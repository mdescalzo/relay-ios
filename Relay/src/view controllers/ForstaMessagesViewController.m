//
//  ForstaMessagesViewController.m
//  Forsta
//
//  Created by Mark on 6/2/17.
//  Copyright © 2017 Forsta. All rights reserved.
//

#import "ForstaMessagesViewController.h"

@interface ForstaMessagesViewController ()

@property (strong, nonatomic) UISwipeGestureRecognizer *swipeRecognizer;

@property (nonatomic, strong) NSMutableArray *messages;

@property (nonatomic, strong) IBOutlet UISearchBar *searchBar;

//@property (nonatomic, strong) NSArray *users;
//@property (nonatomic, strong) NSArray *channels;
//@property (nonatomic, strong) NSArray *emojis;
//@property (nonatomic, strong) NSArray *commands;

@property (nonatomic, strong) NSArray *searchResult;

@property (nonatomic, strong) UIWindow *pipWindow;

//@property (nonatomic, weak) Message *editingMessage;

@end

@implementation ForstaMessagesViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.

    [self configureNavigationBar];
    [self configureBottomButtons];
    [self swipeRecognizer];
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

-(NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return 0;
}

-(NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 1;
}

-(void)configureBottomButtons
{
    // Look at using segmentedcontrol to simulate multiple buttons on one side
    [self.leftButton setImage:[UIImage imageNamed:@"btnAttachments--blue"] forState:UIControlStateNormal];

    [self.rightButton setTitle:NSLocalizedString(@"Send", nil) forState:UIControlStateNormal];
    self.textInputbar.autoHideRightButton = NO;

}

-(void)configureNavigationBar
{
    UIBarButtonItem *logoItem = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"logo-40"]
                                                                style:UIBarButtonItemStylePlain
                                                               target:self
                                                               action:@selector(onLogoTap:)];
    
    UIBarButtonItem *settingsItem = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"settings"]
                                                                style:UIBarButtonItemStylePlain
                                                               target:self
                                                               action:@selector(onSettingsTap:)];
    
    self.navigationItem.leftBarButtonItem = logoItem;
    self.navigationItem.titleView = self.searchBar;
    self.navigationItem.rightBarButtonItem = settingsItem;
}

#pragma mark - swipe handler
-(IBAction)onSwipeToTheRight:(id)sender
{
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"DING" message:@"Swipe to the right" delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
    [alert show];
}

#pragma mark - Button actions
-(IBAction)onLogoTap:(id)sender
{
    // Logo icon tapped
}

-(IBAction)onSettingsTap:(id)sender
{
    // Settings button tapped
}

#pragma mark - Lazy instantiation
-(UISearchBar *)searchBar
{
    if (_searchBar == nil) {
        _searchBar = [UISearchBar new];
    }
    return _searchBar;
}

-(UISwipeGestureRecognizer *)swipeRecognizer
{
    if (_swipeRecognizer == nil) {
        _swipeRecognizer = [[UISwipeGestureRecognizer alloc] initWithTarget:self action:@selector(onSwipeToTheRight:)];
        _swipeRecognizer.direction = UISwipeGestureRecognizerDirectionRight;
        [self.tableView addGestureRecognizer:_swipeRecognizer];
    }
    return _swipeRecognizer;
}

@end
