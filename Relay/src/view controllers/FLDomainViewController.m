//
//  FLDomainViewController.m
//  Forsta
//
//  Created by Mark on 6/5/17.
//  Copyright © 2017 Forsta. All rights reserved.
//

#import "FLDomainViewController.h"
#import "InboxTableViewCell.h"
#import "Environment.h"
#import "TSDatabaseView.h"
#import "OWSContactsManager.h"

#import <RelayServiceKit/OWSMessageSender.h>
#import <RelayServiceKit/TSMessagesManager.h>
#import <RelayServiceKit/TSOutgoingMessage.h>
#import <YapDatabase/YapDatabaseViewChange.h>
#import <YapDatabase/YapDatabaseViewConnection.h>

NSInteger const kConversationsIndex = 0;
NSInteger const kPinnedIndex = 1;
NSInteger const kAnnouncementsIndex = 2;
NSInteger const kTopicsIndex = 4;

CGFloat const kCellHeight = 72.0;
CGFloat const kHeaderHeight = 33.0;

@interface FLDomainViewController ()

@property (nonatomic, strong) NSArray *sectionTitles;
@property (nonatomic, strong) NSArray *sectionImages;

@property (nonatomic) long inboxCount;
@property (strong, nonatomic, readonly) OWSContactsManager *contactsManager;
@property (nonatomic) CellState viewingThreadsIn;

@property (nonatomic, readonly) TSMessagesManager *messagesManager;
@property (nonatomic, readonly) OWSMessageSender *messageSender;
@property (nonatomic, strong) YapDatabaseViewMappings *threadMappings;
@property (nonatomic, strong) YapDatabaseConnection *uiDatabaseConnection;
@property (nonatomic, strong) YapDatabaseConnection *editingDbConnection;

@end

@implementation FLDomainViewController

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
                                                      contactsManager:_contactsManager];
//                                                      contactsUpdater:[Environment getCurrent].contactsUpdater];
    
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
                                                      contactsManager:_contactsManager];
//                                                      contactsUpdater:[Environment getCurrent].contactsUpdater];
    
    return self;
}

//- (void)awakeFromNib
//{
//    [super awakeFromNib];
//    [[Environment getCurrent] setForstaViewController:self];
//}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    // Uncomment the following line to preserve selection between presentations.
    // self.clearsSelectionOnViewWillAppear = NO;
    
    // Uncomment the following line to display an Edit button in the navigation bar for this view controller.
    // self.navigationItem.rightBarButtonItem = self.editButtonItem;
    
/////////////////////
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
///////////////////////
    
    self.title = @"Domain";
    
    // Section header name and image in NSDictionary
    self.sectionTitles = @[NSLocalizedString(@"Conversation", @""),
                           NSLocalizedString(@"Pinned", @""),
                           NSLocalizedString(@"Announcements", @""),
                           NSLocalizedString(@"Topics", @"") ];
     self.sectionImages = @[[UIImage imageNamed:@"Chat_2"],
                            [UIImage imageNamed:@"Pin_2"],
                            [UIImage imageNamed:@"Announcements_2"],
                            [UIImage imageNamed:@"Topics_2"]];
}

//-(void)viewWillAppear:(BOOL)animated
//{
//    [self.uiDatabaseConnection beginLongLivedReadTransaction];
//}
//
//-(void)viewWillDisappear:(BOOL)animated
//{
//    [self.uiDatabaseConnection endLongLivedReadTransaction];
//    
//    [super viewDidDisappear:animated];
//}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 4;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    switch (section) {
        case kConversationsIndex:
        {
            return 0;
//            return (NSInteger)[self.threadMappings numberOfItemsInSection:(NSUInteger)section];
        }
            break;
        case kPinnedIndex:
        {
            return 0;
        }
            break;
        case kAnnouncementsIndex:
        {
            return 0;
        }
            break;
        case kTopicsIndex:
        {
            return 0;
        }
            break;
            
        default:
            // Bad thing.
            return 0;
            break;
    }
}

