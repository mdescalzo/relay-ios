//
//  LoginValidationViewController.m
//  Forsta
//
//  Created by Mark on 5/27/17.
//  Copyright © 2017 Forsta. All rights reserved.
//

#import "LoginValidationViewController.h"
#import "TSAccountManager.h"
#import "CCSMCommunication.h"
#import "CCSMStorage.h"
#import "Environment.h"
#import "SignalsNavigationController.h"
#import "AppDelegate.h"
#import "FLDeviceRegistrationService.h"

NSUInteger maximumValidationAttempts = 9999;

@interface LoginValidationViewController ()

@property (strong) CCSMStorage *ccsmStorage;
//@property (strong) CCSMCommManager *ccsmCommManager;
@property (weak, nonatomic) IBOutlet UILabel *infoLabel;

@property (nonatomic, assign) BOOL keyboardShowing;

-(IBAction)mainViewTapped:(id)sender;


@end

@implementation LoginValidationViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.ccsmStorage = [CCSMStorage new];
    //    self.ccsmCommManager = [CCSMCommManager new];
    
    // Allow for localized string on controls
    self.validationCodeTextField.placeholder = NSLocalizedString(@"Enter Validation Code", @"");
    self.validationButton.titleLabel.text = NSLocalizedString(@"Validate", @"");
    self.resendCodeButton.titleLabel.text = NSLocalizedString(@"Send New Code", @"");
    self.changeCredButton.titleLabel.text = NSLocalizedString(@"        Change Credentials", @"");
    
    // Setup tap recognizer for keyboard dismissal
    UITapGestureRecognizer *tgr = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(mainViewTapped:)];
    [self.view addGestureRecognizer:tgr];
    
}

-(void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    self.navigationController.navigationBar.hidden = NO;
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(keyboardWillShow:)
                                                 name:UIKeyboardWillShowNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardWillHide:) name:UIKeyboardWillHideNotification object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(updateInfoLabel:)
                                                 name:FLRegistrationStatusUpdateNotification
                                               object:nil];
    // Ensure infoLabel is empty.
    self.infoLabel.text = @"";
}

-(void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    [self.validationCodeTextField becomeFirstResponder];
}

-(void)viewDidDisappear:(BOOL)animated
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    
    [super viewDidDisappear:animated];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
    if ([segue.identifier isEqualToString: @"mainSegue"]) {
        [[NSUserDefaults standardUserDefaults] setBool:NO forKey:FLAwaitingVerification];
        [[NSUserDefaults standardUserDefaults] synchronize];
        
        SignalsNavigationController *snc = (SignalsNavigationController *)segue.destinationViewController;
        
        AppDelegate *appDelegate = (AppDelegate *)[UIApplication sharedApplication].delegate;
        appDelegate.window.rootViewController = snc;
        
        [appDelegate applicationDidBecomeActive:[UIApplication sharedApplication]];
        
        if (![snc.topViewController isKindOfClass:[FLThreadViewController class]]) {
            DDLogError(@"%@ Unexpected top view controller: %@", self.tag, snc.topViewController);
            return;
        }
        DDLogDebug(@"%@ notifying signals view controller of new user.", self.tag);
        FLThreadViewController *forstaVC = (FLThreadViewController *)snc.topViewController;
        forstaVC.newlyRegisteredUser = YES;
    }
}


// MARK: - Notification handling

-(void)updateInfoLabel:(NSNotification *)notification
{
    NSString *messageString = [(NSDictionary *)notification.object objectForKey:@"message"];
    
    if (messageString.length == 0) {
        DDLogWarn(@"Empty registration status notification received.  Ignoring");
        return;
    } else {
        dispatch_async(dispatch_get_main_queue(), ^{
            self.infoLabel.text = messageString;
        });
    }
}

