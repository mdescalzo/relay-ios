//
//  CreateAccountViewController.m
//  Forsta
//
//  Created by Mark on 10/4/17.
//  Copyright © 2017 Forsta. All rights reserved.
//

#import "CreateAccountViewController.h"
#import "CCSMCommunication.h"

@interface CreateAccountViewController () <UITextFieldDelegate>

@property (weak, nonatomic) IBOutlet UITextField *firstNameTextField;
@property (weak, nonatomic) IBOutlet UITextField *lastNameTextField;
@property (weak, nonatomic) IBOutlet UITextField *phoneNumberTextField;
@property (weak, nonatomic) IBOutlet UITextField *emailTextField;
@property (weak, nonatomic) IBOutlet UIButton *submitButton;
@property (weak, nonatomic) IBOutlet UIActivityIndicatorView *spinner;

@property (nonatomic, strong) NSString *simplePhoneNumber;
@property (nonatomic, strong) NSArray<UITextField *> *inputFields;

@property (nonatomic, assign) BOOL keyboardShowing;

@end

@implementation CreateAccountViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    self.firstNameTextField.placeholder = NSLocalizedString(@"Enter First Name", @"Enter First Name");
    self.lastNameTextField.placeholder = NSLocalizedString(@"Enter Last Name", @"Enter Last Name");
    self.phoneNumberTextField.placeholder = NSLocalizedString(@"Enter Phone Number", @"Enter Phone Number");
    self.emailTextField.placeholder = NSLocalizedString(@"Enter Email Address", @"Enter Phone Number");
    [self.submitButton setTitle:NSLocalizedString(@"Submit", @"Submit") forState:UIControlStateNormal];
    
    // Setup tap recognizer for keyboard dismissal
    UITapGestureRecognizer *tgr = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(mainViewTapped:)];
    [self.view addGestureRecognizer:tgr];
}

-(void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(keyboardWillShow:) name:UIKeyboardWillShowNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardWillHide:) name:UIKeyboardWillHideNotification object:nil];
}

-(void)viewDidAppear:(BOOL)animated
{
    [self.firstNameTextField resignFirstResponder];
    [self.lastNameTextField resignFirstResponder];
    [self.phoneNumberTextField resignFirstResponder];
    [self.emailTextField resignFirstResponder];
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


#pragma mark - move controls up to accomodate keyboard.
-(void)keyboardWillShow:(NSNotification *)notification
{
    if (!self.keyboardShowing) {
        self.keyboardShowing = YES;
        CGSize keyboardSize = [[[notification userInfo] objectForKey:UIKeyboardFrameEndUserInfoKey] CGRectValue].size;
        CGSize screenSize = UIScreen.mainScreen.bounds.size;
        
        CGFloat controlsY = self.submitButton.frame.origin.y + self.submitButton.frame.size.height + 8.0;
        
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
        if (([self.firstNameTextField isFirstResponder] ||
             [self.lastNameTextField isFirstResponder] ||
             [self.phoneNumberTextField isFirstResponder] ||
             [self.emailTextField isFirstResponder])) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [UIView animateWithDuration:0.25 animations:^{
                    self.view.frame = [UIScreen mainScreen].bounds ;
                }];
            });
        }
    }
}

#pragma mark - UITextField delegate methods
-(BOOL)textField:(UITextField *)textField shouldChangeCharactersInRange:(NSRange)range replacementString:(NSString *)string
{
    NSString* totalString = [NSString stringWithFormat:@"%@%@",textField.text,string];
    
    if (textField == self.phoneNumberTextField) {
        if (range.length == 1) {
            // Delete button was hit.. so tell the method to delete the last char.
            textField.text = [self formatPhoneNumber:totalString deleteLastChar:YES];
        } else {
            textField.text = [self formatPhoneNumber:totalString deleteLastChar:NO ];
        }
        return NO;
    }
    return YES;
}

-(BOOL)textFieldShouldReturn:(UITextField *)textField
{
    NSUInteger currentIndex = [self.inputFields indexOfObject:textField];
    NSUInteger nextIndex = (self.inputFields.count > currentIndex+1 ? currentIndex+1 : 0);
//    [textField resignFirstResponder];
    [[self.inputFields objectAtIndex:nextIndex] becomeFirstResponder];
    
    return YES;
}

#pragma mark - Worker methods
-(void)stopSpinner
{
    [self.spinner stopAnimating];
    self.submitButton.enabled = YES;
    self.submitButton.alpha = 1.0;
}

-(void)startSpinner
{
    [self.spinner startAnimating];
    self.submitButton.enabled = NO;
    self.submitButton.alpha = 0.5;

}

