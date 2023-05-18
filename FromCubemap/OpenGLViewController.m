/*
*/
#import "OpenGLHeaders.h"
#import "OpenGLRenderer.h"
#import "OpenGLViewController.h"
#import "VirtualCamera.h"
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

    BOOL _saveAsHDR;
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
    _saveAsHDR = NO;
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
        NSOpenGLPFAOpenGLProfile, NSOpenGLProfileVersion4_1Core,
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

- (BOOL)becomeFirstResponder
{
    return YES;
}

- (void)viewDidAppear
{
    [_view.window makeFirstResponder:self];
}

/*
 Return a CGImage object; we assume the internal format of the texture
 is GL_RGBA8 (RGBA8888).
 The images saved to disk are flipped vertically compared to those
 displayed by Apple's OpenGL Profiler.
 In other words, you have to flip the images below writing them out to disk,
 if you wish to see that they match those rendered by Apple's OpenGL Profiler.
 */
- (CGImageRef)makeCGImage:(void *)rawData
                    width:(NSUInteger)width
                   height:(NSUInteger)height
               colorSpace:(CGColorSpaceRef)colorSpace
{
    
    NSUInteger pixelByteCount = 4;
    NSUInteger imageBytesPerRow = width * pixelByteCount;
    NSUInteger imageByteCount = imageBytesPerRow * height;
    NSUInteger bitsPerComponent = 8;
    // Assumes the raw data of CGImage is in RGB/RGBA format.
    // The alpha component is stored in the least significant bits of each pixel.
    CGImageAlphaInfo bitmapInfo = kCGImageAlphaPremultipliedLast | kCGBitmapByteOrder32Big;
    // Let the function allocate memory for the bitmap
    CGContextRef bitmapContext = CGBitmapContextCreate(NULL,
                                                       width, height,
                                                       bitsPerComponent,
                                                       imageBytesPerRow,
                                                       colorSpace,
                                                       bitmapInfo);
    void* imageData = NULL;
    if (bitmapContext != NULL) {
        imageData = CGBitmapContextGetData(bitmapContext);
    }
    if (imageData != NULL) {
        memcpy(imageData, rawData, imageByteCount);
    }
    CGImageRef cgImage = CGBitmapContextCreateImage(bitmapContext);
    if (bitmapContext != NULL) {
        CGContextRelease(bitmapContext);
    }
    // The CGImage object might be NULL.
    // The caller need to release this CGImage object
    return cgImage;
}



/*
 textureNames: a 2-element array
 Apple's OpenGL Profile displays the front 2D image as vertically flipped
 and the back side 2D as horizontally flipped
 In OpenGL, Pixel (0,0) is at the bottom left corner of a 2D image.
 */
