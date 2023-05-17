/*
 Created by Mark Lim Pak Mun on 16 May 2023
*/
#import "OpenGLViewController.h"
#import "VirtualCamera.h"
#import "OpenGLRenderer.h"
#define STB_IMAGE_WRITE_IMPLEMENTATION
#import "stb_image_write.h"


#ifdef TARGET_MACOS
#define PlatformGLContext NSOpenGLContext
#else // if!(TARGET_IOS || TARGET_TVOS)
#define PlatformGLContext EAGLContext
#endif // !(TARGET_IOS || TARGET_TVOS)

@implementation OpenGLView

#if defined(TARGET_IOS) || defined(TARGET_TVOS)
// Implement this to override the default layer class (which is [CALayer class]).
// We do this so that our view will be backed by a layer that is capable of OpenGL ES rendering.
+ (Class) layerClass
{
    return [CAEAGLLayer class];
}
#endif

@end

@implementation OpenGLViewController
{
    // Instance vars
    OpenGLView *_view;
    OpenGLRenderer *_openGLRenderer;
    PlatformGLContext *_context;
    GLuint _defaultFBOName;

#if defined(TARGET_IOS) || defined(TARGET_TVOS)
    GLuint _colorRenderbuffer;
    GLuint _depthRenderbuffer;
    CADisplayLink *_displayLink;
#else
    CVDisplayLinkRef _displayLink;
#endif
}

// Common method for iOS and macOS ports
- (void)viewDidLoad
{
    [super viewDidLoad];

    _view = (OpenGLView *)self.view;

    [self prepareView];

    [self makeCurrentContext];

    _openGLRenderer = [[OpenGLRenderer alloc] initWithDefaultFBOName:_defaultFBOName];

    if (!_openGLRenderer) {
        NSLog(@"OpenGL renderer failed initialization.");
        return;
    }

    // This call will set the camera's screenSize correctly.
    [_openGLRenderer resize:self.drawableSize];
#if TARGET_OS_IOS
    UIGestureRecognizer *panGesture = [[UIPanGestureRecognizer alloc] initWithTarget:self
                                                                              action:@selector(panGestureDidRecognize:)];
    [self.view addGestureRecognizer:panGesture];
    
    UIGestureRecognizer *pinchGesture = [[UIPinchGestureRecognizer alloc] initWithTarget:self
                                                                                  action:@selector(pinchGestureDidRecognize:)];
    [self.view addGestureRecognizer:pinchGesture];
    
#endif

}

#if defined(TARGET_MACOS)

- (CGSize)drawableSize
{
    CGSize viewSizePoints = _view.bounds.size;

    CGSize viewSizePixels = [_view convertSizeToBacking:viewSizePoints];

    return viewSizePixels;
}

- (void)makeCurrentContext
{
    [_context makeCurrentContext];
}

static CVReturn OpenGLDisplayLinkCallback(CVDisplayLinkRef displayLink,
                                          const CVTimeStamp* now,
                                          const CVTimeStamp* outputTime,
                                          CVOptionFlags flagsIn,
                                          CVOptionFlags* flagsOut,
                                          void* displayLinkContext)
{
    OpenGLViewController *viewController = (__bridge OpenGLViewController*)displayLinkContext;

    [viewController draw];
    return YES;
}

// The CVDisplayLink object will call this method whenever a frame update is necessary.
- (void)draw
 {
    CGLLockContext(_context.CGLContextObj);

    [_context makeCurrentContext];

    [_openGLRenderer draw];

    CGLFlushDrawable(_context.CGLContextObj);
    CGLUnlockContext(_context.CGLContextObj);
}

