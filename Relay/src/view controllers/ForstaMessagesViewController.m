//
//  ForstaMessagesViewController.m
//  Forsta
//
//  Created by Mark on 6/2/17.
//  Copyright © 2017 Forsta. All rights reserved.
//

#import "AppDelegate.h"

#import "ForstaMessagesViewController.h"
#import "InboxTableViewCell.h"
#import "Environment.h"
#import "NSDate+millisecondTimeStamp.h"
#import "OWSContactsManager.h"
#import "PropertyListPreferences.h"
#import "PushManager.h"
#import "Relay-Swift.h"
#import "TSAccountManager.h"
#import "TSDatabaseView.h"
#import "TSGroupThread.h"
#import "TSStorageManager.h"
#import "UIUtil.h"
#import "VersionMigrations.h"
#import <RelayServiceKit/OWSMessageSender.h>
#import <RelayServiceKit/TSMessagesManager.h>
#import <RelayServiceKit/TSOutgoingMessage.h>
#import <YapDatabase/YapDatabaseViewChange.h>
#import <YapDatabase/YapDatabaseViewConnection.h>

@interface ForstaMessagesViewController ()

@property (strong, nonatomic, readonly) OWSContactsManager *contactsManager;
@property (nonatomic, readonly) TSMessagesManager *messagesManager;
@property (nonatomic, readonly) OWSMessageSender *messageSender;
@property (nonatomic, strong) YapDatabaseViewMappings *threadMappings;
@property (nonatomic, strong) YapDatabaseConnection *editingDbConnection;
@property (nonatomic, strong) YapDatabaseConnection *uiDatabaseConnection;

@property (nonatomic) CellState viewingThreadsIn;
@property (nonatomic) long inboxCount;
@property (nonatomic, strong) id previewingContext;


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

- (id)init
{
    self = [super init];
    if (!self) {
        return self;
    }
    
    _contactsManager = [Environment getCurrent].contactsManager;
    _messagesManager = [TSMessagesManager sharedManager];
    _messageSender = [[OWSMessageSender alloc] initWithNetworkManager:[Environment getCurrent].networkManager
                                                       storageManager:[TSStorageManager sharedManager]
                                                      contactsManager:_contactsManager
                                                      contactsUpdater:[Environment getCurrent].contactsUpdater];
    
    return self;
}

- (id)initWithCoder:(NSCoder *)aDecoder
{
    self = [super initWithCoder:aDecoder];
    if (!self) {
        return self;
    }
    
    _contactsManager = [Environment getCurrent].contactsManager;
    _messagesManager = [TSMessagesManager sharedManager];
    _messageSender = [[OWSMessageSender alloc] initWithNetworkManager:[Environment getCurrent].networkManager
                                                       storageManager:[TSStorageManager sharedManager]
                                                      contactsManager:_contactsManager
                                                      contactsUpdater:[Environment getCurrent].contactsUpdater];
    
    return self;
}

- (void)awakeFromNib
{
    [super awakeFromNib];
    [[Environment getCurrent] setForstaViewController:self];
}



- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
//////////////
    [self.navigationController.navigationBar setTranslucent:NO];
    
//    [self tableViewSetUp];
    
    self.editingDbConnection = TSStorageManager.sharedManager.newDatabaseConnection;
    
    [self.uiDatabaseConnection beginLongLivedReadTransaction];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(yapDatabaseModified:)
                                                 name:TSUIDatabaseConnectionDidUpdateNotification
                                               object:nil];
        
    [[[Environment getCurrent] contactsManager]
     .getObservableContacts watchLatestValue:^(id latestValue) {
         [self.tableView reloadData];
     }
     onThread:[NSThread mainThread]
     untilCancelled:nil];
    
    if ([self.traitCollection respondsToSelector:@selector(forceTouchCapability)] &&
        (self.traitCollection.forceTouchCapability == UIForceTouchCapabilityAvailable)) {
        [self registerForPreviewingWithDelegate:self sourceView:self.tableView];
    }

//////////////
    
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

#pragma mark - Lifted from SignalsViewController
- (void)presentThread:(TSThread *)thread keyboardOnViewAppearing:(BOOL)keyboardOnViewAppearing
{
    
}

- (NSNumber *)updateInboxCountLabel
{
    return [NSNumber numberWithInt:0];
}

- (void)composeNew
{
    
}

#pragma mark Database delegates

- (YapDatabaseConnection *)uiDatabaseConnection {
    NSAssert([NSThread isMainThread], @"Must access uiDatabaseConnection on main thread!");
    if (!_uiDatabaseConnection) {
        YapDatabase *database = TSStorageManager.sharedManager.database;
        _uiDatabaseConnection = [database newConnection];
        [_uiDatabaseConnection beginLongLivedReadTransaction];
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(yapDatabaseModified:)
                                                     name:YapDatabaseModifiedNotification
                                                   object:database];
    }
    return _uiDatabaseConnection;
}

