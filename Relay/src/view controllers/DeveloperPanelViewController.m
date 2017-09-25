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

@interface DeveloperPanelViewController ()

@property (nonatomic, weak) IBOutlet UILabel *supermanIDLabel;
@property (nonatomic, weak) IBOutlet UILabel *forstaURLLabel;
@property (nonatomic, weak) IBOutlet UITextField *inputField;
@property (nonatomic, weak) IBOutlet UILabel *outputLabel;

@property (nonatomic, strong) FLTagMathService *tagService;

@property (nonatomic, strong) NSArray *validSupermanIDs;

@end

@implementation DeveloperPanelViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    
    self.outputLabel.text = [NSString stringWithFormat:@"UserID: %@", TSAccountManager.sharedInstance.myself.uniqueId];
    
    self.validSupermanIDs = @[ FLSupermanDevID, FLSupermanStageID, FLSupermanProdID ];
    
    self.supermanIDLabel.text = FLSupermanID;
    self.forstaURLLabel.text = FLHomeURL;
    
    [self tagService];
    
    [self updateView];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

-(void)updateView
{
    NSString *supermanID = [[CCSMStorage new] supermanId];
    NSUInteger supermanIndex;
    
    if (supermanID == nil || [supermanID isEqualToString:@""]) {
        supermanIndex = 0;
    } else {
        supermanIndex = [self.validSupermanIDs indexOfObject:supermanID];
    }
    
//    self.outputLabel.text = @"No output";
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
        [self.tagService tagLookupWithString:textField.text
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

//-(void)successfulLookupWithResults:(NSDictionary *)results
//{
//    dispatch_async(dispatch_get_main_queue(), ^{
//        self.outputLabel.text = [NSString stringWithFormat:@"Successful lookup:\n %@", results.description];
//    });
//}
//
//-(void)failedLookupWithError:(NSError *)error
//{
//    dispatch_async(dispatch_get_main_queue(), ^{
//        self.outputLabel.text = [NSString stringWithFormat:@"Failed lookup.  Error code:%ld\n %@", error.code, error.localizedDescription];
//    });
//}

-(FLTagMathService *)tagService
{
    if (_tagService == nil) {
        _tagService = [FLTagMathService new];
//        _tagService.delegate = self;
    }
    return _tagService;
}

@end
