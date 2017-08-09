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

NSUInteger maximumValidationAttempts = 9999;

@interface LoginValidationViewController ()

@property (strong) CCSMStorage *ccsmStorage;
@property (strong) CCSMCommManager *ccsmCommManager;

@property (nonatomic, assign) BOOL keyboardShowing;

-(IBAction)mainViewTapped:(id)sender;


@end

@implementation LoginValidationViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.ccsmStorage = [CCSMStorage new];
    self.ccsmCommManager = [CCSMCommManager new];
    
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
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(keyboardWillShow:) name:UIKeyboardWillShowNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardWillHide:) name:UIKeyboardWillHideNotification object:nil];
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
        SignalsNavigationController *snc = (SignalsNavigationController *)segue.destinationViewController;
        
        AppDelegate *appDelegate = (AppDelegate *)[UIApplication sharedApplication].delegate;
        appDelegate.window.rootViewController = snc;
        if (![snc.topViewController isKindOfClass:[FLThreadViewController class]]) {
            DDLogError(@"%@ Unexpected top view controller: %@", self.tag, snc.topViewController);
            return;
        }
        DDLogDebug(@"%@ notifying signals view controller of new user.", self.tag);
        FLThreadViewController *forstaVC = (FLThreadViewController *)snc.topViewController;
        forstaVC.newlyRegisteredUser = YES;
    }
}

#pragma mark - move controls up to accomodate keyboard.
-(void)keyboardWillShow:(NSNotification *)notification
{
    if (!self.keyboardShowing) {
        self.keyboardShowing = YES;
        CGSize keyboardSize = [[[notification userInfo] objectForKey:UIKeyboardFrameBeginUserInfoKey] CGRectValue].size;
        CGSize screenSize = UIScreen.mainScreen.bounds.size;
        
        CGFloat controlsY = self.resendCodeButton.frame.origin.y + self.resendCodeButton.frame.size.height + 8.0;
        
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
        if ([self.validationCodeTextField isFirstResponder]) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [UIView animateWithDuration:0.25 animations:^{
                    self.view.frame = [UIScreen mainScreen].bounds ;
                    
                }];
            });
        }
    }
}


#pragma mark -
-(BOOL)attemptValidation
{
    return YES;
}

-(void)ccsmValidationSucceeded
{
    // refresh other stuff now that we have the user info...
    NSMutableDictionary * users= [[self.ccsmStorage getUsers] mutableCopy];
    if (!users) {
        users = [NSMutableDictionary new];
    }
    NSMutableDictionary *tags = [[self.ccsmStorage getTags] mutableCopy];
    if (!tags) {
        tags = [NSMutableDictionary new];
    }

    
    NSString *orgUrl = [[self.ccsmStorage getUserInfo] objectForKey:@"org"];
    [self.ccsmCommManager getThing:orgUrl
                           success:^(NSDictionary *org){
                               NSLog(@"Retrieved org info after login validation");
                               [self.ccsmStorage setOrgInfo:org];
                           }
                           failure:^(NSError *err){
                               NSLog(@"Failed to retrieve org info after login validation");
                           }];
    [self.ccsmCommManager updateAllTheThings:[NSString stringWithFormat:@"%@/v1/user/", FLHomeURL]
                                  collection:users
                                 synchronous:NO
                                     success:^{
                                         NSLog(@"Retrieved all users after login validation");
                                         [self.ccsmStorage setUsers:[NSDictionary dictionaryWithDictionary:users]];
                                     }
                                     failure:^(NSError *err){
                                         NSLog(@"Failed to retrieve all users after login validation");
                                     }];
    
    // TSS Registration handling
    // Check if registered and proceed to next storyboard accordingly
    if ([TSAccountManager isRegistered]) {
        // We are, move onto main
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.spinner stopAnimating];
            self.validationButton.enabled = YES;
            self.validationButton.alpha = 1.0;
            [self performSegueWithIdentifier:@"mainSegue" sender:self];
        });
    } else {
        // Not registered with TSS, ask CCSM to do it for us.
        [self.ccsmCommManager registerWithTSSViaCCSMForUserID:[[[Environment getCurrent].ccsmStorage getUserInfo] objectForKey:@"id"]
                                                      success:^{
                                                          [self.spinner stopAnimating];
                                                          self.validationButton.enabled = YES;
                                                          self.validationButton.alpha = 1.0;
                                                          [self performSegueWithIdentifier:@"mainSegue" sender:self];
                                                      }
                                                      failure:^(NSError *error) {
                                                          DDLogError(@"TSS Validation error: %@", error.description);
                                                          UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Error"
                                                                                                          message:error.description
                                                                                                         delegate:nil
                                                                                                cancelButtonTitle:@"OK"
                                                                                                otherButtonTitles:nil];
                                                          [alert show];
                                                          dispatch_async(dispatch_get_main_queue(), ^{
                                                              [self.spinner stopAnimating];
                                                              self.validationButton.enabled = YES;
                                                              self.validationButton.alpha = 1.0;
                                                          });
                                                      }];
    }
    
}

-(void)ccsmValidationFailed
{
    
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"Login Failed", @"")
                                                                   message:NSLocalizedString(@"Invalid credentials.  Please try again.", @"")
                                                            preferredStyle:UIAlertControllerStyleActionSheet];
    UIAlertAction *okButton = [UIAlertAction actionWithTitle:NSLocalizedString(@"OK", @"")
                                                       style:UIAlertActionStyleDefault
                                                     handler:^(UIAlertAction *action) {
                                                         dispatch_async(dispatch_get_main_queue(), ^{
                                                             [self.spinner stopAnimating];
                                                             self.validationButton.enabled = YES;
                                                             self.validationButton.alpha = 1.0;
                                                         });
                                                     }];
    [alert addAction:okButton];
    [self presentViewController:alert animated:YES completion:nil];
}

#pragma mark - Button actions
-(IBAction)onValidationButtonTap:(id)sender
{
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.spinner startAnimating];
        self.validationButton.enabled = NO;
        self.validationButton.alpha = 0.5;
    });

    
    NSString *code = self.validationCodeTextField.text;
    [self.ccsmCommManager verifyLogin:code
                              success:^{
                                  [self ccsmValidationSucceeded];
                              }
                              failure:^(NSError *err){
                                  [self ccsmValidationFailed];
                              }];
}

-(IBAction)onResendCodeButtonTap:(id)sender
{
//    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Be Patient." message:@"Function not yet implemented." delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
//    [alert show];

    [self.ccsmCommManager requestLogin:[self.ccsmStorage getUserName]
                               orgName:[self.ccsmStorage getOrgName]
                               success:^{
//                                   [self connectionSucceeded];
                               }
                               failure:^(NSError *err){
                                   
                               }];
}

-(IBAction)mainViewTapped:(id)sender
{
    if ([self.validationCodeTextField isFirstResponder]) {
        [self.validationCodeTextField resignFirstResponder];
    }
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
