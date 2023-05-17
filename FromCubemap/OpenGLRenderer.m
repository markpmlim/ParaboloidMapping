/*
*/

#import <Foundation/Foundation.h>
#import <simd/simd.h>
#import "VirtualCamera.h"
#import "OpenGLRenderer.h"
#import "AAPLMathUtilities.h"
#define STB_IMAGE_IMPLEMENTATION
#include "stb_image.h"


@implementation OpenGLRenderer
{
    GLuint _defaultFBOName;
    CGSize _viewSize;

    GLuint _glslProgram;


    GLuint _triangleVAO;
    GLuint _frontTextureID;
    GLuint _backTextureID;

    GLuint _cubemapTextureID;

    CGSize _tex0Resolution;

    vector_int4 _viewPort[2];
}

- (instancetype)initWithDefaultFBOName:(GLuint)defaultFBOName
{
    self = [super init];
    if(self) {
        NSLog(@"%s %s", glGetString(GL_RENDERER), glGetString(GL_VERSION));

        // Build all of your objects and setup initial state here.
        _defaultFBOName = defaultFBOName;
        // Must bind or buildProgramWithVertexSourceURL:withFragmentSourceURLwill crash on validation.
        glGenVertexArrays(1, &_triangleVAO);
        glBindVertexArray(_triangleVAO);

        NSBundle *mainBundle = [NSBundle mainBundle];
        NSURL *vertexSourceURL = [mainBundle URLForResource:@"SimpleVertexShader"
                                              withExtension:@"glsl"];
        NSURL *fragmentSourceURL = [mainBundle URLForResource:@"SimpleFragmentShader"
                                              withExtension:@"glsl"];
        _glslProgram = [OpenGLRenderer buildProgramWithVertexSourceURL:vertexSourceURL
                                                 withFragmentSourceURL:fragmentSourceURL];
        NSArray <NSString*> *names = @[@"px.png", @"nx.png", @"py.png", @"ny.png", @"pz.png", @"nz.png"];
#if !TARGET_OS_IOS
        glEnable(GL_TEXTURE_CUBE_MAP_SEAMLESS);
#endif
        _cubemapTextureID = [self textureWithContentsOfFiles:names
                                           resolution:&_tex0Resolution
                                                isHDR:NO];
        //printf("%f %f\n", _tex0Resolution.width, _tex0Resolution.height);
        // _viewSize is initially CGSizeZero but that's ok because the resize:
        // method will be called shortly.
        CGSize size = CGSizeMake(512, 512);
        [self paraboloidMapFromCubemap:_cubemapTextureID
                           textureSize:size];
    }
    return self;
}

- (void)dealloc
{
    glDeleteProgram(_glslProgram);
    glDeleteVertexArrays(1, &_triangleVAO);
    glDeleteTextures(1, &_cubemapTextureID);
    glDeleteTextures(1, &_backTextureID);
    glDeleteTextures(1, &_frontTextureID);
}


- (void)resize:(CGSize)size
{
    // Handle the resize of the draw rectangle.
    _viewSize = size;
    // Divide the view into 2 (vertical) halves
    GLint border = 2;
    _viewPort[0] = (vector_int4){0, 0,
                                _viewSize.width/2.0, _viewSize.height};
    _viewPort[1] = (vector_int4){_viewSize.width/2.0, 0,
                                 _viewSize.width/2.0, _viewSize.height};
}

