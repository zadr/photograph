#import "PGPhotographApplication.h"

#import "PGViewController.h"

@implementation PGPhotographApplication
- (BOOL) application:(UIApplication *) application didFinishLaunchingWithOptions:(NSDictionary *) launchOptions {
	_window = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
	_window.rootViewController = [[PGViewController alloc] init];

	[_window makeKeyAndVisible];

	return YES;
}
@end
