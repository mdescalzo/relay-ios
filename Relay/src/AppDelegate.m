#import "AppDelegate.h"
#import "AppStoreRating.h"
#import "CategorizingLogger.h"
#import "CodeVerificationViewController.h"
#import "DebugLogger.h"
#import "Environment.h"
#import "NotificationsManager.h"
#import "FLContactsManager.h"
#import "OWSStaleNotificationObserver.h"
#import "PropertyListPreferences.h"
#import "PushManager.h"
#import "Release.h"
#import "Relay-Swift.h"
#import "TSMessagesManager.h"
#import "TSPreKeyManager.h"
#import "TSSocketManager.h"
#import "TextSecureKitEnv.h"
#import <PastelogKit/Pastelog.h>
#import <PromiseKit/AnyPromise.h>
#import "OWSDisappearingMessagesJob.h"
#import "OWSIncomingMessageReadObserver.h"
#import "FLMessageSender.h"
#import "TSAccountManager.h"

#import "CCSMCommunication.h"
#import "CCSMStorage.h"

@import Fabric;
@import Crashlytics;

NSString *const AppDelegateStoryboardMain = @"Main_v2";
NSString *const AppDelegateStoryboardRegistration = @"Registration";
NSString *const AppDelegateStoryboardLogin = @"Login";
NSString *const AppDelegateStoryboardLaunchScreen = @"Launch Screen";


static NSString *const kInitialViewControllerIdentifier = @"UserInitialViewController";
static NSString *const kURLSchemeSGNLKey                = @"sgnl";
static NSString *const kURLHostVerifyPrefix             = @"verify";

@interface AppDelegate ()

@property (nonatomic, strong) UIWindow *screenProtectionWindow;
@property (nonatomic, strong) OWSIncomingMessageReadObserver *incomingMessageReadObserver;
@property (nonatomic, strong) OWSStaleNotificationObserver *staleNotificationObserver;
@property (nonatomic, assign) BOOL hasRootViewController;
@property (nonatomic, assign) BOOL awaitingVerification;

@end

@implementation AppDelegate

- (void)applicationWillEnterForeground:(UIApplication *)application {
    [[UIApplication sharedApplication] setApplicationIconBadgeNumber:0];
}

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    
    // Initializing logger
    CategorizingLogger *logger = [CategorizingLogger categorizingLogger];
    [logger addLoggingCallback:^(NSString *category, id details, NSUInteger index){
    }];
    
    
    // Initialize crash reporting
    [Crashlytics startWithAPIKey:[self fabricAPIKey]];
    
    // Navbar background color iOS10 bug workaround
    [UINavigationBar appearance].backgroundColor = [UIColor blackColor];
    [UINavigationBar appearance].barTintColor = [UIColor blackColor];
    [UINavigationBar appearance].tintColor = [UIColor whiteColor];
    [UINavigationBar appearance].translucent = YES;
    
    // Setting up environment
    [Environment setCurrent:[Release releaseEnvironmentWithLogging:logger]];
    [[NSUserDefaults standardUserDefaults] setBool:NO forKey:FLAwaitingVerification];
    [[NSUserDefaults standardUserDefaults] synchronize];
    
    [[PushManager sharedManager] registerPushKitNotificationFuture];
    
    if (getenv("runningTests_dontStartApp")) {
        return YES;
    }
    
    if ([TSAccountManager isRegistered]) {
        [Environment.getCurrent.contactsManager doAfterEnvironmentInitSetup];
    }
    
    BOOL loggingIsEnabled;
#ifdef DEBUG
    // Specified at Product -> Scheme -> Edit Scheme -> Test -> Arguments -> Environment to avoid things like
    // the phone directory being looked up during tests.
    loggingIsEnabled = TRUE;
    [DebugLogger.sharedLogger enableTTYLogging];
#elif RELEASE
    loggingIsEnabled = Environment.preferences.loggingIsEnabled;
