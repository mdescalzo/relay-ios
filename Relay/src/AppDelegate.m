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
#import "SmileAuthenticator.h"
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

@interface AppDelegate () <SmileAuthenticatorDelegate>

@property (nonatomic, strong) UIWindow *screenProtectionWindow;
@property (nonatomic, strong) OWSIncomingMessageReadObserver *incomingMessageReadObserver;
@property (nonatomic, strong) OWSStaleNotificationObserver *staleNotificationObserver;
@property (nonatomic, assign) BOOL hasRootViewController;
@property (nonatomic, assign) BOOL awaitingVerification;

@property (nonatomic, strong) UIImageView *coverImageView;

@end

@implementation AppDelegate

- (void)applicationWillEnterForeground:(UIApplication *)application {
    [[UIApplication sharedApplication] setApplicationIconBadgeNumber:0];
}

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    if (getenv("runningTests_dontStartApp")) {
        return YES;
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
    
    if (loggingIsEnabled) {
        [DebugLogger.sharedLogger enableFileLogging];
    }
    DDLogDebug(@"DebugLogger setup complete.");
    
    DDLogDebug(@"didFinishLaunchingWithOptions Begins.");
    DDLogDebug(@"Crashlytics starts.");
    // Initialize crash reporting
    [Crashlytics startWithAPIKey:[self fabricAPIKey]];
    [Fabric with:@[ [Crashlytics class] ]];

    // Initializing logger
    DDLogDebug(@"CategorizingLogger starts.");
    CategorizingLogger *logger = [CategorizingLogger categorizingLogger];
    [logger addLoggingCallback:^(NSString *category, id details, NSUInteger index){
    }];
    
    DDLogDebug(@"Environment object init.");
    // Setting up environment
    [Environment setCurrent:[Release releaseEnvironmentWithLogging:logger]];

    // Moved this to ensureRootViewController method since this was redundent.
//    DDLogDebug(@"Init main window and make visible.");
//    self.window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
//    // TODO: Generate an informational loading view to display here.
//    UIStoryboard *storyboard = [UIStoryboard storyboardWithName:AppDelegateStoryboardLaunchScreen bundle:[NSBundle mainBundle]];
//    self.window.rootViewController = [storyboard instantiateInitialViewController];
//    [self.window makeKeyAndVisible];

    DDLogDebug(@"Navbar appearance setup.");
    // Navbar background color iOS10 bug workaround
    [UINavigationBar appearance].backgroundColor = [UIColor blackColor];
    [UINavigationBar appearance].barTintColor = [UIColor blackColor];
    [UINavigationBar appearance].tintColor = [UIColor whiteColor];
    [UINavigationBar appearance].translucent = YES;
    
    DDLogDebug(@"[self setupTSKitEnv] called.");
    [self setupTSKitEnv];
    
    DDLogDebug(@"TSAccountManager isRegistered called.");
    UIApplicationState launchState = application.applicationState;
    if ([TSAccountManager isRegistered]) {
        DDLogDebug(@"Pushmanager registers.");
        [[PushManager sharedManager] registerPushKitNotificationFuture];

        DDLogDebug(@"TSAccountManager isRegistered TRUE.");
        [Environment.getCurrent.contactsManager doAfterEnvironmentInitSetup];
        
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
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
        });
    }

    DDLogDebug(@"[self verifyBackgroundBeforeKeysAvailableLaunch] called.");
    [self verifyBackgroundBeforeKeysAvailableLaunch];
    
    DDLogDebug(@"Remote notification hanler.");
    // Accept push notification when app is not open
    NSDictionary *remoteNotif = launchOptions[UIApplicationLaunchOptionsRemoteNotificationKey];
    if (remoteNotif) {
        DDLogInfo(@"Application was launched by tapping a push notification.");
        [self application:application didReceiveRemoteNotification:remoteNotif];
    }
    
    DDLogDebug(@"didFinishLaunchingWithOptions ends.");
    return YES;
}

