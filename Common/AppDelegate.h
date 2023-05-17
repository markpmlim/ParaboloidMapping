/*
See LICENSE folder for this sample’s licensing information.

Abstract:
Header for the iOS app delegate.
*/

#if defined(TARGET_IOS)
#import <UIKit/UIKit.h>

@interface AppDelegate : UIResponder <UIApplicationDelegate>

@property (strong, nonatomic) UIWindow *window;

#else
#import <AppKit/AppKit.h>

@interface AppDelegate : NSResponder <NSApplicationDelegate>

@property (strong, nonatomic) NSWindow *window;

#endif


@end