#endif
    
    [self verifyBackgroundBeforeKeysAvailableLaunch];
    
    if (loggingIsEnabled) {
        [DebugLogger.sharedLogger enableFileLogging];
    }
    
    [self setupTSKitEnv];
    
    self.window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
    // TODO: Generate an informational loading to display here.
    UIStoryboard *storyboard = [UIStoryboard storyboardWithName:AppDelegateStoryboardLaunchScreen bundle:[NSBundle mainBundle]];
    self.window.rootViewController = [storyboard instantiateInitialViewController];
    [self.window makeKeyAndVisible];
    
    // Accept push notification when app is not open
    NSDictionary *remoteNotif = launchOptions[UIApplicationLaunchOptionsRemoteNotificationKey];
    if (remoteNotif) {
        DDLogInfo(@"Application was launched by tapping a push notification.");
        [self application:application didReceiveRemoteNotification:remoteNotif];
    }
    
    [self prepareScreenProtection];
    
    // Avoid blocking app launch by putting all further possible DB access in async thread.
    UIApplicationState launchState = application.applicationState;
    [[TSAccountManager sharedInstance] ifRegistered:YES runAsync:^{
        if (launchState == UIApplicationStateInactive) {
            DDLogWarn(@"The app was launched from inactive");
            [TSSocketManager becomeActiveFromForeground];
        } else if (launchState == UIApplicationStateBackground) {
            DDLogWarn(@"The app was launched from being backgrounded");
            [TSSocketManager becomeActiveFromBackgroundExpectMessage:YES];
        } else {
            DDLogWarn(@"The app was launched in an unknown way");
        }
        
        OWSAccountManager *accountManager = [[OWSAccountManager alloc] initWithTextSecureAccountManager:[TSAccountManager sharedInstance]];
        
        [OWSSyncPushTokensJob runWithPushManager:[PushManager sharedManager]
                                  accountManager:accountManager
                                     preferences:[Environment preferences]].then(^{
            DDLogDebug(@"%@ Successfully ran syncPushTokensJob.", self.tag);
        }).catch(^(NSError *_Nonnull error) {
            DDLogDebug(@"%@ Failed to run syncPushTokensJob with error: %@", self.tag, error);
        });
        
        [TSPreKeyManager refreshPreKeys];
        
        // Clean up any messages that expired since last launch.
        [[[OWSDisappearingMessagesJob alloc] initWithStorageManager:[TSStorageManager sharedManager]] run];
        [AppStoreRating setupRatingLibrary];
    }];
    
    return YES;
}

- (void)setupTSKitEnv {
    [TextSecureKitEnv sharedEnv].contactsManager = [Environment getCurrent].contactsManager;
    [[TSStorageManager sharedManager] setupDatabase];
    [TextSecureKitEnv sharedEnv].notificationsManager = [[NotificationsManager alloc] init];
    
    OWSMessageSender *messageSender =
    [[OWSMessageSender alloc] initWithNetworkManager:[Environment getCurrent].networkManager
                                      storageManager:[TSStorageManager sharedManager]
                                     contactsManager:[Environment getCurrent].contactsManager];
    //                                     contactsUpdater:[Environment getCurrent].contactsUpdater];
    
    self.incomingMessageReadObserver =
    [[OWSIncomingMessageReadObserver alloc] initWithStorageManager:[TSStorageManager sharedManager]
                                                     messageSender:messageSender];
    [self.incomingMessageReadObserver startObserving];
    
    self.staleNotificationObserver = [OWSStaleNotificationObserver new];
    [self.staleNotificationObserver startObserving];
}

- (void)application:(UIApplication *)application didRegisterForRemoteNotificationsWithDeviceToken:(NSData *)deviceToken
{
    DDLogDebug(@"%@ Successfully registered for remote notifications with token: %@", self.tag, deviceToken);
    [PushManager.sharedManager.pushNotificationFutureSource trySetResult:deviceToken];
}

- (void)application:(UIApplication *)application didFailToRegisterForRemoteNotificationsWithError:(NSError *)error
{
    DDLogError(@"%@ Failed to register for remote notifications with error %@", self.tag, error);
#ifdef DEBUG
    DDLogWarn(@"%@ We're in debug mode. Faking success for remote registration with a fake push identifier", self.tag);
    [PushManager.sharedManager.pushNotificationFutureSource trySetResult:[NSData dataWithLength:32]];
#else
    [PushManager.sharedManager.pushNotificationFutureSource trySetFailure:error];
#endif
}

