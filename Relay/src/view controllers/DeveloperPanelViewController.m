//
//  DeveloperPanelViewController.m
//  Forsta
//
//  Created by Mark on 6/19/17.
//  Copyright © 2017 Forsta. All rights reserved.
//

#import "DeveloperPanelViewController.h"
#import "CCSMStorage.h"
#import "TSAccountManager.h"

@import Crashlytics;

@interface DeveloperPanelViewController ()

@property (nonatomic, weak) IBOutlet UILabel *forstaURLLabel;
@property (nonatomic, weak) IBOutlet UITextField *inputField;
@property (nonatomic, weak) IBOutlet UILabel *outputLabel;
@property (weak, nonatomic) IBOutlet UIButton *crashButton;

@end

@implementation DeveloperPanelViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    
    self.outputLabel.text = [NSString stringWithFormat:@"UserID: %@", TSAccountManager.sharedInstance.myself.uniqueId];
    
    self.forstaURLLabel.text = FLHomeURL;
    
    [self updateView];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

-(void)updateView
{
}

/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/

-(BOOL)textField:(UITextField *)textField shouldChangeCharactersInRange:(NSRange)range replacementString:(NSString *)string
{
    if (textField.text.length >= 3) {
        [CCSMCommManager asyncTagLookupWithString:textField.text
                                     success:^(NSDictionary *results) {
                                         dispatch_async(dispatch_get_main_queue(), ^{
                                             self.outputLabel.text = [NSString stringWithFormat:@"Successful lookup:\n %@", results.description];
                                         });
                                     }
                                     failure:^(NSError *error) {
                                         dispatch_async(dispatch_get_main_queue(), ^{
                                             self.outputLabel.text = [NSString stringWithFormat:@"Failed lookup.  Error code:%ld\n %@", (long)error.code, error.localizedDescription];
                                         });
                                     }];
    }
    
    return YES;
}

-(IBAction)crashTheThings:(id)sender
{
    [[Crashlytics sharedInstance] crash];
}

@end