- (void)prepareView
{
    NSOpenGLPixelFormatAttribute attrs[] =
    {
        NSOpenGLPFAColorSize, 32,
        NSOpenGLPFADoubleBuffer,
        NSOpenGLPFADepthSize, 24,
        NSOpenGLPFAOpenGLProfile, NSOpenGLProfileVersion3_2Core,
        0
    };

    NSOpenGLPixelFormat *pixelFormat = [[NSOpenGLPixelFormat alloc] initWithAttributes:attrs];

    NSAssert(pixelFormat, @"No OpenGL pixel format.");

    _context = [[NSOpenGLContext alloc] initWithFormat:pixelFormat
                                          shareContext:nil];

    CGLLockContext(_context.CGLContextObj);

    [_context makeCurrentContext];

    CGLUnlockContext(_context.CGLContextObj);

    glEnable(GL_FRAMEBUFFER_SRGB);
    _view.pixelFormat = pixelFormat;
    _view.openGLContext = _context;
    _view.wantsBestResolutionOpenGLSurface = YES;

    // The default framebuffer object (FBO) is 0 on macOS, because it uses
    // a traditional OpenGL pixel format model. Might be different on other OSes.
    _defaultFBOName = 0;

    CVDisplayLinkCreateWithActiveCGDisplays(&_displayLink);

    // Set the renderer output callback function.
    CVDisplayLinkSetOutputCallback(_displayLink,
                                   &OpenGLDisplayLinkCallback, (__bridge void*)self);

    CVDisplayLinkSetCurrentCGDisplayFromOpenGLContext(_displayLink,
                                                      _context.CGLContextObj,
                                                      pixelFormat.CGLPixelFormatObj);
}

- (void)viewDidLayout
{
    CGLLockContext(_context.CGLContextObj);

    NSSize viewSizePoints = _view.bounds.size;

    NSSize viewSizePixels = [_view convertSizeToBacking:viewSizePoints];

    [self makeCurrentContext];

    [_openGLRenderer resize:viewSizePixels];

    CGLUnlockContext(_context.CGLContextObj);

    if(!CVDisplayLinkIsRunning(_displayLink))
    {
        CVDisplayLinkStart(_displayLink);
    }
}

- (void) viewWillDisappear
{
    CVDisplayLinkStop(_displayLink);
}

- (void)dealloc
{
    CVDisplayLinkStop(_displayLink);

    CVDisplayLinkRelease(_displayLink);
}

- (BOOL) becomeFirstResponder {
    return YES;
}


- (void) mouseDown:(NSEvent *)event {
    NSPoint mouseLocation = [self.view convertPoint:event.locationInWindow
                                        fromView:nil];
    [_openGLRenderer.camera startDraggingFromPoint:mouseLocation];
}

- (void) mouseDragged:(NSEvent *)event {
    NSPoint mouseLocation = [self.view convertPoint:event.locationInWindow
                                           fromView:nil];
    if (_openGLRenderer.camera.isDragging) {
        [_openGLRenderer.camera dragToPoint:mouseLocation];
    }
}

- (void) mouseUp:(NSEvent *)event {
    NSPoint mouseLocation = [self.view convertPoint:event.locationInWindow
                                           fromView:nil];
    [_openGLRenderer.camera endDrag];
    
}

// We can move most of the code to the VirtualCamera class
- (void)scrollWheel:(NSEvent *)event {
    CGFloat dz = event.scrollingDeltaY;
    [_openGLRenderer.camera zoomInOrOut:dz];
}

#else

// ===== iOS specific code. =====

// sender is an instance of CADisplayLink
- (void)draw:(id)sender
{
    [EAGLContext setCurrentContext:_context];
    [_openGLRenderer draw];

    glBindRenderbuffer(GL_RENDERBUFFER, _colorRenderbuffer);
    [_context presentRenderbuffer:GL_RENDERBUFFER];
}

- (void)makeCurrentContext
{
    [EAGLContext setCurrentContext:_context];
}

- (void)prepareView
{
    CAEAGLLayer *eaglLayer = (CAEAGLLayer *)self.view.layer;

    eaglLayer.drawableProperties = @{kEAGLDrawablePropertyRetainedBacking : @NO,
                                     kEAGLDrawablePropertyColorFormat     : kEAGLColorFormatSRGBA8 };
    eaglLayer.opaque = YES;

    _context = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES3];

    if (!_context || ![EAGLContext setCurrentContext:_context])
    {
        NSLog(@"Could not create an OpenGL ES context.");
        return;
    }

    [self makeCurrentContext];

    self.view.contentScaleFactor = [UIScreen mainScreen].nativeScale;

    // In iOS & tvOS, you must create an FBO and attach a drawable texture
    // allocated by Core Animation to use as the default FBO for a view.
    glGenFramebuffers(1, &_defaultFBOName);
    glBindFramebuffer(GL_FRAMEBUFFER, _defaultFBOName);

    glGenRenderbuffers(1, &_colorRenderbuffer);

    glGenRenderbuffers(1, &_depthRenderbuffer);

    [self resizeDrawable];

    glFramebufferRenderbuffer(GL_FRAMEBUFFER,
                              GL_COLOR_ATTACHMENT0,
                              GL_RENDERBUFFER,
                              _colorRenderbuffer);
    glFramebufferRenderbuffer(GL_FRAMEBUFFER,
                              GL_DEPTH_ATTACHMENT,
                              GL_RENDERBUFFER,
                              _depthRenderbuffer);

    // Create the display link so you render at 60 frames per second (FPS).
    _displayLink = [CADisplayLink displayLinkWithTarget:self
                                               selector:@selector(draw:)];

    _displayLink.preferredFramesPerSecond = 60;

    // Set the display link to run on the default run loop (and the main thread).
    [_displayLink addToRunLoop:[NSRunLoop currentRunLoop]
                       forMode:NSDefaultRunLoopMode];
}

