/*
*/

#import <Foundation/Foundation.h>
#include <CoreGraphics/CoreGraphics.h>
#import <GLKit/GLKTextureLoader.h>
#import "OpenGLHeaders.h"

@interface OpenGLRenderer: NSObject

- (instancetype)initWithDefaultFBOName:(GLuint)defaultFBOName;

- (void)draw;

- (void)resize:(CGSize)size;

@property GLuint frontTextureID;
@property GLuint backTextureID;

@end
