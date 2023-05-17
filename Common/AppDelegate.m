/*
See LICENSE folder for this sample’s licensing information.

Abstract:
Implementation of the iOS app delegate.
*/

#import "AppDelegate.h"

@implementation AppDelegate

#if defined(TARGET_IOS)
- (BOOL)application:(UIApplication *)application
didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    return YES;
}

#else

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
    // Insert code here to initialize your application
}


- (void)applicationWillTerminate:(NSNotification *)aNotification
{
    // Insert code here to tear down your application
}

- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)sender
{
    return YES;
}
#endif
@end
