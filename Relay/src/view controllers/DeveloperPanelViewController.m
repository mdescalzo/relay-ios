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

@property (nonatomic, weak) IBOutlet UITextField *supermanIDField;

-(IBAction)didPressSave:(id)sender;
-(IBAction)didPressReset:(id)sender;

@end

@implementation DeveloperPanelViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    
    [self updateView];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

-(void)updateView
{
    self.supermanIDField.text = [[CCSMStorage new] supermanId];
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
    [[CCSMStorage new] setSupermanId:self.supermanIDField.text];
    
    [self updateView];
}

-(IBAction)didPressReset:(id)sender
{
    [self updateView];
}

@end