-(void)keyboardWillShow:(NSNotification *)notification
{
    if (!self.keyboardShowing) {
        self.keyboardShowing = YES;
        CGSize keyboardSize = [[[notification userInfo] objectForKey:UIKeyboardFrameEndUserInfoKey] CGRectValue].size;
        CGSize screenSize = UIScreen.mainScreen.bounds.size;
        
        CGFloat controlsY = self.resendCodeButton.frame.origin.y + self.resendCodeButton.frame.size.height + 8.0f;
        
        if ((screenSize.height - controlsY) < keyboardSize.height) {  // Keyboard will overlap
            
            CGFloat offset =  keyboardSize.height - (screenSize.height - controlsY);
            
            CGRect newFrame = CGRectMake(self.view.frame.origin.x,
                                         self.view.frame.origin.y - offset,
                                         self.view.frame.size.width,
                                         self.view.frame.size.height);
            
            
            dispatch_async(dispatch_get_main_queue(), ^{
                [UIView animateWithDuration:0.25 animations:^{
                    self.view.frame = newFrame;
                    
                }];
            });
        }
    }
}

-(void)keyboardWillHide:(NSNotification *)notification
{
    if (self.keyboardShowing) {
        self.keyboardShowing = NO;
        
        CGFloat offset = [UIApplication sharedApplication].statusBarFrame.size.height + self.navigationController.navigationBar.frame.size.height;
        CGRect screenFrame = UIScreen.mainScreen.bounds;
        CGRect newFrame = CGRectMake(screenFrame.origin.x,
                                     screenFrame.origin.y + offset,
                                     screenFrame.size.width,
                                     screenFrame.size.height);
        
        dispatch_async(dispatch_get_main_queue(), ^{
            [UIView animateWithDuration:0.25 animations:^{
                self.view.frame = newFrame;
                //                    self.view.frame = [UIScreen mainScreen].bounds ;
                
            }];
        });
    }
}


#pragma mark - Workers
-(BOOL)attemptValidation
{
    return YES;
}

-(void)ccsmValidationSucceeded
{
    // TSS Registration handling
    // Check if registered and proceed to next storyboard accordingly
    if ([TSAccountManager isRegistered]) {
        // We are, move onto main
        
        [TSSocketManager becomeActiveFromForeground];
        [CCSMCommManager refreshCCSMData];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            self.infoLabel.text = @"This device is already registered.";
            [self.spinner stopAnimating];
            self.validationButton.enabled = YES;
            self.validationButton.alpha = 1.0;
            [self performSegueWithIdentifier:@"mainSegue" sender:self];
        });
    } else {
        [FLDeviceRegistrationService.sharedInstance registerWithTSSWithCompletion:^(NSError * _Nullable error) {
            if (error == nil) {
                [CCSMCommManager refreshCCSMData];
                [TSSocketManager becomeActiveFromForeground];
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self.spinner stopAnimating];
                    self.validationButton.enabled = YES;
                    self.validationButton.alpha = 1.0;
                    [self performSegueWithIdentifier:@"mainSegue" sender:self];
                });
                
            } else {
                if (error.domain == NSCocoaErrorDomain && error.code == NSUserActivityRemoteApplicationTimedOutError) {
                    // Device provision timed out.
                    DDLogInfo(@"Device Autoprovisioning timed out.");
                    dispatch_async(dispatch_get_main_queue(), ^{
                        NSString *messageString = [NSString stringWithFormat:@"%@\n\nPlease make sure one of your other registered devices or web client sessions is active and try again.", error.localizedDescription];
                        UIAlertController *alertController =
                        [UIAlertController alertControllerWithTitle:NSLocalizedString(@"REGISTRATION_ERROR", nil)
                                                            message:messageString
                                                     preferredStyle:UIAlertControllerStyleAlert];
                        [alertController addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"OK", nil)
                                                                            style:UIAlertActionStyleDefault
                                                                          handler:^(UIAlertAction * _Nonnull action) {
                                                                              // Do nothin'
                                                                          }]];
                        [self.navigationController presentViewController:alertController animated:YES completion:^{
                            self.infoLabel.text = @"";
                            [self.spinner stopAnimating];
                            self.validationButton.enabled = YES;
                            self.validationButton.alpha = 1.0;
                        }];
                    });
                } else {
                    
                    DDLogError(@"TSS Validation error: %@", error.description);
                    dispatch_async(dispatch_get_main_queue(), ^{
                        // TODO: More user-friendly alert here
                        UIAlertController *alertController =
                        [UIAlertController alertControllerWithTitle:NSLocalizedString(@"REGISTRATION_ERROR", nil)
                                                            message:NSLocalizedString(@"REGISTRATION_CONNECTION_FAILED", nil)
                                                     preferredStyle:UIAlertControllerStyleAlert];
                        [alertController addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"OK", nil)
                                                                            style:UIAlertActionStyleDefault
                                                                          handler:^(UIAlertAction * _Nonnull action) {
                                                                              // Do nothin'
                                                                          }]];
                        [self.navigationController presentViewController:alertController animated:YES completion:^{
                            self.infoLabel.text = @"";
                            [self.spinner stopAnimating];
                            self.validationButton.enabled = YES;
                            self.validationButton.alpha = 1.0;
                        }];
                    });
                }
            }
        }];
    }
    
}