- (void)yapDatabaseModified:(NSNotification *)notification {
    NSArray *notifications  = [self.uiDatabaseConnection beginLongLivedReadTransaction];
    NSArray *sectionChanges = nil;
    NSArray *rowChanges     = nil;
    
    [[self.uiDatabaseConnection ext:TSThreadDatabaseViewExtensionName] getSectionChanges:&sectionChanges
                                                                              rowChanges:&rowChanges
                                                                        forNotifications:notifications
                                                                            withMappings:self.threadMappings];
    
    // We want this regardless of if we're currently viewing the archive.
    // So we run it before the early return
//    [self updateInboxCountLabel];
    
    if ([sectionChanges count] == 0 && [rowChanges count] == 0) {
        return;
    }
    
    [self.tableView beginUpdates];
    
    for (YapDatabaseViewSectionChange *sectionChange in sectionChanges) {
        switch (sectionChange.type) {
            case YapDatabaseViewChangeDelete: {
                [self.tableView deleteSections:[NSIndexSet indexSetWithIndex:sectionChange.index]
                              withRowAnimation:UITableViewRowAnimationAutomatic];
                break;
            }
            case YapDatabaseViewChangeInsert: {
                [self.tableView insertSections:[NSIndexSet indexSetWithIndex:sectionChange.index]
                              withRowAnimation:UITableViewRowAnimationAutomatic];
                break;
            }
            case YapDatabaseViewChangeUpdate:
            case YapDatabaseViewChangeMove:
                break;
        }
    }
    
    for (YapDatabaseViewRowChange *rowChange in rowChanges) {
        switch (rowChange.type) {
            case YapDatabaseViewChangeDelete: {
                [self.tableView deleteRowsAtIndexPaths:@[ rowChange.indexPath ]
                                      withRowAnimation:UITableViewRowAnimationAutomatic];
                _inboxCount += (self.viewingThreadsIn == kArchiveState) ? 1 : 0;
                break;
            }
            case YapDatabaseViewChangeInsert: {
                [self.tableView insertRowsAtIndexPaths:@[ rowChange.newIndexPath ]
                                      withRowAnimation:UITableViewRowAnimationAutomatic];
                _inboxCount -= (self.viewingThreadsIn == kArchiveState) ? 1 : 0;
                break;
            }
            case YapDatabaseViewChangeMove: {
                [self.tableView deleteRowsAtIndexPaths:@[ rowChange.indexPath ]
                                      withRowAnimation:UITableViewRowAnimationAutomatic];
                [self.tableView insertRowsAtIndexPaths:@[ rowChange.newIndexPath ]
                                      withRowAnimation:UITableViewRowAnimationAutomatic];
                break;
            }
            case YapDatabaseViewChangeUpdate: {
                [self.tableView reloadRowsAtIndexPaths:@[ rowChange.indexPath ]
                                      withRowAnimation:UITableViewRowAnimationNone];
                break;
            }
        }
    }
    
    [self.tableView endUpdates];
//    [self checkIfEmptyView];
}


#pragma mark - TableView delegate and data source methods
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return (NSInteger)[self.threadMappings numberOfSections];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return (NSInteger)[self.threadMappings numberOfItemsInSection:(NSUInteger)section];
}

-(UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
//    NSString *aString = NSStringFromClass([InboxTableViewCell class]);
//    InboxTableViewCell *cell = (InboxTableViewCell *)[tableView dequeueReusableCellWithIdentifier:aString forIndexPath:indexPath];
   InboxTableViewCell *cell =  [self.tableView dequeueReusableCellWithIdentifier:NSStringFromClass([InboxTableViewCell class])];
    TSThread *thread = [self threadForIndexPath:indexPath];
    
    if (!cell) {
        cell = [InboxTableViewCell inboxTableViewCell];
    }
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        [cell configureWithThread:thread contactsManager:self.contactsManager];
    });
    
    if ((unsigned long)indexPath.row == [self.threadMappings numberOfItemsInSection:0] - 1) {
        cell.separatorInset = UIEdgeInsetsMake(0.f, cell.bounds.size.width, 0.f, 0.f);
    }
    
    return cell;

}

- (TSThread *)threadForIndexPath:(NSIndexPath *)indexPath {
    __block TSThread *thread = nil;
    [self.uiDatabaseConnection readWithBlock:^(YapDatabaseReadTransaction *transaction) {
        thread = [[transaction extension:TSThreadDatabaseViewExtensionName] objectAtIndexPath:indexPath
                                                                                 withMappings:self.threadMappings];
    }];
    
    return thread;
}


#pragma mark - convenience build methods
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

-(void)reloadTableView
{
    [self.tableView reloadData];
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

-(YapDatabaseViewMappings *)threadMappings
{
    if (_threadMappings == nil) {
        _threadMappings =
        [[YapDatabaseViewMappings alloc] initWithGroups:@[ TSInboxGroup ] view:TSThreadDatabaseViewExtensionName];
        [_threadMappings setIsReversed:YES forGroup:TSInboxGroup];
        
        [self.uiDatabaseConnection asyncReadWithBlock:^(YapDatabaseReadTransaction *transaction) {
            [_threadMappings updateWithTransaction:transaction];

            dispatch_async(dispatch_get_main_queue(), ^{
                [self.tableView reloadData];
            });
        }];
    }
    return _threadMappings;
}

@end