- (void)application:(UIApplication *)application
didRegisterUserNotificationSettings:(UIUserNotificationSettings *)notificationSettings {
    [PushManager.sharedManager.userNotificationFutureSource trySetResult:notificationSettings];
}

- (BOOL)application:(UIApplication *)application
            openURL:(NSURL *)url
  sourceApplication:(NSString *)sourceApplication
         annotation:(id)annotation {
    if ([url.scheme isEqualToString:kURLSchemeSGNLKey]) {
        if ([url.host hasPrefix:kURLHostVerifyPrefix] && ![TSAccountManager isRegistered]) {
            id signupController = [Environment getCurrent].signUpFlowNavigationController;
            if ([signupController isKindOfClass:[UINavigationController class]]) {
                UINavigationController *navController = (UINavigationController *)signupController;
                UIViewController *controller          = [navController.childViewControllers lastObject];
                if ([controller isKindOfClass:[CodeVerificationViewController class]]) {
                    CodeVerificationViewController *cvvc = (CodeVerificationViewController *)controller;
                    NSString *verificationCode           = [url.path substringFromIndex:1];
                    
                    cvvc.challengeTextField.text = verificationCode;
                    [cvvc verifyChallengeAction:nil];
                } else {
                    DDLogWarn(@"Not the verification view controller we expected. Got %@ instead",
                              NSStringFromClass(controller.class));
                }
            }
        } else {
            DDLogWarn(@"Application opened with an unknown URL action: %@", url.host);
        }
    } else {
        DDLogWarn(@"Application opened with an unknown URL scheme: %@", url.scheme);
    }
    return NO;
}

- (void)applicationDidBecomeActive:(UIApplication *)application {
    if (getenv("runningTests_dontStartApp")) {
        return;
    }
    [self ensureRootViewController];
    [self removeScreenProtection];
    
    // Refresh local data from CCSM
    if ([TSAccountManager isRegistered]) {
        [TSSocketManager becomeActiveFromForeground];
        [CCSMCommManager refreshSessionTokenAsynchronousSuccess:^{  // Refresh success
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0), ^{
                [self refreshUsersStore];
            });
        }
                                                        failure:^(NSError *error){
                                                            // Unable to refresh, login force login
                                                            DDLogDebug(@"Token Refresh failed with error: %@", error.description);
                                                            
                                                            // Determine if this eror should kick the user out:
                                                            if (error.code >= 400 && error.code < 500) {
                                                                //  Out they go...
                                                                [TSSocketManager resignActivity];
                                                                dispatch_async(dispatch_get_main_queue(), ^{
                                                                    UIAlertController *alert = [UIAlertController alertControllerWithTitle:nil                                                                                                                               message:NSLocalizedString(@"REFRESH_FAILURE_MESSAGE", nil)
                                                                                                                            preferredStyle:UIAlertControllerStyleActionSheet];
                                                                    UIAlertAction *okAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"OK", nil)
                                                                                                                       style:UIAlertActionStyleDefault
                                                                                                                     handler:^(UIAlertAction *action) {
                                                                                                                         UIStoryboard *storyboard = [UIStoryboard storyboardWithName:AppDelegateStoryboardLogin bundle:[NSBundle mainBundle]];
                                                                                                                         self.window.rootViewController = [storyboard instantiateInitialViewController];
                                                                                                                         [self.window makeKeyAndVisible];
                                                                                                                     }];
                                                                    [alert addAction:okAction];
                                                                    [self.window.rootViewController presentViewController:alert animated:YES completion:nil];
                                                                });
                                                            } else {
                                                                dispatch_async(dispatch_get_main_queue(), ^{
                                                                    UIAlertController *alert = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"Server Connection Failed", @"")
                                                                                                                                   message:[NSString stringWithFormat:@"Error: %ld\n%@", (long)error.code, error.localizedDescription]
                                                                                                                            preferredStyle:UIAlertControllerStyleActionSheet];
                                                                    UIAlertAction *okButton = [UIAlertAction actionWithTitle:NSLocalizedString(@"OK", @"")
                                                                                                                       style:UIAlertActionStyleDefault
                                                                                                                     handler:^(UIAlertAction * action) {} ];
                                                                    [alert addAction:okButton];
                                                                    [self.window.rootViewController presentViewController:alert animated:YES completion:nil];
                                                                });
                                                            }
                                                        }];
        
    } else {
        // User not logged in.
        dispatch_async(dispatch_get_main_queue(), ^{
            UIStoryboard *storyboard = [UIStoryboard storyboardWithName:AppDelegateStoryboardLogin bundle:[NSBundle mainBundle]];
            self.window.rootViewController = [storyboard instantiateInitialViewController];
            [self.window makeKeyAndVisible];
        });
    }
    if ([Environment.getCurrent.ccsmStorage getUserName] != nil) {
        [CrashlyticsKit setUserName:[Environment.getCurrent.ccsmStorage getUserName]];
    }

}


