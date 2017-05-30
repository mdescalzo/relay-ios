//
//  LoginValidationViewController.m
//  Forsta
//
//  Created by Mark on 5/27/17.
//  Copyright © 2017 Forsta. All rights reserved.
//

#import "LoginValidationViewController.h"

NSUInteger maximumValidationAttempts = 9999;

@interface LoginValidationViewController ()

@end

@implementation LoginValidationViewController

- (void)viewDidLoad {
    [super viewDidLoad];
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

-(IBAction)onValidationButtonTap:(id)sender
{
    // Do stuff when Validation button tapped
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.spinner startAnimating];
        self.validationButton.enabled = NO;
        self.validationButton.alpha = 0.5;
        [self performSegueWithIdentifier:@"registrationSegue" sender:self];
    });
}



@end
