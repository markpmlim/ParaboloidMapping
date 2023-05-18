/*
 Created by Mark Lim Pak Mun on 16 May 2023
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

    GLuint _cubeVAO;
    GLuint _cubeVBO;

    GLuint _triangleVAO;
    GLuint _frontTextureID;
    GLuint _backTextureID;

    GLuint _cubemapTextureID;

    CGSize _tex0Resolution;

    GLint _projectionMatrixLoc;
    GLint _viewMatrixLoc;
    GLint _modelMatrixLoc;
    matrix_float4x4 _projectionMatrix;

    VirtualCamera* _camera;
}

- (instancetype)initWithDefaultFBOName:(GLuint)defaultFBOName
{
    self = [super init];
    if(self) {
        NSLog(@"%s %s", glGetString(GL_RENDERER), glGetString(GL_VERSION));

        // Build all of your objects and setup initial state here.
        _defaultFBOName = defaultFBOName;
        [self buildResources];
        // Must bind or buildProgramWithVertexSourceURL:withFragmentSourceURLwill crash on validation.
        glBindVertexArray(_cubeVAO);

        NSBundle *mainBundle = [NSBundle mainBundle];
        NSURL *vertexSourceURL = [mainBundle URLForResource:@"VertexShader"
                                              withExtension:@"glsl"];
        NSURL *fragmentSourceURL = [mainBundle URLForResource:@"FragmentShader"
                                              withExtension:@"glsl"];
        _glslProgram = [OpenGLRenderer buildProgramWithVertexSourceURL:vertexSourceURL
                                                 withFragmentSourceURL:fragmentSourceURL];
        //printf("%u\n", _glslProgram);
        _projectionMatrixLoc = glGetUniformLocation(_glslProgram, "projectionMatrix");
        _viewMatrixLoc = glGetUniformLocation(_glslProgram, "viewMatrix");
        _modelMatrixLoc = glGetUniformLocation(_glslProgram, "modelMatrix");
        //printf("%d %d %d\n", _projectionMatrixLoc, _viewMatrixLoc, _modelMatrixLoc);
        NSString *name = @"Front.png";
        _frontTextureID = [self textureWithContentsOfFile:name
                                               resolution:&_tex0Resolution
                                                    isHDR:NO];
        //printf("%f %f\n", _tex0Resolution.width, _tex0Resolution.height);
        name = @"Back.png";
        _backTextureID = [self textureWithContentsOfFile:name
                                              resolution:&_tex0Resolution
                                                   isHDR:NO];
        glBindVertexArray(0);
        // _viewSize is CGSizeZero but that's ok because the resize: method
        //  will be called shortly. The virtual camera's screen size will
        //  be set correctly.
        _camera = [[VirtualCamera alloc] initWithScreenSize:_viewSize];
#if !TARGET_OS_IOS
        glEnable(GL_TEXTURE_CUBE_MAP_SEAMLESS);
#endif
        // Enable depth testing because we won't be culling the cube's faces
        glEnable(GL_DEPTH_TEST);
        GLuint texNames[2] = {_frontTextureID, _backTextureID};
        _cubemapTextureID = [self cubemapFromParaboloidMap:texNames
                                                  faceSize:512];
    }

    return self;
}

- (void)dealloc
{
    glDeleteProgram(_glslProgram);
    glDeleteVertexArrays(1, &_cubeVAO);
    glDeleteBuffers(1, &_cubeVBO);
    glDeleteTextures(1, &_cubemapTextureID);
    glDeleteTextures(1, &_frontTextureID);
    glDeleteTextures(1, &_backTextureID);
}

- (void)renderCube
{
    glBindVertexArray(_cubeVAO);
    glDrawArrays(GL_TRIANGLES, 0, 36);
    glBindVertexArray(0);
}

/*
 The winding order is important because when viewed within the box,
 it should be clockwise.
 When viewed outside the box, the winding order of the 6 faces should be
 anti-clockwise.
 */