-(void)presentAlertWithMessage:(NSString *)message
{
    dispatch_async(dispatch_get_main_queue(), ^{
        UIAlertController *alertView = [UIAlertController alertControllerWithTitle:nil
                                                                           message:message
                                                                    preferredStyle:UIAlertControllerStyleActionSheet];
        UIAlertAction *okButton = [UIAlertAction actionWithTitle:NSLocalizedString(@"OK", nil)
                                                           style:UIAlertActionStyleDefault
                                                         handler:^(UIAlertAction *action) { /* do nothing */} ];
        [alertView addAction:okButton];
        [self presentViewController:alertView animated:YES completion:nil];
    });
}

// Swiped from: https://stackoverflow.com/questions/5428304/email-validation-on-textfield-in-iphone-sdk
- (BOOL)validateEmail:(NSString*)emailAddress
{
    NSString *emailRegex = @"[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,4}";
    NSPredicate *emailTest = [NSPredicate predicateWithFormat:@"SELF MATCHES %@", emailRegex];
    return [emailTest evaluateWithObject:emailAddress];
}

// Swiped from: https://stackoverflow.com/questions/1246439/uitextfield-for-phone-number
-(NSString*)formatPhoneNumber:(NSString*)simpleNumber deleteLastChar:(BOOL)deleteLastChar
{
    if(simpleNumber.length==0) return @"";
    // use regex to remove non-digits(including spaces) so we are left with just the numbers
    NSError *error = NULL;
    NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:@"[\\s-\\(\\)]" options:NSRegularExpressionCaseInsensitive error:&error];
    simpleNumber = [regex stringByReplacingMatchesInString:simpleNumber options:0 range:NSMakeRange(0, [simpleNumber length]) withTemplate:@""];
    
    // check if the number is to long
    if(simpleNumber.length>10) {
        // remove last extra chars.
        simpleNumber = [simpleNumber substringToIndex:10];
    }
    
    if(deleteLastChar) {
        // should we delete the last digit?
        simpleNumber = [simpleNumber substringToIndex:[simpleNumber length] - 1];
    }
    
    // Store the number for use elsewhere
    self.simplePhoneNumber = [simpleNumber copy];
    
    // 123 456 7890
    // format the number.. if it's less then 7 digits.. then use this regex.
    if(simpleNumber.length<7)
        simpleNumber = [simpleNumber stringByReplacingOccurrencesOfString:@"(\\d{3})(\\d+)"
                                                               withString:@"($1) $2"
                                                                  options:NSRegularExpressionSearch
                                                                    range:NSMakeRange(0, [simpleNumber length])];
    
    else   // else do this one..
        simpleNumber = [simpleNumber stringByReplacingOccurrencesOfString:@"(\\d{3})(\\d{3})(\\d+)"
                                                               withString:@"($1) $2-$3"
                                                                  options:NSRegularExpressionSearch
                                                                    range:NSMakeRange(0, [simpleNumber length])];
    return simpleNumber;
}

#pragma mark - Actions
- (IBAction)didPressSubmit:(id)sender
{
    dispatch_async(dispatch_get_main_queue(), ^{
        [self startSpinner];
        
        if (self.firstNameTextField.text.length == 0) {
            [self presentAlertWithMessage:@"Please enter your first name."];
            [self stopSpinner];
        } else if (self.lastNameTextField.text.length == 0) {
            [self presentAlertWithMessage:@"Please enter your last name."];
            [self stopSpinner];
        } else if (self.phoneNumberTextField.text.length < 14) {
            [self presentAlertWithMessage:@"Please enter your phone number."];
            [self stopSpinner];
        } else if (![self validateEmail:self.emailTextField.text]) {
            [self presentAlertWithMessage:@"Please enter a valid email address."];
            [self stopSpinner];
        } else {
            //  Good inputs, GO!
            NSDictionary *payload = @{ @"first_name" : self.firstNameTextField.text,
                                       @"last_name" : self.lastNameTextField.text,
                                       @"phone" : [NSString stringWithFormat:@"+1%@",  self.simplePhoneNumber],
                                       @"email" : self.emailTextField.text
                                       };
            [[CCSMCommManager new] requestAccountCreationWithUserDict:payload
                                                              success:^{
                                                                  [self stopSpinner];
                                                                  [self performSegueWithIdentifier:@"validationViewSegue" sender:self];
                                                              }
                                                              failure:^(NSError *error) {
                                                                  [self stopSpinner];
                                                              }];
        }
    });
}

// Dismiss keyboard
-(IBAction)mainViewTapped:(id)sender
{
    [self.firstNameTextField resignFirstResponder];
    [self.lastNameTextField resignFirstResponder];
    [self.phoneNumberTextField resignFirstResponder];
    [self.emailTextField resignFirstResponder];
}

#pragma mark - Accessors
-(NSArray <UITextField *>*)inputFields
{
    if (_inputFields == nil) {
        _inputFields = @[ self.firstNameTextField, self.lastNameTextField, self.emailTextField, self.phoneNumberTextField ];
    }
    return  _inputFields;
}

@end