- (GLuint)textureWithContentsOfFiles:(NSArray *)names
                          resolution:(CGSize *)size
                               isHDR:(BOOL)isHDR
{
    //NSLog(@"%@", names);
    GLuint textureID = 0;

    NSBundle *mainBundle = [NSBundle mainBundle];
    // The objects of filePath should be either NSString or NSURL
    NSMutableArray <id> *filePaths = [NSMutableArray arrayWithCapacity:6];
    for (int i=0; i<6; i++) {
        NSArray<NSString *> *subStrings = [names[i] componentsSeparatedByString:@"."];
        
        NSString* path = [mainBundle pathForResource:subStrings[0]
                                              ofType:subStrings[1]];
        filePaths[i] = path;
    }

    if (isHDR == YES) {
        //NSLog(@"%@", filePaths);
        GLint width = 0;
        GLint height = 0;
        GLint numComponents = 0;

        glGenTextures(1, &textureID);
        glBindTexture(GL_TEXTURE_CUBE_MAP, textureID);
        // The flag stbi__vertically_flip_on_load defaults to false
        for (int i=0; i<6; i++) {
            GLfloat *data = nil;
            data = stbi_loadf([filePaths[i] UTF8String],
                              &width, &height, &numComponents, 0);
            glTexImage2D(GL_TEXTURE_CUBE_MAP_POSITIVE_X + i,
                         0,
                         GL_RGB16F,
                         width, height,
                         0,
                         GL_RGB,
                         GL_FLOAT,
                         data);
            stbi_image_free(data);
        }
        glTexParameteri(GL_TEXTURE_CUBE_MAP, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
        glTexParameteri(GL_TEXTURE_CUBE_MAP, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
        glTexParameteri(GL_TEXTURE_CUBE_MAP, GL_TEXTURE_WRAP_R, GL_CLAMP_TO_EDGE);
        glTexParameteri(GL_TEXTURE_CUBE_MAP, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
        glTexParameteri(GL_TEXTURE_CUBE_MAP, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
        size->width = width;
        size->height = height;
    }
    else {
        NSDictionary *loaderOptions = @{
            GLKTextureLoaderOriginBottomLeft : @NO,
        };
        NSError *error;
        GLKTextureInfo *textureInfo = [GLKTextureLoader cubeMapWithContentsOfFiles:filePaths
                                                                           options:loaderOptions
                                                                             error:&error];
        //NSLog(@"%@", textureInfo);
        textureID = textureInfo.name;
        size->width = textureInfo.width;
        size->height = textureInfo.height;
    }
    return textureID;
}

- (void)draw
{
    glClearColor(0.5, 0.5, 0.5, 1.0);
    glClear(GL_COLOR_BUFFER_BIT);

    glUseProgram(_glslProgram);
    glBindVertexArray(_triangleVAO);

    // Draw the front side of the Paraboloid Map on the left
    glViewport(_viewPort[0].x, _viewPort[0].y,
               _viewPort[0].z, _viewPort[0].w);
    glActiveTexture(GL_TEXTURE0);
    glBindTexture(GL_TEXTURE_2D, _frontTextureID);
    glDrawArrays(GL_TRIANGLES, 0, 3);

    // Draw the back side of the Paraboloid Map on the right
    glViewport(_viewPort[1].x, _viewPort[1].y,
               _viewPort[1].z, _viewPort[1].w);
    glActiveTexture(GL_TEXTURE0);
    glBindTexture(GL_TEXTURE_2D, _backTextureID);
    glDrawArrays(GL_TRIANGLES, 0, 3);

    glUseProgram(0);
    glBindVertexArray(0);
} // draw

/*
 Multitexture render to an Offscreen framebuffer using a cubemap texture
 */
- (void)paraboloidMapFromCubemap:(GLuint)textureID
                     textureSize:(CGSize)size
{
    glBindVertexArray(_triangleVAO);
    NSBundle *mainBundle = [NSBundle mainBundle];
    NSURL *vertexSourceURL = [mainBundle URLForResource:@"SimpleVertexShader"
                                          withExtension:@"glsl"];
    NSURL *fragmentSourceURL = [mainBundle URLForResource:@"GenerateDPM2"
                                            withExtension:@"glsl"];
    GLuint program = [OpenGLRenderer buildProgramWithVertexSourceURL:vertexSourceURL
                                               withFragmentSourceURL:fragmentSourceURL];

    // Create and initialize an offscreen frame buffer object (fbo)
    GLuint fbo;
    GLuint rbo;
    glGenFramebuffers(1, &fbo);
    glGenRenderbuffers(1, &rbo);
    glBindFramebuffer(GL_FRAMEBUFFER, fbo);    // read & draw
    glBindRenderbuffer(GL_RENDERBUFFER, rbo);
    glRenderbufferStorage((GLenum)GL_RENDERBUFFER,
                          (GLenum)GL_DEPTH_COMPONENT24,
                          (GLsizei)size.width, (GLsizei)size.height);
    glFramebufferRenderbuffer(GL_FRAMEBUFFER,
                              GL_DEPTH_ATTACHMENT,
                              GL_RENDERBUFFER,
                              rbo);
    CheckFramebuffer();

    glGenTextures(1, &_frontTextureID);
    glBindTexture(GL_TEXTURE_2D, _frontTextureID);
    // Allocate immutable storage for the front texture
    glTexStorage2D(GL_TEXTURE_2D, 1, GL_RGBA16F, size.width, size.height);
    // Set its default filter parameters
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST);
    glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_TEXTURE_2D, _frontTextureID, 0);

    glGenTextures(1, &_backTextureID);
    glBindTexture(GL_TEXTURE_2D, _backTextureID);
    // Allocate immutable storage for the back texture
    glTexStorage2D(GL_TEXTURE_2D, 1, GL_RGBA16F, size.width, size.height);
    // Set its default filter parameters
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST);
    glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT1, GL_TEXTURE_2D, _backTextureID, 0);

    GLenum drawBuffers[] = {GL_COLOR_ATTACHMENT0, GL_COLOR_ATTACHMENT1};
    glDrawBuffers(2, drawBuffers); // don't forget to do this!
    GetGLError();

    // prepare to draw.
    glClearColor(0.5, 0.5, 0.5, 1.0);
    glClear(GL_COLOR_BUFFER_BIT);
    glViewport(0, 0,
               size.width, size.height);
    glUseProgram(program);
    glActiveTexture(GL_TEXTURE0);
    glBindTexture(GL_TEXTURE_CUBE_MAP, textureID);
    glDrawArrays(GL_TRIANGLES, 0, 3);
    glBindVertexArray(0);
    GetGLError();

    glDeleteProgram(program);
    glDeleteRenderbuffers(1, &rbo);
    glDeleteFramebuffers(1, &fbo);

    glBindFramebuffer(GL_FRAMEBUFFER, _defaultFBOName);
}

