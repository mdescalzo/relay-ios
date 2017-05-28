//
//  LoginViewController.m
//  Forsta
//
//  Created by Mark on 5/27/17.
//  Copyright © 2017 Forsta. All rights reserved.
//

#import "LoginViewController.h"

@interface LoginViewController ()

@end

@implementation LoginViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    
    // Allow for localized strings on controls
//    self.organizationLabel.text = NSLocalizedString(@"Organization", @"");
//    self.usernameLabel.text = NSLocalizedString(@"Username", @"");
    self.organizationTextField.placeholder = NSLocalizedString(@"Enter Organization", @"");
    self.usernameTextField.placeholder = NSLocalizedString(@"Enter Username", @"");
    self.loginButton.titleLabel.text = NSLocalizedString(@"Login", @"");
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
    [self performSegueWithIdentifier:@"validationViewSegue" sender:nil];
}

@end