- (CGSize)drawableSize
{
    GLint backingWidth, backingHeight;
    glBindRenderbuffer(GL_RENDERBUFFER, _colorRenderbuffer);
    glGetRenderbufferParameteriv(GL_RENDERBUFFER, GL_RENDERBUFFER_WIDTH, &backingWidth);
    glGetRenderbufferParameteriv(GL_RENDERBUFFER, GL_RENDERBUFFER_HEIGHT, &backingHeight);
    CGSize drawableSize = {backingWidth, backingHeight};
    return drawableSize;
}

- (void)resizeDrawable
{
    [self makeCurrentContext];

    // First, ensure that you have a render buffer.
    assert(_colorRenderbuffer != 0);

    glBindRenderbuffer(GL_RENDERBUFFER,
                       _colorRenderbuffer);
    // This call associates the storage for the current render buffer with the EAGLDrawable
    // (our CAEAGLLayer) allowing us to draw into a buffer that will later be rendered
    // to screen wherever the layer is (which corresponds with our view).
    [_context renderbufferStorage:GL_RENDERBUFFER
                     fromDrawable:(id<EAGLDrawable>)_view.layer];

    CGSize drawableSize = [self drawableSize];

    glBindRenderbuffer(GL_RENDERBUFFER,
                       _depthRenderbuffer);

    glRenderbufferStorage(GL_RENDERBUFFER,
                          GL_DEPTH_COMPONENT24,
                          drawableSize.width, drawableSize.height);

    GetGLError();
    // The custom render object is nil on first call to this method.
    [_openGLRenderer resize:self.drawableSize];
}

// overridden method
- (void)viewDidLayoutSubviews
{
    [self resizeDrawable];
}

// overridden method
- (void)viewDidAppear:(BOOL)animated
{
    [self resizeDrawable];
}

- (void) panGestureDidRecognize:(UIPanGestureRecognizer *)gesture {
    CGPoint location = [gesture locationInView:self.view];
    switch(gesture.state) {
        case UIGestureRecognizerStateBegan:
            [_openGLRenderer.camera startDraggingFromPoint:location];
            break;
        case UIGestureRecognizerStateChanged:
            if (_openGLRenderer.camera.isDragging) {
                [_openGLRenderer.camera dragToPoint:location];
            }
            break;
        case UIGestureRecognizerStateEnded:
            [_openGLRenderer.camera endDrag];
            break;
        default:
            break;
    }
    [gesture setTranslation:CGPointZero
                     inView:self.view];
}

/*
 The "scale" property of UIPinchGestureRecognizer object is the distance between
  the 2 fingers of the pinch gesture.
 At the start of every pinch gesture, the var "previousScale" is set/reset to 1.0
 Refer: Apple's documentation "Handling Pinch Gestures"
 */
- (void) pinchGestureDidRecognize:(UIPinchGestureRecognizer *)gesture {
    static float previousScale = 1.0;
    static float arbitraryValue = 15.0;

    // Use the difference (positive/negative) to do a zoom in/zoom out.
    float delta = (gesture.scale - previousScale) * arbitraryValue;
    [_openGLRenderer.camera zoomInOrOut:delta];
    previousScale = gesture.scale;
    if (gesture.state == UIGestureRecognizerStateEnded) {
        // Reset for the event of a new pinch gesture.
        // The "velocity" property will be reset.
        previousScale = 1.0;
    }
}


#endif
@end