- (void)applicationWillResignActive:(UIApplication *)application {
    UIBackgroundTaskIdentifier __block bgTask = UIBackgroundTaskInvalid;
    bgTask                                    = [application beginBackgroundTaskWithExpirationHandler:^{
        
    }];
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        if ([TSAccountManager isRegistered]) {
            dispatch_sync(dispatch_get_main_queue(), ^{
                [self protectScreen];
                [[[Environment getCurrent] forstaViewController] updateInboxCountLabel];
            });
            [TSSocketManager resignActivity];
        }
        
        [application endBackgroundTask:bgTask];
        bgTask = UIBackgroundTaskInvalid;
    });
}

- (void)application:(UIApplication *)application
performActionForShortcutItem:(UIApplicationShortcutItem *)shortcutItem
  completionHandler:(void (^)(BOOL succeeded))completionHandler {
    if ([TSAccountManager isRegistered]) {
        [[Environment getCurrent].forstaViewController composeNew:nil];
        completionHandler(YES);
    } else {
        UIAlertController *controller =
        [UIAlertController alertControllerWithTitle:NSLocalizedString(@"REGISTER_CONTACTS_WELCOME", nil)
                                            message:NSLocalizedString(@"REGISTRATION_RESTRICTED_MESSAGE", nil)
                                     preferredStyle:UIAlertControllerStyleAlert];
        
        [controller addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"OK", nil)
                                                       style:UIAlertActionStyleDefault
                                                     handler:^(UIAlertAction *_Nonnull action){
                                                         
                                                     }]];
        [[Environment getCurrent]
         .forstaViewController.presentedViewController presentViewController:controller
         animated:YES
         completion:^{
             completionHandler(NO);
         }];
    }
}

/**
 * Screen protection obscures the app screen shown in the app switcher.
 */
- (void)prepareScreenProtection
{
    UIWindow *window = [[UIWindow alloc] initWithFrame:self.window.bounds];
    window.hidden = YES;
    window.opaque = YES;
    window.userInteractionEnabled = NO;
    window.windowLevel = CGFLOAT_MAX;
    window.backgroundColor = UIColor.ows_materialBlueColor;
    window.rootViewController =
    [[UIStoryboard storyboardWithName:@"Launch Screen" bundle:nil] instantiateInitialViewController];
    
    self.screenProtectionWindow = window;
}

- (void)protectScreen {
    if (Environment.preferences.screenSecurityIsEnabled) {
        self.screenProtectionWindow.hidden = NO;
    }
}

- (void)removeScreenProtection {
    if (Environment.preferences.screenSecurityIsEnabled) {
        self.screenProtectionWindow.hidden = YES;
    }
}

-(void)refreshUsersStore
{
    [CCSMCommManager refreshCCSMData];
}

#pragma mark - Push Notifications Delegate Methods

