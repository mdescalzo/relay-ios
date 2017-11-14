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


@interface LoginViewController () <UINavigationControllerDelegate>

@property (strong) CCSMStorage *ccsmStorage;
@property (nonatomic, assign) BOOL keyboardShowing;

-(IBAction)mainViewTapped:(id)sender;

@end

@implementation LoginViewController


- (void)viewDidLoad {
    [super viewDidLoad];
    // Setup nav controller
    self.navigationController.navigationBar.barTintColor = [UIColor whiteColor];
    self.navigationController.navigationBar.tintColor = [UIColor blackColor];
//    [self.navigationController.navigationBar setBackgroundImage:[UIImage new] forBarMetrics:UIBarMetricsDefault];
    self.navigationController.navigationBar.shadowImage = [UIImage new];
    self.navigationController.navigationBar.translucent = NO;

    // Allow for localized strings on controls
    self.organizationTextField.placeholder = NSLocalizedString(@"Enter Organization", @"Enter Username");
    self.usernameTextField.placeholder = NSLocalizedString(@"Enter Username", @"Enter Username");
    [self.loginButton setTitle:NSLocalizedString(@"Login", @"") forState:UIControlStateNormal];
    [self.createDomainButton setTitle:NSLocalizedString(@"Create Account", @"Create Account") forState:UIControlStateNormal];
    
    // Setup tap recognizer for keyboard dismissal
    UITapGestureRecognizer *tgr = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(mainViewTapped:)];
    [self.view addGestureRecognizer:tgr];
}

-(void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    self.navigationController.navigationBar.hidden = YES;
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(keyboardWillShow:) name:UIKeyboardWillShowNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardWillHide:) name:UIKeyboardWillHideNotification object:nil];
}

-(void)viewDidAppear:(BOOL)animated
{
    [self.usernameTextField resignFirstResponder];
    [self.organizationTextField resignFirstResponder]; 
}

-(void)viewWillDisappear:(BOOL)animated
{
    [self.usernameTextField resignFirstResponder];
    [self.organizationTextField resignFirstResponder];
    [self.spinner stopAnimating];
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [super viewWillDisappear:animated];
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

#pragma mark - Tap actions

-(IBAction)onLoginButtonTap:(id)sender
{
    if ([self isValidUsername:self.usernameTextField.text] &&
        [self isValidOrganization:self.organizationTextField.text]) // check for valid entries
    {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.spinner startAnimating];
            self.loginButton.enabled = NO;
            self.loginButton.alpha = 0.5;
        });
        
        [CCSMCommManager requestLogin:self.usernameTextField.text
                              orgName:self.organizationTextField.text
                              success:^{
                                  [self connectionSucceeded];
                              }
                              failure:^(NSError *err) {
                                  [self connectionFailed:err];
                              }];
    }
    else  // Bad organization or username
    {
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"Error", @"")
                                             message:NSLocalizedString(@"Please enter a valid organization/username.", @"")
                                      preferredStyle:UIAlertControllerStyleActionSheet];
        UIAlertAction *okButton = [UIAlertAction actionWithTitle:NSLocalizedString(@"OK", @"")
                                 style:UIAlertActionStyleDefault
                               handler:^(UIAlertAction * action) {} ];
        [alert addAction:okButton];
        [self presentViewController:alert animated:YES completion:nil];
        
    }
}

// Dismiss keyboard
-(IBAction)mainViewTapped:(id)sender
{
    if ([self.usernameTextField isFirstResponder]) {
        [self.usernameTextField resignFirstResponder];
    }
    if ([self.organizationTextField isFirstResponder]) {
        [self.organizationTextField resignFirstResponder];
    }
}

// Hop out to the domain creation page
//-(IBAction)onCreateDomainTap:(id)sender
//{
//    [[UIApplication sharedApplication] openURL:[NSURL URLWithString:FLDomainCreateURL]];
//}


#pragma mark - move controls up to accomodate keyboard.
-(void)keyboardWillShow:(NSNotification *)notification
{
    if (!self.keyboardShowing) {
        self.keyboardShowing = YES;
        CGSize keyboardSize = [[[notification userInfo] objectForKey:UIKeyboardFrameEndUserInfoKey] CGRectValue].size;
        CGSize screenSize = UIScreen.mainScreen.bounds.size;
        
        CGFloat controlsY = self.loginButton.frame.origin.y + self.loginButton.frame.size.height + 8.0;
        
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

-(void)keyboardWillHide:(nullable NSNotification *)notification
{
    if (self.keyboardShowing) {
        self.keyboardShowing = NO;
//        if (([self.organizationTextField isFirstResponder] || [self.usernameTextField isFirstResponder])) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [UIView animateWithDuration:0.25 animations:^{
                    self.view.frame = [UIScreen mainScreen].bounds ;
                }];
            });
//        }
    }
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
        [[NSUserDefaults standardUserDefaults] setBool:YES forKey:FLAwaitingVerification];
        [[NSUserDefaults standardUserDefaults] synchronize];
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
        
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"Login Failed", @"")
                                                                       message:[NSString stringWithFormat:@"%@", error.localizedDescription]
                                                                preferredStyle:UIAlertControllerStyleActionSheet];
        UIAlertAction *okButton = [UIAlertAction actionWithTitle:NSLocalizedString(@"OK", @"")
                                                           style:UIAlertActionStyleDefault
                                                         handler:^(UIAlertAction * action) {} ];
        [alert addAction:okButton];
        [self presentViewController:alert animated:YES completion:nil];
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