- (void)buildResources
{

    // initialize (if necessary)
    if (_cubeVAO == 0) {
        float vertices[] = {
            // back face
            //  positions               normals       texcoords
            -1.0f, -1.0f, -1.0f,  0.0f,  0.0f, -1.0f, 0.0f, 0.0f, // A bottom-left
             1.0f,  1.0f, -1.0f,  0.0f,  0.0f, -1.0f, 1.0f, 1.0f, // C top-right
             1.0f, -1.0f, -1.0f,  0.0f,  0.0f, -1.0f, 1.0f, 0.0f, // B bottom-right
             1.0f,  1.0f, -1.0f,  0.0f,  0.0f, -1.0f, 1.0f, 1.0f, // C top-right
            -1.0f, -1.0f, -1.0f,  0.0f,  0.0f, -1.0f, 0.0f, 0.0f, // A bottom-left
            -1.0f,  1.0f, -1.0f,  0.0f,  0.0f, -1.0f, 0.0f, 1.0f, // D top-left
            // front face (anti-clockwise when viewed outside the box.
            -1.0f, -1.0f,  1.0f,  0.0f,  0.0f,  1.0f, 0.0f, 0.0f, // E bottom-left
             1.0f, -1.0f,  1.0f,  0.0f,  0.0f,  1.0f, 1.0f, 0.0f, // F bottom-right
             1.0f,  1.0f,  1.0f,  0.0f,  0.0f,  1.0f, 1.0f, 1.0f, // G top-right
             1.0f,  1.0f,  1.0f,  0.0f,  0.0f,  1.0f, 1.0f, 1.0f, // G top-right
            -1.0f,  1.0f,  1.0f,  0.0f,  0.0f,  1.0f, 0.0f, 1.0f, // H top-left
            -1.0f, -1.0f,  1.0f,  0.0f,  0.0f,  1.0f, 0.0f, 0.0f, // E bottom-left
            // left face
            -1.0f,  1.0f,  1.0f, -1.0f,  0.0f,  0.0f, 1.0f, 0.0f, // H top-right
            -1.0f,  1.0f, -1.0f, -1.0f,  0.0f,  0.0f, 1.0f, 1.0f, // D top-left
            -1.0f, -1.0f, -1.0f, -1.0f,  0.0f,  0.0f, 0.0f, 1.0f, // A bottom-left
            -1.0f, -1.0f, -1.0f, -1.0f,  0.0f,  0.0f, 0.0f, 1.0f, // A bottom-left
            -1.0f, -1.0f,  1.0f, -1.0f,  0.0f,  0.0f, 0.0f, 0.0f, // E bottom-right
            -1.0f,  1.0f,  1.0f, -1.0f,  0.0f,  0.0f, 1.0f, 0.0f, // H top-right
            // right face
            1.0f,  1.0f,  1.0f,  1.0f,  0.0f,  0.0f, 1.0f, 0.0f, // G top-left
            1.0f, -1.0f, -1.0f,  1.0f,  0.0f,  0.0f, 0.0f, 1.0f, // B bottom-right
            1.0f,  1.0f, -1.0f,  1.0f,  0.0f,  0.0f, 1.0f, 1.0f, // C top-right
            1.0f, -1.0f, -1.0f,  1.0f,  0.0f,  0.0f, 0.0f, 1.0f, // B bottom-right
            1.0f,  1.0f,  1.0f,  1.0f,  0.0f,  0.0f, 1.0f, 0.0f, // G top-left
            1.0f, -1.0f,  1.0f,  1.0f,  0.0f,  0.0f, 0.0f, 0.0f, // F bottom-left
            // bottom face
            -1.0f, -1.0f, -1.0f,  0.0f, -1.0f,  0.0f, 0.0f, 1.0f, // F top-right
             1.0f, -1.0f, -1.0f,  0.0f, -1.0f,  0.0f, 1.0f, 1.0f, // E Atop-left
             1.0f, -1.0f,  1.0f,  0.0f, -1.0f,  0.0f, 1.0f, 0.0f, // A bottom-left
             1.0f, -1.0f,  1.0f,  0.0f, -1.0f,  0.0f, 1.0f, 0.0f, // A bottom-left
            -1.0f, -1.0f,  1.0f,  0.0f, -1.0f,  0.0f, 0.0f, 0.0f, // B bottom-right
            -1.0f, -1.0f, -1.0f,  0.0f, -1.0f,  0.0f, 0.0f, 1.0f, // F top-right
            // top face
            -1.0f,  1.0f, -1.0f,  0.0f,  1.0f,  0.0f, 0.0f, 1.0f, // D top-left
             1.0f,  1.0f , 1.0f,  0.0f,  1.0f,  0.0f, 1.0f, 0.0f, // G bottom-right
             1.0f,  1.0f, -1.0f,  0.0f,  1.0f,  0.0f, 1.0f, 1.0f, // C top-right
             1.0f,  1.0f,  1.0f,  0.0f,  1.0f,  0.0f, 1.0f, 0.0f, // G bottom-right
            -1.0f,  1.0f, -1.0f,  0.0f,  1.0f,  0.0f, 0.0f, 1.0f, // D top-left
            -1.0f,  1.0f,  1.0f,  0.0f,  1.0f,  0.0f, 0.0f, 0.0f  // H bottom-left
        };

        glGenVertexArrays(1, &_cubeVAO);
        glGenBuffers(1, &_cubeVBO);
        // fill buffer
        glBindBuffer(GL_ARRAY_BUFFER, _cubeVBO);
        glBufferData(GL_ARRAY_BUFFER, sizeof(vertices), vertices, GL_STATIC_DRAW);
        // link vertex attributes
        glBindVertexArray(_cubeVAO);
        glEnableVertexAttribArray(0);
        glVertexAttribPointer(0, 3, GL_FLOAT, GL_FALSE, 8 * sizeof(float), (void*)0);
        glEnableVertexAttribArray(1);
        glVertexAttribPointer(1, 3, GL_FLOAT, GL_FALSE, 8 * sizeof(float), (void*)(3 * sizeof(float)));
        glEnableVertexAttribArray(2);
        glVertexAttribPointer(2, 2, GL_FLOAT, GL_FALSE, 8 * sizeof(float), (void*)(6 * sizeof(float)));
        glBindBuffer(GL_ARRAY_BUFFER, 0);
        glBindVertexArray(0);
    }
}

