#import <UIKit/UIKit.h>

//#import "SignalsViewController.h"
#import "FLThreadViewController.h"

extern NSString *const AppDelegateStoryboardMain;
extern NSString *const AppDelegateStoryboardRegistration;

@interface AppDelegate : UIResponder <UIApplicationDelegate>

@property (strong, nonatomic) UIWindow *window;
//@property (strong, nonatomic) SignalsViewController *signalVC;
@property (strong, nonatomic) FLThreadViewController *forstaVC;

@end