-(UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section
{
    // UIView to hold the things
    UIView *headerView = [[UIView alloc] initWithFrame:CGRectMake(0,
                                                                  0,
                                                                  self.view.frame.size.width,
                                                                  [self tableView:tableView heightForHeaderInSection:section]
                                                                  )];
    
    UIImageView *imageView = [[UIImageView alloc] initWithFrame:CGRectMake(0,
                                                                           0,
                                                                           [self tableView:tableView heightForHeaderInSection:section],
                                                                           [self tableView:tableView heightForHeaderInSection:section])];
    
    switch (section) {
        case kConversationsIndex:
        {
            imageView.backgroundColor = [UIColor colorWithRed:43/255.0 green:172/255.0 blue:226/255.0 alpha:1.0];
        }
            break;
        case kPinnedIndex:
        {
            imageView.backgroundColor = [UIColor colorWithRed:175/255.0 green:210/255.0 blue:63/255.0 alpha:1.0];
        }
            break;
        case kAnnouncementsIndex:
        {
            imageView.backgroundColor = [UIColor colorWithRed:244/255.0 green:125/255.0 blue:32/255.0 alpha:1.0];
        }
            break;
        case kTopicsIndex:
        {
            imageView.backgroundColor = [UIColor colorWithRed:128/255.0 green:206/255.0 blue:255/255.0 alpha:1.0];
        }
            break;
            
        default:
            break;
    }
    
    imageView.image = [self.sectionImages objectAtIndex:(NSUInteger)section];
    
    UILabel *label = [[UILabel alloc] initWithFrame:CGRectMake([self tableView:tableView heightForHeaderInSection:section],
                                                              0,
                                                              self.view.frame.size.width - imageView.frame.size.width,
                                                              [self tableView:tableView heightForHeaderInSection:section])];
    label.backgroundColor = [UIColor colorWithRed:202/255.0 green:202/255.0 blue:202/255.0 alpha:1.0];
    label.textAlignment = NSTextAlignmentCenter;
    label.text = [self.sectionTitles objectAtIndex:(NSUInteger)section];
    
    headerView.backgroundColor = [UIColor clearColor];
    
    
    [headerView addSubview:imageView];
    [headerView addSubview:label];  
    
    return headerView;
}

-(CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section
{
    return kHeaderHeight;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    return kCellHeight;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
//    static NSString *cellID = @"cell";
//    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellID forIndexPath:indexPath];
    
    // Configure the cell...
    InboxTableViewCell *cell =  [self.tableView dequeueReusableCellWithIdentifier:NSStringFromClass([InboxTableViewCell class])];
    
/**********  Disabling this table's content  ****************/
    
//    TSThread *thread = [self threadForIndexPath:indexPath];
//    
//    if (!cell) {
//        cell = [InboxTableViewCell inboxTableViewCell];
//    }
//    
//    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
//        [cell configureWithThread:thread contactsManager:self.contactsManager];
//    });
//    
//    if ((unsigned long)indexPath.row == [self.threadMappings numberOfItemsInSection:0] - 1) {
//        cell.separatorInset = UIEdgeInsetsMake(0.f, cell.bounds.size.width, 0.f, 0.f);
//    }
    
    return cell;
}

-(void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (tableView == self.tableView)    //  check for main tableview or...
    {
        TSThread *selectedThread = [self threadForIndexPath:indexPath];
        [selectedThread markAllAsRead];
//        self.hostViewController.selectedThread = selectedThread;
        [self.hostViewController hideDomainTableView];
        self.hostViewController.newConversation = NO;
        [self.hostViewController reloadTableView];
        [self.tableView deselectRowAtIndexPath:indexPath animated:YES];
    }
    else   // autocomplete tableview
    {
    }
}

- (TSThread *)threadForIndexPath:(NSIndexPath *)indexPath {
    __block TSThread *thread = nil;
    [self.uiDatabaseConnection readWithBlock:^(YapDatabaseReadTransaction *transaction) {
        thread = [[transaction extension:TSThreadDatabaseViewExtensionName] objectAtIndexPath:indexPath
                                                                                 withMappings:self.threadMappings];
    }];
    
    return thread;
}


/*
// Override to support conditional editing of the table view.
- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
    // Return NO if you do not want the specified item to be editable.
    return YES;
}
*/

/*
// Override to support editing the table view.
- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath {
    if (editingStyle == UITableViewCellEditingStyleDelete) {
        // Delete the row from the data source
        [tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationFade];
    } else if (editingStyle == UITableViewCellEditingStyleInsert) {
        // Create a new instance of the appropriate class, insert it into the array, and add a new row to the table view
    }   
}
*/

/*
// Override to support rearranging the table view.
- (void)tableView:(UITableView *)tableView moveRowAtIndexPath:(NSIndexPath *)fromIndexPath toIndexPath:(NSIndexPath *)toIndexPath {
}
*/

/*
// Override to support conditional rearranging of the table view.
- (BOOL)tableView:(UITableView *)tableView canMoveRowAtIndexPath:(NSIndexPath *)indexPath {
    // Return NO if you do not want the item to be re-orderable.
    return YES;
}
*/

/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/

#pragma mark Database delegates

- (YapDatabaseConnection *)uiDatabaseConnection {
    NSAssert([NSThread isMainThread], @"Must access uiDatabaseConnection on main thread!");
    if (!_uiDatabaseConnection) {
        YapDatabase *database = TSStorageManager.sharedManager.database;
        _uiDatabaseConnection = [database newConnection];
//        [_uiDatabaseConnection beginLongLivedReadTransaction];
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

#pragma mark - Lazy instantiation
//-(YapDatabaseViewMappings *)threadMappings
//{
//    if (_threadMappings == nil) {
//        _threadMappings =
//        [[YapDatabaseViewMappings alloc] initWithGroups:@[ TSInboxGroup ] view:TSThreadDatabaseViewExtensionName];
//        [_threadMappings setIsReversed:NO forGroup:TSInboxGroup];
//        
//        [self.uiDatabaseConnection asyncReadWithBlock:^(YapDatabaseReadTransaction *transaction) {
//            [_threadMappings updateWithTransaction:transaction];
//            
//            dispatch_async(dispatch_get_main_queue(), ^{
//                [self.tableView reloadData];
//            });
//        }];
//    }
//    return _threadMappings;
//}

@end