- (BOOL)saveTextures:(GLuint *)textureNames
       relativeToURL:(NSURL *)directoryURL
               error:(NSError **)error
{
    // The 2 following calls will make "name" the active texture.
    // We presume both front and back textures of the DP Map have
    // the same size etc.
    glActiveTexture(GL_TEXTURE0);
    glBindTexture(GL_TEXTURE_2D, textureNames[0]);

    GLint width, height;
    GLenum format;
    glGetTexLevelParameteriv(GL_TEXTURE_2D, 0, GL_TEXTURE_WIDTH, &width);
    glGetTexLevelParameteriv(GL_TEXTURE_2D, 0, GL_TEXTURE_HEIGHT, &height);
    NSLog(@"%d %d\n", width, height);
    // Should return 0x8814 which is GL_RGBA32F
    glGetTexLevelParameteriv(GL_TEXTURE_2D, 0, GL_TEXTURE_INTERNAL_FORMAT, (GLint*)&format);
    NSLog(@"0x%0X\n", format);
    if (_saveAsHDR == YES) {
        const size_t kSrcChannelCount = 3;
        // Note: each pixel is 3x4 = 12 bytes and not 3x2 = 6 bytes
        // because OpenGL returns each pixel as a GLfloat not a half GLfloat.
        const size_t bytesPerRow = width*kSrcChannelCount*sizeof(GLfloat);
        size_t dataSize = bytesPerRow*height;
        void *srcData = malloc(dataSize);
        BOOL isOK = YES;                    // Expect no errors
        void *destData = malloc(dataSize);

        NSArray <NSString*> *filenames = [NSArray arrayWithObjects:@"Front.hdr",
                                                                   @"Back.hdr",
                                                                   nil];
        for (int i=0; i<2; i++) {
            NSURL* fileURL = [directoryURL URLByAppendingPathComponent:filenames[i]];
            const char *filePath = [fileURL fileSystemRepresentation];
            glActiveTexture(GL_TEXTURE0+i);
            glBindTexture(GL_TEXTURE_2D, textureNames[i]);
            glGetTexImage(GL_TEXTURE_2D,                    // target
                          0,                                // level of detail
                          GL_RGB,                           // format
                          GL_FLOAT,                         // type
                          srcData);

            int err = stbi_write_hdr(filePath,
                                     (int)width, (int)height,
                                     3,
                                     srcData);
            if (err == 0) {
                if (error != NULL) {
                    *error = [[NSError alloc] initWithDomain:@"File write failure."
                                                        code:0xdeadbeef
                                                    userInfo:@{NSLocalizedDescriptionKey : @"Unable to write hdr file."}];
                }
                isOK = NO;
                break;
            }
        }
        free(srcData);
        free(destData);
        glBindTexture(GL_TEXTURE_2D, 0);
        return isOK;
    }
    else {
        // format == GL_RGBA8
        const size_t kSrcChannelCount = 4;
        const size_t bytesPerRow = width*kSrcChannelCount*sizeof(uint8_t);
        size_t dataSize = bytesPerRow*height;
        void *srcData = malloc(dataSize);
        CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
        BOOL isOK = YES;                    // Expect no errors
        NSArray <NSString*> *filenames = [NSArray arrayWithObjects:@"Front.png",
                                                                   @"Back.png",
                                                                   nil];
        for (int i=0; i<2; i++) {
            glActiveTexture(GL_TEXTURE0+i);
            glBindTexture(GL_TEXTURE_2D, textureNames[i]);
            glGetTexImage(GL_TEXTURE_2D,        // target
                          0,                    // level of detail
                          GL_RGBA,              // format
                          GL_UNSIGNED_BYTE,     // type
                          srcData);
            CGImageRef cgImage = [self makeCGImage:srcData
                                             width:width
                                            height:height
                                        colorSpace:colorSpace];
            CGImageDestinationRef imageDestination = NULL;
            if (cgImage != NULL) {
                NSURL* fileURL = [directoryURL URLByAppendingPathComponent:filenames[i]];
                imageDestination = CGImageDestinationCreateWithURL((__bridge CFURLRef)fileURL,
                                                                   kUTTypePNG,
                                                                   1, NULL);
                CGImageDestinationAddImage(imageDestination, cgImage, nil);
                isOK = CGImageDestinationFinalize(imageDestination);
                CGImageRelease(cgImage);
                CFRelease(imageDestination);
                if (!isOK) {
                    if (error != NULL) {
                        *error = [[NSError alloc] initWithDomain:@"File write failure."
                                                            code:0xdeadbeef
                                                        userInfo:@{NSLocalizedDescriptionKey : @"Unable to write png file."}];
                    }
                    break;
                }
            } // if cgImage not null
            else {
                if (error != NULL) {
                    *error = [[NSError alloc] initWithDomain:@"File write failure."
                                                        code:0xdeadbeef
                                                    userInfo:@{NSLocalizedDescriptionKey : @"Unable to write png file."}];
                }
                isOK = NO;
                break;
            } // cgImage is null
        }
        CGColorSpaceRelease(colorSpace);
        free(srcData);
        glBindTexture(GL_TEXTURE_2D, 0);
        return isOK;
    }
}

/*
 The Paraboloid map is saved as two separate files in the User's
 Document Directory. No prompt will be given.
 */
- (void)keyDown:(NSEvent *)event
{
    if( [[event characters] length] ) {
        unichar nKey = [[event characters] characterAtIndex:0];
        if (nKey == 83 || nKey == 115) {
            GLuint textureIDs[2];
            textureIDs[0] = _openGLRenderer.frontTextureID;
            textureIDs[1] = _openGLRenderer.backTextureID;
            // Save to user's Document Directory.
            if (textureIDs[0] != 0 && textureIDs[1] != 0) {
                NSString *folderPath = @"~/Documents";
                folderPath = [folderPath stringByExpandingTildeInPath];
                NSFileManager *fm = [NSFileManager defaultManager];
                BOOL isDir = NO;
                [fm fileExistsAtPath:folderPath
                         isDirectory:&isDir];
                if (isDir == YES) {
                    NSURL* folderURL = [NSURL fileURLWithPath:folderPath];
                    NSError *err = nil;
                    [self saveTextures:textureIDs
                         relativeToURL:folderURL
                                 error:&err];
                    // KIV. Put up a dialog here?
                }
                NSBeep();
                NSLog(@"The Dual-Paraboloid Maps have been saved");
           }
        }
        else {
            [super keyDown:event];
        }
    }
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

#endif
@end