- (void)resize:(CGSize)size
{
    // Handle the resize of the draw rectangle. In particular, update the perspective projection matrix
    // with a new aspect ratio because the view orientation, layout, or size has changed.
    _viewSize = size;
    float aspect = (float)size.width / size.height;
    _projectionMatrix = matrix_perspective_right_hand_gl(radians_from_degrees(65.0f),
                                                         aspect,
                                                         1.0f, 5000.0);
    [_camera resizeWithSize:size];
}

- (GLuint)textureWithContentsOfFile:(NSString *)name
                         resolution:(CGSize *)size
                              isHDR:(BOOL)isHDR
{
    //NSLog(@"%@", names);
    GLuint textureID = 0;
    GLint width = 0;
    GLint height = 0;
    GLint numComponents = 0;

    NSBundle *mainBundle = [NSBundle mainBundle];
    // The objects of filePath should be either NSString or NSURL
    NSArray<NSString *> *subStrings = [name componentsSeparatedByString:@"."];
    
    NSString* filePath = [mainBundle pathForResource:subStrings[0]
                                              ofType:subStrings[1]];
    if (isHDR == YES) {
        glGenTextures(1, &textureID);
        glBindTexture(GL_TEXTURE_2D, textureID);
        // The flag stbi__vertically_flip_on_load defaults to false
        GLfloat *data = nil;
        data = stbi_loadf([filePath UTF8String],
                          &width, &height, &numComponents, 0);
        if (data != nil) {
            glTexImage2D(GL_TEXTURE_2D,
                         0,
                         GL_RGB16F,
                         width, height,
                         0,
                         GL_RGB,
                         GL_FLOAT,
                         data);
            stbi_image_free(data);

            glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
            glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
            glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
            glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
            size->width = width;
            size->height = height;
        }
    }
    else {
        NSDictionary *loaderOptions = @{
            GLKTextureLoaderOriginBottomLeft : @NO,
            //GLKTextureLoaderSRGB : @YES
        };
        NSError *error = nil;
        GLKTextureInfo *textureInfo = [GLKTextureLoader textureWithContentsOfFile:filePath
                                                                          options:loaderOptions
                                                                            error:&error];
        if (error != nil) {
            NSLog(@"Cannot instantiate a texture from the file:%@ Error Code:%@", filePath, error);
        }
        //NSLog(@"%@", textureInfo);
        textureID = textureInfo.name;
        size->width = textureInfo.width;
        size->height = textureInfo.height;
    }
    return textureID;
}

- (void)updateCamera
{
    [_camera update:1.0f/60.0f];
}

- (void)draw
{
    glClearColor(0.5, 0.5, 0.5, 1.0);
    glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
    // Bind the quad vertex array object.
    glViewport(0, 0,
               _viewSize.width, _viewSize.height);

    [self updateCamera];
    matrix_float4x4 viewMatrix = _camera.viewMatrix;
    matrix_float4x4 modelMatrix = simd_matrix4x4(_camera.orientation);
    glUseProgram(_glslProgram);
    glUniformMatrix4fv(_projectionMatrixLoc, 1, GL_FALSE, (const GLfloat*)&_projectionMatrix);
    glUniformMatrix4fv(_viewMatrixLoc, 1, GL_FALSE, (const GLfloat*)&viewMatrix);
    glUniformMatrix4fv(_modelMatrixLoc, 1, GL_FALSE, (const GLfloat*)&modelMatrix);
    glActiveTexture(GL_TEXTURE0);
    glBindTexture(GL_TEXTURE_CUBE_MAP, _cubemapTextureID);
    [self renderCube];
    glUseProgram(0);
    glBindVertexArray(0);
} // draw

