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

NSUInteger maximumValidationAttempts = 9999;

@interface LoginValidationViewController ()

@property (strong) CCSMStorage *ccsmStorage;
@property (strong) CCSMCommManager *ccsmCommManager;

@end

@implementation LoginValidationViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.ccsmStorage = [CCSMStorage new];
    self.ccsmCommManager = [CCSMCommManager new];
    
    // Do any additional setup after loading the view.
    
    // Allow for localized string on controls
//    self.validationLabel.text = NSLocalizedString(@"Enter Validation Code", @"");
    self.validationCodeTextField.placeholder = NSLocalizedString(@"Enter Validation Code", @"");
    self.validationButton.titleLabel.text = NSLocalizedString(@"Validate", @"");
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/

#pragma mark -
-(BOOL)attemptValidation
{
    return YES;
}

-(void)validationSucceeded
{
    // refresh other stuff now that we have the user info...
    NSMutableDictionary * users = [self.ccsmStorage getUsers];
    if (!users) {
        users = [NSMutableDictionary new];
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
    [self.ccsmCommManager updateAllTheThings:@"https://ccsm-dev-api.forsta.io/v1/user/"
                                  collection:users
                                     success:^{
                                         NSLog(@"Retrieved all users after login validation");
                                         [self.ccsmStorage setUsers:users];
                                     }
                                     failure:^(NSError *err){
                                         NSLog(@"Failed to retrieve all users after login validation");
                                     }];
    
    // Check if registered and proceed to next storyboard accordingly
    NSString *targetSegue = nil;
    if ([TSAccountManager isRegistered])
        targetSegue = @"mainSegue";
    else
        targetSegue = @"registrationSegue";
    
    // Move on to the Registration storyboard
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.spinner startAnimating];
        self.validationButton.enabled = NO;
        self.validationButton.alpha = 0.5;
        [self performSegueWithIdentifier:targetSegue sender:self];
    });
}

-(void)validationFailed
{
    [[[UIAlertView alloc] initWithTitle:NSLocalizedString(@"Login Failed", @"")
                                message:NSLocalizedString(@"Invalid credentials.  Please try again.", @"")
                               delegate:self
                      cancelButtonTitle:NSLocalizedString(@"Try again", @"")
                      otherButtonTitles:NSLocalizedString(@"Send new code", @""), nil]
     show];
}

#pragma mark - Button actions
-(IBAction)onValidationButtonTap:(id)sender
{
    NSString *code = self.validationCodeTextField.text;
    [self.ccsmCommManager verifyLogin:code
                              success:^{
                                  [self validationSucceeded];
                              }
                              failure:^(NSError *err){
                                  [self validationFailed];
                              }];
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



@end