+ (GLuint)buildProgramWithVertexSourceURL:(NSURL*)vertexSourceURL
                    withFragmentSourceURL:(NSURL*)fragmentSourceURL
{

    NSError *error;

    NSString *vertSourceString = [[NSString alloc] initWithContentsOfURL:vertexSourceURL
                                                                encoding:NSUTF8StringEncoding
                                                                   error:&error];

    NSAssert(vertSourceString, @"Could not load vertex shader source, error: %@.", error);

    NSString *fragSourceString = [[NSString alloc] initWithContentsOfURL:fragmentSourceURL
                                                                encoding:NSUTF8StringEncoding
                                                                   error:&error];

    NSAssert(fragSourceString, @"Could not load fragment shader source, error: %@.", error);

    // Prepend the #version definition to the vertex and fragment shaders.
    float  glLanguageVersion;

#if defined(TARGET_IOS)
    sscanf((char *)glGetString(GL_SHADING_LANGUAGE_VERSION), "OpenGL ES GLSL ES %f", &glLanguageVersion);
#else
    sscanf((char *)glGetString(GL_SHADING_LANGUAGE_VERSION), "%f", &glLanguageVersion);
#endif

    // `GL_SHADING_LANGUAGE_VERSION` returns the standard version form with decimals, but the
    //  GLSL version preprocessor directive simply uses integers (e.g. 1.10 should be 110 and 1.40
    //  should be 140). You multiply the floating point number by 100 to get a proper version number
    //  for the GLSL preprocessor directive.
    GLuint version = 100 * glLanguageVersion;

    NSString *versionString = [[NSString alloc] initWithFormat:@"#version %d", version];
#if TARGET_OS_IOS
    if ([[EAGLContext currentContext] API] == kEAGLRenderingAPIOpenGLES3)
        versionString = [versionString stringByAppendingString:@" es"];
#endif

    vertSourceString = [[NSString alloc] initWithFormat:@"%@\n%@", versionString, vertSourceString];
    fragSourceString = [[NSString alloc] initWithFormat:@"%@\n%@", versionString, fragSourceString];

    GLuint prgName;

    GLint logLength, status;

    // Create a GLSL program object.
    prgName = glCreateProgram();

    /*
     * Specify and compile a vertex shader.
     */

    GLchar *vertexSourceCString = (GLchar*)vertSourceString.UTF8String;
    GLuint vertexShader = glCreateShader(GL_VERTEX_SHADER);
    glShaderSource(vertexShader, 1, (const GLchar **)&(vertexSourceCString), NULL);
    glCompileShader(vertexShader);
    glGetShaderiv(vertexShader, GL_INFO_LOG_LENGTH, &logLength);

    if (logLength > 0) {
        GLchar *log = (GLchar*) malloc(logLength);
        glGetShaderInfoLog(vertexShader, logLength, &logLength, log);
        NSLog(@"Vertex shader compile log:\n%s.\n", log);
        free(log);
    }

    glGetShaderiv(vertexShader, GL_COMPILE_STATUS, &status);

    NSAssert(status, @"Failed to compile the vertex shader:\n%s.\n", vertexSourceCString);

    // Attach the vertex shader to the program.
    glAttachShader(prgName, vertexShader);

    // Delete the vertex shader because it's now attached to the program, which retains
    // a reference to it.
    glDeleteShader(vertexShader);

    /*
     * Specify and compile a fragment shader.
     */

    GLchar *fragSourceCString =  (GLchar*)fragSourceString.UTF8String;
    GLuint fragShader = glCreateShader(GL_FRAGMENT_SHADER);
    glShaderSource(fragShader, 1, (const GLchar **)&(fragSourceCString), NULL);
    glCompileShader(fragShader);
    glGetShaderiv(fragShader, GL_INFO_LOG_LENGTH, &logLength);
    if (logLength > 0) {
        GLchar *log = (GLchar*)malloc(logLength);
        glGetShaderInfoLog(fragShader, logLength, &logLength, log);
        NSLog(@"Fragment shader compile log:\n%s.\n", log);
        free(log);
    }

    glGetShaderiv(fragShader, GL_COMPILE_STATUS, &status);

    NSAssert(status, @"Failed to compile the fragment shader:\n%s.", fragSourceCString);

    // Attach the fragment shader to the program.
    glAttachShader(prgName, fragShader);

    // Delete the fragment shader because it's now attached to the program, which retains
    // a reference to it.
    glDeleteShader(fragShader);

    /*
     * Link the program.
     */

    glLinkProgram(prgName);
    glGetProgramiv(prgName, GL_LINK_STATUS, &status);
    NSAssert(status, @"Failed to link program.");
    if (status == 0) {
        glGetProgramiv(prgName, GL_INFO_LOG_LENGTH, &logLength);
        if (logLength > 0) {
            GLchar *log = (GLchar*)malloc(logLength);
            glGetProgramInfoLog(prgName, logLength, &logLength, log);
            NSLog(@"Program link log:\n%s.\n", log);
            free(log);
        }
    }

    // Added code
    // Call the 2 functions below if VAOs have been bound prior to creating the shader program
    // iOS will not complain if VAOs have NOT been bound.
    glValidateProgram(prgName);
    glGetProgramiv(prgName, GL_VALIDATE_STATUS, &status);
    NSAssert(status, @"Failed to validate program.");

    if (status == 0) {
        fprintf(stderr,"Program cannot run with current OpenGL State\n");
        glGetProgramiv(prgName, GL_INFO_LOG_LENGTH, &logLength);
        if (logLength > 0) {
            GLchar *log = (GLchar*)malloc(logLength);
            glGetProgramInfoLog(prgName, logLength, &logLength, log);
            NSLog(@"Program validate log:\n%s\n", log);
            free(log);
        }
    }

    GetGLError();

    return prgName;
}

@end
