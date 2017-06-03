//
//  LoginViewController.m
//  Forsta
//
//  Created by Mark on 5/27/17.
//  Copyright © 2017 Forsta. All rights reserved.
//

#import "LoginViewController.h"
#import "CCSMCommunication.h"
#import "CCSMStorage.h"

@interface LoginViewController ()

@property (strong) CCSMStorage *ccsmStorage;
@property (strong) CCSMCommManager *ccsmCommManager;

@end

@implementation LoginViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    self.ccsmStorage = [CCSMStorage new];
    self.ccsmCommManager = [CCSMCommManager new];
    
    // Allow for localized strings on controls
    self.organizationTextField.placeholder = NSLocalizedString(@"Enter Organization", @"");
    self.usernameTextField.placeholder = NSLocalizedString(@"Enter Username", @"");
    self.loginButton.titleLabel.text = NSLocalizedString(@"Login", @"");
}

-(void)viewDidDisappear:(BOOL)animated
{
    [self.spinner stopAnimating];
    
    [super viewDidDisappear:animated];
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

-(IBAction)onLoginButtonTap:(id)sender
{
    if ([self isValidUsername:self.usernameTextField.text] &&
        [self isValidOrganization:self.organizationTextField.text]) // check for valid entries
    {
        
        [self.ccsmStorage setOrgName:self.organizationTextField.text];
        [self.ccsmStorage setUserName:self.usernameTextField.text];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.spinner startAnimating];
            self.loginButton.enabled = NO;
            self.loginButton.alpha = 0.5;
        });
        
        [self.ccsmCommManager requestLogin:[self.ccsmStorage getUserName]
                                   orgName:[self.ccsmStorage getOrgName]
                                   success:^{
                                       [self connectionSucceeded];
                                   }
                                   failure:^(NSError *err){
                                       [self connectionFailed:err];
                                   }];
    }
    else  // Bad organization or username
    {
        [[[UIAlertView alloc] initWithTitle:NSLocalizedString(@"Error", @"")
                                    message:NSLocalizedString(@"Please enter a valid organization/username.", @"")
                                   delegate:nil
                          cancelButtonTitle:NSLocalizedString(@"OK", @"")
                          otherButtonTitles:nil]
         show];
    }
    // Do stuff on Login button tap

    dispatch_async(dispatch_get_main_queue(), ^{
        [self.spinner startAnimating];
        self.loginButton.enabled = NO;
        self.loginButton.alpha = 0.5;
    });
    
    [self.ccsmCommManager requestLogin:self.usernameTextField.text
                               orgName:self.organizationTextField.text
                               success:^{
                                   [self connectionSucceeded];
                               }
                               failure:^(NSError *err){
                                   [self connectionFailed:err];
                               }];
}

#pragma mark -

-(BOOL)isValidOrganization:(NSString *)organization
{
    // Make sure not empty
    return !([organization isEqualToString:@""] || organization == nil);
}

-(BOOL)isValidUsername:(NSString *)username
{
    // Make sure not empty
    return !([username isEqualToString:@""] || username == nil);
}

#pragma mark - Login handlers
//
//-(BOOL)attemptLogin
//{
//    return YES;
//}

-(void)connectionSucceeded
{
    dispatch_async(dispatch_get_main_queue(), ^{
        self.loginButton.enabled = YES;
        self.loginButton.alpha = 1.0;
        [self.spinner stopAnimating];
        [self performSegueWithIdentifier:@"validationViewSegue" sender:nil];
    });
}

-(void)connectionFailed:(NSError *)error
{
    dispatch_async(dispatch_get_main_queue(), ^{
        self.loginButton.enabled = YES;
        self.loginButton.alpha = 1.0;
        [self.spinner stopAnimating];
        
        [[[UIAlertView alloc] initWithTitle:NSLocalizedString(@"Login Failed", @"")
                                    message:[NSString stringWithFormat:@"Error: %ld\n%@", error.code, error.localizedDescription]
                                   delegate:nil
                          cancelButtonTitle:NSLocalizedString(@"OK", @"")
                          otherButtonTitles:nil]
         show];
    });
}

#pragma mark - UITextField delegate methods
//-(BOOL)textFieldShouldEndEditing:(UITextField *)textField
//{
//    if (textField == self.organizationTextField)
//    {
//        return [self isValidOrganization:textField.text];
//    }
//    else if (textField == self.usernameTextField)
//    {
//        return [self isValidUsername:textField.text];
//    }
//    else
//        return YES;
//}

#pragma mark - Unwinding
- (IBAction)unwindToChangeCredientials:(UIStoryboardSegue *)sender {
}

@end