-(void)ccsmValidationFailed
{
    dispatch_async(dispatch_get_main_queue(), ^{
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"Login Failed", @"")
                                                                       message:NSLocalizedString(@"Invalid credentials.  Please try again.", @"")
                                                                preferredStyle:UIAlertControllerStyleActionSheet];
        [alert addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"OK", @"")
                                                           style:UIAlertActionStyleDefault
                                                         handler:^(UIAlertAction *action) {
                                                             dispatch_async(dispatch_get_main_queue(), ^{
                                                                 self.infoLabel.text = @"";
                                                                 [self.spinner stopAnimating];
                                                                 self.validationButton.enabled = YES;
                                                                 self.validationButton.alpha = 1.0;
                                                             });
                                                         }]];
        [self presentViewController:alert animated:YES completion:nil];
    });
}

#pragma mark - Button actions
-(IBAction)onValidationButtonTap:(id)sender
{
    dispatch_async(dispatch_get_main_queue(), ^{
        self.infoLabel.text = NSLocalizedString(@"Validating code", @"Status message when starting code validation");
        [self.spinner startAnimating];
        self.validationButton.enabled = NO;
        self.validationButton.alpha = 0.5;
    });
    
    
    NSString *code = self.validationCodeTextField.text;
    [CCSMCommManager verifyLogin:code
                         success:^{
                             [self ccsmValidationSucceeded];
                         }
                         failure:^(NSError *err){
                             [self ccsmValidationFailed];
                         }];
}

-(IBAction)onResendCodeButtonTap:(id)sender
{
    [CCSMCommManager requestLogin:[self.ccsmStorage getUserName]
                          orgName:[self.ccsmStorage getOrgName]
                          success:^{
                              DDLogDebug(@"Request for code resend succeeded.");
                          }
                          failure:^(NSError *err){
                              DDLogDebug(@"Request for code resend failed.  Error: %@", err.description);
                          }];
}

-(IBAction)mainViewTapped:(id)sender
{
    if ([self.validationCodeTextField isFirstResponder]) {
        [self.validationCodeTextField resignFirstResponder];
    }
}

- (IBAction)onChangeCredsTapped:(id)sender
{
    [self.navigationController popViewControllerAnimated:YES];
}

#pragma mark - UIAlertView delegate methods
-(void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex
{
    if (buttonIndex == 1) {
        // Initiate resend of validation code here
    }
}

#pragma mark - UITextField delegate methods
-(BOOL)textField:(UITextField *)textField shouldChangeCharactersInRange:(NSRange)range replacementString:(NSString *)string
{
    return YES;
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

@end