- (void)application:(UIApplication *)application didReceiveRemoteNotification:(NSDictionary *)userInfo {
    [[PushManager sharedManager] application:application didReceiveRemoteNotification:userInfo];
}
- (void)application:(UIApplication *)application
didReceiveRemoteNotification:(NSDictionary *)userInfo
fetchCompletionHandler:(void (^)(UIBackgroundFetchResult))completionHandler {
    [[PushManager sharedManager] application:application
                didReceiveRemoteNotification:userInfo
                      fetchCompletionHandler:completionHandler];
}

- (void)application:(UIApplication *)application didReceiveLocalNotification:(UILocalNotification *)notification {
    [[PushManager sharedManager] application:application didReceiveLocalNotification:notification];
}

- (void)application:(UIApplication *)application
handleActionWithIdentifier:(NSString *)identifier
forLocalNotification:(UILocalNotification *)notification
  completionHandler:(void (^)())completionHandler {
    [[PushManager sharedManager] application:application
                  handleActionWithIdentifier:identifier
                        forLocalNotification:notification
                           completionHandler:completionHandler];
}

- (void)application:(UIApplication *)application
handleActionWithIdentifier:(NSString *)identifier
forLocalNotification:(UILocalNotification *)notification
   withResponseInfo:(NSDictionary *)responseInfo
  completionHandler:(void (^)())completionHandler {
    [[PushManager sharedManager] application:application
                  handleActionWithIdentifier:identifier
                        forLocalNotification:notification
                            withResponseInfo:responseInfo
                           completionHandler:completionHandler];
}

#pragma mark - Helpers
-(void)ensureRootViewController
{
    if (!self.hasRootViewController) {
        self.hasRootViewController = YES;
        UIStoryboard *storyboard = nil;
        if ([TSAccountManager isRegistered]) { // Check for local sessionKey
//            [TSSocketManager becomeActiveFromForeground];
            storyboard = [UIStoryboard storyboardWithName:AppDelegateStoryboardMain bundle:[NSBundle mainBundle]];
            self.window.rootViewController = [storyboard instantiateInitialViewController];
            [self.window makeKeyAndVisible];
        } else { // No local token, login
            storyboard = [UIStoryboard storyboardWithName:AppDelegateStoryboardLogin bundle:[NSBundle mainBundle]];
            self.window.rootViewController = [storyboard instantiateInitialViewController];
            [self.window makeKeyAndVisible];
        }
    }
}

/**
 *  Signal requires an iPhone to be unlocked after reboot to be able to access keying material.
 */
- (void)verifyBackgroundBeforeKeysAvailableLaunch {
    if ([self applicationIsActive]) {
        return;
    }
    
    if (![[TSStorageManager sharedManager] databasePasswordAccessible]) {
        UILocalNotification *notification = [[UILocalNotification alloc] init];
        notification.alertBody            = NSLocalizedString(@"PHONE_NEEDS_UNLOCK", nil);
        [[UIApplication sharedApplication] presentLocalNotificationNow:notification];
        exit(0);
    }
}

- (BOOL)applicationIsActive {
    UIApplication *app = [UIApplication sharedApplication];
    
    if (app.applicationState == UIApplicationStateActive) {
        return YES;
    }
    
    return NO;
}

#pragma mark - Crashlytics
-(NSString *)fabricAPIKey
{
    NSString *path = [[NSBundle mainBundle] pathForResource:@"Forsta-values" ofType:@"plist"];
    NSFileManager *fileManager = [NSFileManager defaultManager];
    
    if ([fileManager fileExistsAtPath: path]) {
        NSDictionary *forstaDict = [[NSDictionary alloc] initWithContentsOfFile:path];
        NSDictionary *fabricDict = [forstaDict objectForKey:@"Fabric"];
        return [fabricDict objectForKey:@"APIKey"];
    } else {
        return @"";
    }
}

#pragma mark - Logging

+ (NSString *)tag
{
    return [NSString stringWithFormat:@"[%@]", self.class];
}

- (NSString *)tag
{
    return self.class.tag;
}

-(BOOL)awaitingVerification
{
    return [[NSUserDefaults standardUserDefaults] boolForKey:FLAwaitingVerification];
}

@end