- (void)setupTSKitEnv
{
    DDLogDebug(@"[TextSecureKitEnv sharedEnv].contactsManager");
    [TextSecureKitEnv sharedEnv].contactsManager = [Environment getCurrent].contactsManager;

    DDLogDebug(@"[[TSStorageManager sharedManager] setupDatabase]");
    [[TSStorageManager sharedManager] setupDatabase];
    
    DDLogDebug(@"[TextSecureKitEnv sharedEnv].notificationsManager init");
    [TextSecureKitEnv sharedEnv].notificationsManager = [[NotificationsManager alloc] init];
    
    DDLogDebug(@"FLMessageSender *messageSender init");
    FLMessageSender *messageSender =
    [[FLMessageSender alloc] initWithNetworkManager:[Environment getCurrent].networkManager
                                      storageManager:[TSStorageManager sharedManager]
                                     contactsManager:[Environment getCurrent].contactsManager];
     
    DDLogDebug(@"incomingMessageReadObserver init");
    self.incomingMessageReadObserver =
    [[OWSIncomingMessageReadObserver alloc] initWithStorageManager:[TSStorageManager sharedManager]
                                                     messageSender:messageSender];
    DDLogDebug(@"incomingMessageReadObserver starts");
    [self.incomingMessageReadObserver startObserving];
    
    DDLogDebug(@"staleNotificationObserver init");
    self.staleNotificationObserver = [OWSStaleNotificationObserver new];
    DDLogDebug(@"staleNotificationObserver starts");
    [self.staleNotificationObserver startObserving];
    
    DDLogDebug(@"setupTSKitEnv ends.");
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
    
    // Refresh local data from CCSM
    if ([TSAccountManager isRegistered]) {
        if (Environment.preferences.requirePINAccess) {
            if ([SmileAuthenticator hasPassword] && SmileAuthenticator.sharedInstance.isAuthenticated) {
                [self removeScreenProtection];
            } else {
                if (!SmileAuthenticator.sharedInstance.isShowingAuthVC) {
                SmileAuthenticator.sharedInstance.securityType = INPUT_TOUCHID;
                [SmileAuthenticator.sharedInstance presentAuthViewControllerAnimated:YES];
                }
            }
        } else {
            [self removeScreenProtection];
        }

        [TSSocketManager becomeActiveFromForeground];
        [CCSMCommManager refreshSessionTokenAsynchronousSuccess:^{  // Refresh success
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0), ^{
                [Environment.getCurrent.contactsManager intersectLocalContacts];
                [self refreshUsersStore];
            });
        }
                                                        failure:^(NSError *error){
                                                            // Unable to refresh, login force login
                                                            DDLogDebug(@"Token Refresh failed with error: %@", error.description);
                                                            
                                                            // Determine if this eror should kick the user out:
                                                            if (error.code >= 400 && error.code <= 404) {
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
}


- (void)applicationWillResignActive:(UIApplication *)application {
    UIBackgroundTaskIdentifier __block bgTask = UIBackgroundTaskInvalid;
    bgTask                                    = [application beginBackgroundTaskWithExpirationHandler:^{
        
    }];
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        if ([TSAccountManager isRegistered]) {
            dispatch_async(dispatch_get_main_queue(), ^{
                if (application.keyWindow.rootViewController.presentedViewController) {
                    if (!SmileAuthenticator.sharedInstance.isShowingAuthVC) {
                        [application.keyWindow.rootViewController dismissViewControllerAnimated:NO completion:^{
                            [self protectScreen];
                        }];
                    }
                } else {
                    [self protectScreen];
                }
                [Environment.getCurrent.forstaViewController updateInboxCountLabel];
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
 * MARK: - Screen protection obscures the app screen shown in the app switcher.
 */

-(UIImageView *)coverImageView
{
    if (_coverImageView == nil) {
        _coverImageView = [[UIImageView alloc]initWithFrame:[self.window bounds]];
        _coverImageView.contentMode = UIViewContentModeScaleAspectFill;
        UIImage *image = [UIImage imageNamed:@"forsta_splash.png"];
        [_coverImageView setImage:image];
        _coverImageView.alpha = 1.0;
    }
    return _coverImageView;
}

- (void)protectScreen
{
//    dispatch_async(dispatch_get_main_queue(), ^{
        if (!self.coverImageView.superview) {
            [self.window.rootViewController.view addSubview:self.coverImageView];
        }
        self.coverImageView.alpha = 1.0;
//    });
}

- (void)removeScreenProtection
{
    if (self.coverImageView.superview) {
//        dispatch_async(dispatch_get_main_queue(), ^{
            self.coverImageView.alpha = 0.0;
            [self.coverImageView removeFromSuperview];
//        });
    }
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
        } else { // No local token, login
            storyboard = [UIStoryboard storyboardWithName:AppDelegateStoryboardLogin bundle:[NSBundle mainBundle]];
        }
        self.window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
        self.window.rootViewController = [storyboard instantiateInitialViewController];
        [self.window makeKeyAndVisible];
    }

    // Setup Authenticator
    SmileAuthenticator.sharedInstance.delegate = self;
    SmileAuthenticator.sharedInstance.passcodeDigit = Environment.preferences.PINLength;
    SmileAuthenticator.sharedInstance.tintColor = [ForstaColors blackColor];
    SmileAuthenticator.sharedInstance.rootVC = self.window.rootViewController;
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

-(void)refreshUsersStore
{
    [CCSMCommManager refreshCCSMData];
}

#pragma mark - Smile Authentication Delegate methods
-(void)userFailAuthenticationWithCount:(NSInteger)failCount
{
    if (failCount > FLMaxAuthFailures) {
        // TODO: Put a delay of failCount seconds in to make brute force less appealing
        [SmileAuthenticator.sharedInstance.rootVC dismissViewControllerAnimated:YES completion:^{
            [self protectScreen];
            
            __block NSString *formatString = [NSString stringWithFormat:@"%@\n\n%@", NSLocalizedString(@"FL_SMILE_TOOMANYFAILS_MESSAGE", nil), NSLocalizedString(@"FL_SMILE_FAIL_WAIT_MESSAGE", nil)];
            __block UIAlertController *failAlert = [UIAlertController alertControllerWithTitle:nil
                                                                                       message:[NSString stringWithFormat:formatString, FLAuthFailCooldown]
                                                                                preferredStyle:UIAlertControllerStyleAlert];
            __block UIAlertAction *tryAgain = [UIAlertAction actionWithTitle:@"Try Again"
                                                                       style:UIAlertActionStyleDefault
                                                                     handler:^(UIAlertAction * _Nonnull action) {
                                                                         SmileAuthenticator.sharedInstance.securityType = INPUT_TOUCHID;
                                                                         [SmileAuthenticator.sharedInstance presentAuthViewControllerAnimated:YES];
                                                                     }];
            tryAgain.enabled = NO;
//            [failAlert addAction:tryAgain];
            [self.window.rootViewController presentViewController:failAlert
                                                         animated:YES
                                                       completion:^{
                                                           dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                                                               for (NSInteger i = FLAuthFailCooldown; i >= 0 ; i--) {
                                                                   //Here your non-main thread.
                                                                   dispatch_async(dispatch_get_main_queue(), ^{
                                                                       //Here you return to main thread.
                                                                       failAlert.message = [NSString stringWithFormat:formatString, i];
                                                                   });
                                                                   [NSThread sleepForTimeInterval:1.0f];
                                                               }
                                                               dispatch_async(dispatch_get_main_queue(), ^{
                                                                   failAlert.message = NSLocalizedString(@"FL_SMILE_TOOMANYFAILS_MESSAGE", nil);
                                                                   [failAlert addAction:tryAgain];
                                                                   tryAgain.enabled = YES;
                                                               });
                                                           });
                                                       }];
        }];
    }
}

// TODO: return to the privacy settings VC after making changes to auth
-(void)userTurnPasswordOn
{
    [Environment.preferences setScreenSecurity:YES];
    Environment.preferences.requirePINAccess = YES;
}

-(void)userTurnPasswordOff
{
    Environment.preferences.requirePINAccess = NO;
}

//-(void)userChangePassword
//{
//
//}

-(void)userSuccessAuthentication
{
    [self removeScreenProtection];
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
        DDLogDebug(@"Fabric API key not found!");
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

