//
//  DeveloperPanelViewController.m
//  Forsta
//
//  Created by Mark on 6/19/17.
//  Copyright © 2017 Forsta. All rights reserved.
//

#import "DeveloperPanelViewController.h"
#import "CCSMStorage.h"

@interface DeveloperPanelViewController ()

@property (nonatomic, weak) IBOutlet UIPickerView *supermanIDPicker;

@property (nonatomic, strong) NSArray *validSupermanIDs;

-(IBAction)didPressSave:(id)sender;
-(IBAction)didPressReset:(id)sender;

@end

@implementation DeveloperPanelViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    
    self.validSupermanIDs = @[ FLSupermanDevID, FLSupermanStageID, FLSupermanProdID ];
    
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
    [self.supermanIDPicker selectRow:(NSInteger)supermanIndex inComponent:0 animated:YES];
}

/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/

-(IBAction)didPressSave:(id)sender
{
    NSInteger supermanIndex = [self.supermanIDPicker selectedRowInComponent:0];
    [[CCSMStorage new] setSupermanId:[self.validSupermanIDs objectAtIndex:(NSUInteger)supermanIndex]];
    
    [self updateView];
}

-(IBAction)didPressReset:(id)sender
{
    [self updateView];
}

-(void)pickerView:(UIPickerView *)pickerView didSelectRow:(NSInteger)row inComponent:(NSInteger)component
{
    
}

-(NSInteger)pickerView:(UIPickerView *)pickerView numberOfRowsInComponent:(NSInteger)component
{
    return (NSInteger)[self.validSupermanIDs count];
}

-(NSInteger)numberOfComponentsInPickerView:(UIPickerView *)pickerView
{
    return 1;
}

-(NSString *)pickerView:(UIPickerView *)pickerView titleForRow:(NSInteger)row forComponent:(NSInteger)component
{
    return (NSString *)[self.validSupermanIDs objectAtIndex:(NSUInteger)row];
}

@end
