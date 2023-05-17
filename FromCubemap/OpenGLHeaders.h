/*
*/
#ifndef AAPLGLHeaders_h
#define AAPLGLHeaders_h

#import <TargetConditionals.h>

#if TARGET_OS_OSX

#import <OpenGL/OpenGL.h>
#import <OpenGL/gl.h>
#import <OpenGL/gl3.h>
#import <OpenGL/gl3ext.h>

#else // if (TARGET_OS_IOS || TARGET_OS_TVOS)

#import <OpenGLES/EAGL.h>
#import <OpenGLES/ES2/gl.h>
#import <OpenGLES/ES2/glext.h>
#import <OpenGLES/ES3/gl.h>

#endif // !(TARGET_OS_IOS || TARGET_OS_TVOS)

// The name of the vertex array objects are slightly different in OpenGL ES, OpenGL Core
// Profile, and OpenGL Legacy. Howeverm the arguments are exactly the same across these APIs.

#if (TARGET_OS_IOS || TARGET_OS_TVOS)
#define glBindVertexArray glBindVertexArrayOES
#define glGenVertexArrays glGenVertexArraysOES
#define glDeleteVertexArrays glDeleteVertexArraysOES
#endif // !(TARGET_OS_IOS || TARGET_OS_TVOS)


#define BUFFER_OFFSET(i) ((char *)NULL + (i))

static inline void CheckFramebuffer(void)
{
    const char *str;
    
    GLenum status = glCheckFramebufferStatus(GL_FRAMEBUFFER);
    if (status != GL_FRAMEBUFFER_COMPLETE) {
        if (status == GL_FRAMEBUFFER_UNDEFINED)
            str =  "undefined framebuffer";
        else if (status == GL_FRAMEBUFFER_INCOMPLETE_ATTACHMENT)
            str =  "a necessary attachment is uninitialized";
        else if (status == GL_FRAMEBUFFER_INCOMPLETE_MISSING_ATTACHMENT)
            str =  "no attachments";
#if TARGET_OS_OSX
        else if (status == GL_FRAMEBUFFER_INCOMPLETE_DRAW_BUFFER)
            str =  "incomplete draw buffer";
        else if (status == GL_FRAMEBUFFER_INCOMPLETE_READ_BUFFER)
            str =  "incomplete read buffer";
        else if (status == GL_FRAMEBUFFER_INCOMPLETE_LAYER_TARGETS)
            str = "incomplete layer targets";
#endif
        else if (status == GL_FRAMEBUFFER_UNSUPPORTED)
            str =  "combination of attachments is not supported";
        else if (status == GL_FRAMEBUFFER_INCOMPLETE_MULTISAMPLE)
            str = "number if samples for all attachments does not match";
        printf("OpenGL Framebuffer Error:  \t%s\n", str);
    }
}

static inline const char * GetGLErrorString(GLenum error)
{
    const char *str;
    switch( error )
    {
        case GL_NO_ERROR:
            str = "GL_NO_ERROR";
            break;
        case GL_INVALID_ENUM:
            str = "GL_INVALID_ENUM";
            break;
        case GL_INVALID_VALUE:
            str = "GL_INVALID_VALUE";
            break;
        case GL_INVALID_OPERATION:
            str = "GL_INVALID_OPERATION";
            break;
        case GL_OUT_OF_MEMORY:
            str = "GL_OUT_OF_MEMORY";
            break;
        case GL_INVALID_FRAMEBUFFER_OPERATION:
            str = "GL_INVALID_FRAMEBUFFER_OPERATION";
            break;
#if defined __gl_h_
        case GL_STACK_OVERFLOW:
            str = "GL_STACK_OVERFLOW";
            break;
        case GL_STACK_UNDERFLOW:
            str = "GL_STACK_UNDERFLOW";
            break;
        case GL_TABLE_TOO_LARGE:
            str = "GL_TABLE_TOO_LARGE";
            break;
#endif
        default:
            str = "(ERROR: Unknown Error Enum)";
            break;
    }
    return str;
}

#define GetGLError()                                  \
{                                                     \
    GLenum err = glGetError();                        \
    while (err != GL_NO_ERROR)                        \
    {                                                 \
        NSLog(@"GLError %s set in File:%s Line:%d\n", \
        GetGLErrorString(err), __FILE__, __LINE__);   \
        err = glGetError();                           \
    }                                                 \
}

#endif
