/*
*/

#import <Foundation/Foundation.h>
#include <CoreGraphics/CoreGraphics.h>
#import <GLKit/GLKTextureLoader.h>
#import "OpenGLHeaders.h"

@class VirtualCamera;

static const CGSize AAPLInteropTextureSize = {1024, 1024};

@interface OpenGLRenderer : NSObject {
}

- (instancetype)initWithDefaultFBOName:(GLuint)defaultFBOName;

- (void)draw;

- (void)resize:(CGSize)size;

@property (nonatomic) VirtualCamera* _Nonnull camera;

@end
