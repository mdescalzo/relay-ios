//
//  LoginValidationViewController.h
//  Forsta
//
//  Created by Mark on 5/27/17.
//  Copyright © 2017 Forsta. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface LoginValidationViewController : UIViewController <UITextFieldDelegate, UIAlertViewDelegate>

//@property (weak, nonatomic) IBOutlet UILabel *validationLabel;
@property (weak, nonatomic) IBOutlet UITextField *validationCodeTextField;
@property (weak, nonatomic) IBOutlet UIButton *validationButton;
@property (weak, nonatomic) IBOutlet UIActivityIndicatorView *spinner;
@property (weak, nonatomic) IBOutlet UIButton *resendCodeButton;
@property (weak, nonatomic) IBOutlet UIButton *changeCredButton;

-(IBAction)onValidationButtonTap:(id)sender;

@end