/*
 Input:
    textureNames - an array of 2 texture identifiers
    faceSize - size of each face of the cube
 */
- (GLuint)cubemapFromParaboloidMap:(GLuint *)textureNames
                          faceSize:(GLuint)size
{
    glBindVertexArray(_cubeVAO);
    NSBundle *mainBundle = [NSBundle mainBundle];
    NSURL *vertexSourceURL = [mainBundle URLForResource:@"CubemapVertexShader"
                                          withExtension:@"glsl"];
    NSURL *fragmentSourceURL = [mainBundle URLForResource:@"CubemapFragmentShader3"
                                            withExtension:@"glsl"];
    GLuint program = [OpenGLRenderer buildProgramWithVertexSourceURL:vertexSourceURL
                                               withFragmentSourceURL:fragmentSourceURL];
    GLuint cubemapID;
    glGenTextures(1, &cubemapID);
    glBindTexture(GL_TEXTURE_CUBE_MAP, cubemapID);
    for (unsigned int i=0; i<6; i++) {
        glTexImage2D(GL_TEXTURE_CUBE_MAP_POSITIVE_X + i,
                     0,
                     GL_RGBA16F,            // internal format
                     size, size,            // width, height
                     0,
                     GL_RGBA,               // format
                     GL_FLOAT,              // type
                     nil);                  // allocate space for the pixels.
    }
    // Set its default filter parameters
    glTexParameteri(GL_TEXTURE_CUBE_MAP, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
    glTexParameteri(GL_TEXTURE_CUBE_MAP, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
    glTexParameteri(GL_TEXTURE_CUBE_MAP, GL_TEXTURE_WRAP_R, GL_CLAMP_TO_EDGE);
    glTexParameteri(GL_TEXTURE_CUBE_MAP, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_CUBE_MAP, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
    glBindTexture(GL_TEXTURE_CUBE_MAP, 0);
    GetGLError();

    // Create and initialize an offscreen frame buffer object (fbo)
    GLuint fbo;
    GLuint rbo;
    glGenFramebuffers(1, &fbo);
    glGenRenderbuffers(1, &rbo);

    glBindFramebuffer(GL_FRAMEBUFFER, fbo);             // read & draw
    glBindRenderbuffer(GL_RENDERBUFFER, rbo);
    glRenderbufferStorage((GLenum)GL_RENDERBUFFER,
                          (GLenum)GL_DEPTH_COMPONENT24,
                          (GLsizei)size, (GLsizei)size);
    glFramebufferRenderbuffer(GL_FRAMEBUFFER,
                              GL_DEPTH_ATTACHMENT,
                              GL_RENDERBUFFER,
                              rbo);
    CheckFramebuffer();

    // Set up the common perspective projection which has a 90-degree FOV horizontally and vertically.
    // Note: the aspect ratio is 1.0 indicating the width and height of the base of the frustum are equal.
    // And therefore, the horizontal FOV = vertical FOV.
    matrix_float4x4 captureProjectionMatrix = matrix_perspective_right_hand_gl(radians_from_degrees(90),
                                                                               1.0,
                                                                               0.1, 10.0);
    
    // Set up 6 view matrices for capturing data onto the six 2D textures of the cubemap.
    // Remember the virtual camera is inside the cube and at cube's centre.
    matrix_float4x4 captureViewMatrices[6];
    // The camera is rotated -90 degrees about the y-axis from its initial position.
    // Remember the 3D coordinate system is LHS inside the box.
    captureViewMatrices[0] = matrix_look_at_right_hand_gl((vector_float3){ 0,  0, 0},   // eye is at the centre of the cube.
                                                          (vector_float3){ 1,  0, 0},   // centre of +X face
                                                          (vector_float3){ 0, -1, 0});  // Up
    
    // The camera is rotated +90 degrees about the y-axis from its initial position.
    captureViewMatrices[1] = matrix_look_at_right_hand_gl((vector_float3){ 0,  0, 0},   // eye is at the centre of the cube.
                                                          (vector_float3){-1,  0, 0},   // centre of -X face
                                                          (vector_float3){ 0, -1, 0});  // Up
    
    // The camera is rotated -90 degrees about the x-axis from its initial position.
    captureViewMatrices[2] = matrix_look_at_right_hand_gl((vector_float3){ 0,  0, 0},   // eye is at the centre of the cube.
                                                          (vector_float3){ 0,  1, 0},   // centre of +Y face
                                                          (vector_float3){ 0,  0, 1});  // Up
    
    // The camera is rotated +90 degrees about the x-axis from its initial position.
    captureViewMatrices[3] = matrix_look_at_right_hand_gl((vector_float3){ 0,  0,  0},  // eye is at the centre of the cube.
                                                          (vector_float3){ 0, -1,  0},  // centre of -Y face
                                                          (vector_float3){ 0,  0, -1}); // Up
    
    // The camera is placed at its initial position pointing in the +z direction
    //  with its up vector pointing in the -y direction.
    captureViewMatrices[4] = matrix_look_at_right_hand_gl((vector_float3){ 0,  0, 0},   // eye is at the centre of the cube.
                                                          (vector_float3){ 0,  0, 1},   // centre of +Z face
                                                          (vector_float3){ 0, -1, 0});  // Up
    
    // The camera is rotated -180 (+180) degrees about the y-axis from its initial position.
    captureViewMatrices[5] = matrix_look_at_right_hand_gl((vector_float3){ 0,  0,  0},  // eye is at the centre of the cube.
                                                          (vector_float3){ 0,  0, -1},  // centre of -Z face
                                                          (vector_float3){ 0, -1,  0}); // Up

    //GLint vertAttrLoc = glGetAttribLocation(program, "aPos");
    //printf("attribute location:%d\n", vertAttrLoc);
    // Prepare to draw.
    glUseProgram(program);
    GLint frontImageLoc = glGetUniformLocation(program, "frontImage");
    GLint backImageLoc = glGetUniformLocation(program, "backImage");
    //printf("%d %d\n", frontImageLoc, backImageLoc);
    GLint projectionMatrixLoc = glGetUniformLocation(program, "projectionMatrix");
    GLint viewMatrixLoc = glGetUniformLocation(program, "viewMatrix");
    //printf("%d %d\n", projectionMatrixLoc, viewMatrixLoc);
    glUniformMatrix4fv(projectionMatrixLoc, 1, GL_FALSE, (const GLfloat*)&captureProjectionMatrix);

    glUniform1i(frontImageLoc, 0);
    glActiveTexture(GL_TEXTURE0);
    glBindTexture(GL_TEXTURE_2D, textureNames[0]);
    glUniform1i(backImageLoc, 1);
    glActiveTexture(GL_TEXTURE1);
    glBindTexture(GL_TEXTURE_2D, textureNames[1]);
    // fbo already bound.
    glBindFramebuffer(GL_FRAMEBUFFER, fbo);
    //glClearColor(0.5, 0.0, 0.0, 1.0);
    //glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
    glViewport(0, 0,
               size, size);
    // The fragment shader's main function is not even called.
    for (unsigned int i = 0; i < 6; ++i) {
        glUniformMatrix4fv(viewMatrixLoc, 1, GL_FALSE, (const GLfloat*)&captureViewMatrices[i]);
        glFramebufferTexture2D(GL_FRAMEBUFFER,                      // target
                               GL_COLOR_ATTACHMENT0,                // attachment
                               GL_TEXTURE_CUBE_MAP_POSITIVE_X + i,  // texture target
                               cubemapID,                           // texture id
                               0);                                  // mipmap level
        glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
        [self renderCube];
    }
    glBindTexture(GL_TEXTURE_2D, 0);
    glUseProgram(0);
    GetGLError();

    glDeleteProgram(program);
    glDeleteRenderbuffers(1, &rbo);
    glDeleteFramebuffers(1, &fbo);

    glBindFramebuffer(GL_FRAMEBUFFER, _defaultFBOName);
    return cubemapID;
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

#if TARGET_IOS
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

    //GLint samplerLoc = glGetUniformLocation(prgName, "baseColorMap");

    //NSAssert(samplerLoc >= 0, @"No uniform location found from `baseColorMap`.");

    //glUseProgram(prgName);

    // Indicate that the diffuse texture will be bound to texture unit 0.
   // glUniform1i(samplerLoc, AAPLTextureIndexBaseColor);

    GetGLError();

    return prgName;
}

@end
