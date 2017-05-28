//
//  LoginViewController.m
//  Forsta
//
//  Created by Mark on 5/27/17.
//  Copyright © 2017 Forsta. All rights reserved.
//

#import "LoginViewController.h"
#import "CCSMStorage.h"

@interface LoginViewController ()

@property (strong) CCSMStorage *ccsmStorage;

@end

@implementation LoginViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    
    
    
    
    self.ccsmStorage = [[CCSMStorage alloc] init];
    
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

-(IBAction)OnLoginButtonTap:(id)sender
{
    // Do stuff on Login button tap
    [self.spinner startAnimating];

    [self.ccsmStorage setOrgName:self.organizationTextField.text];
    [self.ccsmStorage setUserName:self.usernameTextField.text];
    [self performSegueWithIdentifier:@"validationViewSegue" sender:nil];
    [self.spinner stopAnimating];
}

-(BOOL)isValidOrganization:(NSString *)organization
{
    return YES;
}

-(BOOL)isValidUsername:(NSString *)username
{
    return YES;
}

#pragma mark - UITextField delegate methods
-(BOOL)textFieldShouldEndEditing:(UITextField *)textField
{
    if (textField == self.organizationTextField)
    {
        NSLog(@"OrgFieldEnding...");
        return [self isValidOrganization:textField.text];
    }
    else if (textField == self.usernameTextField)
    {
        NSLog(@"UserFiendEnding...");
        return [self isValidUsername:textField.text];
    }
    else
        return YES;
}

#pragma mark - Lazy instatiation

@end
