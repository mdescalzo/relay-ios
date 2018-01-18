//
//  FLThreadViewController.m
//  Forsta
//
//  Created by Mark on 6/2/17.
//  Copyright © 2017 Forsta. All rights reserved.
//

#import "AppDelegate.h"
#import "CCSMStorage.h"

#import "FLMessageSender.h"
#import "FLThreadViewController.h"
#import "FLDomainViewController.h"
#import "SettingsPopupMenuViewController.h"
#import "InboxTableViewCell.h"
#import "Environment.h"
#import "NSDate+millisecondTimeStamp.h"
#import "OWSCall.h"
#import "OWSCallCollectionViewCell.h"
#import "FLContactsManager.h"
#import "ConversationSettingsViewController.h"
#import "OWSDisappearingMessagesJob.h"
#import "OWSDisplayedMessageCollectionViewCell.h"
#import "OWSExpirableMessageView.h"
#import "OWSIncomingMessageCollectionViewCell.h"
#import "OWSMessagesBubblesSizeCalculator.h"
#import "OWSOutgoingMessageCollectionViewCell.h"
#import "PropertyListPreferences.h"
#import "PushManager.h"
#import "Relay-Swift.h"
#import "TSAccountManager.h"
#import "TSDatabaseView.h"
#import "TSStorageManager.h"
#import "UIUtil.h"
#import "VersionMigrations.h"
#import "TSAttachmentPointer.h"
#import "TSCall.h"
#import "TSContentAdapters.h"
//#import "TSErrorMessage.h"
#import "TSThread.h"
#import "TSIncomingMessage.h"
#import "TSInfoMessage.h"
#import "TSInvalidIdentityKeyErrorMessage.h"
#import "MimeTypeUtil.h"
#import "OWSAttachmentsProcessor.h"
#import "OWSDisappearingMessagesConfiguration.h"
#import "OWSFingerprint.h"
#import "OWSFingerprintBuilder.h"
#import "OWSMessageSender.h"
#import "SignalRecipient.h"
#import "TSAccountManager.h"
#import "TSInvalidIdentityKeySendingErrorMessage.h"
#import "TSMessagesManager.h"
#import "TSNetworkManager.h"
#import <YapDatabase/YapDatabaseViewChange.h>
#import <YapDatabase/YapDatabaseViewConnection.h>
#import <JSQSystemSoundPlayer.h>
#import "MessagesViewController.h"
#import "SecurityUtils.h"
#import "FLControlMessage.h"
#import "OWSDispatch.h"

@import Photos;

#define CELL_HEIGHT 72.0f
#define kLogoButtonTag 1001
#define kSettingsButtonTag 1002

NSString *kSelectedThreadIDKey = @"LastSelectedThreadID";
NSString *kUserIDKey = @"id";
NSString *FLUserSelectedFromDirectory = @"FLUserSelectedFromDirectory";


@interface FLThreadViewController ()

@property (nonatomic, strong) CCSMStorage *ccsmStorage;
@property (strong, nonatomic, readonly) FLContactsManager *contactsManager;
@property (nonatomic, readonly) TSMessagesManager *messagesManager;
//@property (nonatomic, readonly) OWSMessageSender *messageSender;
@property (nonatomic, readonly) FLMessageSender *messageSender;

@property (nonatomic, strong) YapDatabaseViewMappings *threadMappings;
@property (nonatomic, strong) YapDatabaseViewMappings *messageMappings;

@property (nonatomic, strong) YapDatabaseConnection *editingDbConnection;
@property (nonatomic, strong) YapDatabaseConnection *uiDatabaseConnection;
@property NSCache *messageAdapterCache;
@property (nonatomic) CellState viewingThreadsIn;
@property (nonatomic) long inboxCount;
@property (nonatomic, strong) id previewingContext;

// Gesture recognizers
//@property (strong, nonatomic) UISwipeGestureRecognizer *rightSwipeRecognizer;
//@property (strong, nonatomic) UISwipeGestureRecognizer *leftSwipeRecognizer;
@property (strong, nonatomic) UILongPressGestureRecognizer *longPressOnDirButton;

// Message handling
@property (nonatomic, strong) NSSet *taggedRecipientIDs;
@property (nonatomic, copy) NSString *universalTagExpression;
@property (nonatomic, copy) NSString *prettyTagString;
@property (nonatomic, strong) NSMutableArray *recipientTags;
@property (nonatomic, strong) NSMutableArray *attachmentIDs;
@property (nonatomic, strong) NSMutableArray *messages;

//@property (nonatomic, strong) IBOutlet UISearchController *searchController;
@property (weak, nonatomic) IBOutlet UISegmentedControl *archiveSelector;

@property (nonatomic, strong) FLDomainViewController *domainTableViewController;
@property (nonatomic, strong) SettingsPopupMenuViewController *settingsViewController;
@property (nonatomic, assign) BOOL isDomainViewVisible;
@property (nonatomic, strong) NSArray *userTags;

@property (nonatomic, strong) NSMutableArray *searchResult;

@property (nonatomic, strong) NSString *userId;
@property (nonatomic, strong) NSString *userDisplayName;

@property (nonatomic, weak) IBOutlet UIBarButtonItem *composeButton;
@property (nonatomic, weak) IBOutlet UIBarButtonItem *settingsButton;

@property (nonatomic, strong) UIButton *fabButton;

@end

@implementation FLThreadViewController

- (id)init
{
    self = [super init];
    if (!self) {
        return self;
    }
    
    _contactsManager = [Environment getCurrent].contactsManager;
    _messagesManager = [TSMessagesManager sharedManager];
    _messageSender = [[FLMessageSender alloc] initWithNetworkManager:[Environment getCurrent].networkManager
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
    _messageSender = [[FLMessageSender alloc] initWithNetworkManager:[Environment getCurrent].networkManager
                                                      storageManager:[TSStorageManager sharedManager]
                                                     contactsManager:_contactsManager];
    //                                                      contactsUpdater:[Environment getCurrent].contactsUpdater];
    
    return self;
}

- (void)awakeFromNib
{
    [super awakeFromNib];
    [[Environment getCurrent] setForstaViewController:self];
}

-(void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.editingDbConnection = TSStorageManager.sharedManager.newDatabaseConnection;
    
    [self.uiDatabaseConnection beginLongLivedReadTransaction];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(yapDatabaseModified:)
                                                 name:TSUIDatabaseConnectionDidUpdateNotification
                                               object:nil];
    
    // TODO: Investigate this!
    [[Environment getCurrent].contactsManager.getObservableContacts watchLatestValue:^(id latestValue) {
        [self.tableView reloadData];
    }
                                                                            onThread:[NSThread mainThread]
                                                                      untilCancelled:nil];
    
    if ([self.traitCollection respondsToSelector:@selector(forceTouchCapability)] &&
        (self.traitCollection.forceTouchCapability == UIForceTouchCapabilityAvailable)) {
        [self registerForPreviewingWithDelegate:self sourceView:self.tableView];
    }
    
    [self configureNavigationBar];
    [self longPressOnDirButton];
    
    // Popover handling
    self.modalPresentationStyle = UIModalPresentationPopover;
    self.popoverPresentationController.delegate = self;
    
    // setup methodology lifted from Signals
    [self ensureNotificationsUpToDate];
    [[Environment getCurrent].contactsManager doAfterEnvironmentInitSetup];
    
    // FAB
    [self.view addSubview:self.fabButton];
    [self.view bringSubviewToFront:self.fabButton];
    
    // Archive selector
    [self.archiveSelector setTitle:NSLocalizedString(@"WHISPER_NAV_BAR_TITLE", nil) forSegmentAtIndex:0];
    [self.archiveSelector setTitle:NSLocalizedString(@"ARCHIVE_NAV_BAR_TITLE", nil) forSegmentAtIndex:1];
    [self archiveSelectorValueChanged:self];
}

-(void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    [UIUtil applyForstaAppearence];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(markAllRead)
                                                 name:FLMarkAllReadNotification
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(reloadTableView)
                                                 name:FLSettingsUpdatedNotification
                                               object:nil];
}

-(void)viewDidDisappear:(BOOL)animated
{
    //    [[NSNotificationCenter defaultCenter] removeObserver:self
    //                                                    name:FLUserSelectedFromPopoverDirectoryNotification
    //                                                  object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:FLMarkAllReadNotification
                                                  object:nil];
    [super viewDidDisappear:animated];
}

//- (void)viewDidLayoutSubviews
//{
//    [super viewDidLayoutSubviews];
//    CGRect rect = self.navigationController.navigationBar.frame;
//    double y = rect.size.height + rect.origin.y;
//    self.tableView.contentInset = UIEdgeInsetsMake(y, 0, 0, 0);
//}

//-(BOOL)textView:(UITextView *)textView shouldChangeTextInRange:(NSRange)range replacementText:(NSString *)text
//{
//    return [super textView:textView shouldChangeTextInRange:range replacementText:text];
//}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

//- (void)didAppearForNewlyRegisteredUser
//{
//    ABAuthorizationStatus status = ABAddressBookGetAuthorizationStatus();
//    switch (status) {
//        case kABAuthorizationStatusNotDetermined:
//        case kABAuthorizationStatusRestricted: {
//            UIAlertController *controller =
//            [UIAlertController alertControllerWithTitle:NSLocalizedString(@"REGISTER_CONTACTS_WELCOME", nil)
//                                                message:NSLocalizedString(@"REGISTER_CONTACTS_BODY", nil)
//                                         preferredStyle:UIAlertControllerStyleAlert];
//
//            [controller
//             addAction:[UIAlertAction
//                        actionWithTitle:NSLocalizedString(@"REGISTER_CONTACTS_CONTINUE", nil)
//                        style:UIAlertActionStyleCancel
//                        handler:^(UIAlertAction *action) {
//                            [self ensureNotificationsUpToDate];
//                            [[Environment getCurrent].contactsManager doAfterEnvironmentInitSetup];
//                        }]];
//
//            [self presentViewController:controller animated:YES completion:nil];
//            break;
//        }
//        default: {
//            DDLogError(@"%@ Unexpected for new user to have kABAuthorizationStatus:%ld", self.tag, status);
//            [self ensureNotificationsUpToDate];
//            [[Environment getCurrent].contactsManager doAfterEnvironmentInitSetup];
//
//            break;
//        }
//    }
//}

- (void)ensureNotificationsUpToDate
{
    OWSAccountManager *accountManager =
    [[OWSAccountManager alloc] initWithTextSecureAccountManager:[TSAccountManager sharedInstance]];
    
    OWSSyncPushTokensJob *syncPushTokensJob =
    [[OWSSyncPushTokensJob alloc] initWithPushManager:[PushManager sharedManager]
                                       accountManager:accountManager
                                          preferences:[Environment preferences]];
    [syncPushTokensJob run];
}

#pragma mark - Table Swipe to Delete
- (void)tableView:(UITableView *)tableView
commitEditingStyle:(UITableViewCellEditingStyle)editingStyle
forRowAtIndexPath:(NSIndexPath *)indexPath
{
    return;
}

- (NSArray *)tableView:(UITableView *)tableView editActionsForRowAtIndexPath:(NSIndexPath *)indexPath
{
    UITableViewRowAction *deleteAction =
    [UITableViewRowAction rowActionWithStyle:UITableViewRowActionStyleDestructive
                                       title:NSLocalizedString(@"TXT_DELETE_TITLE", nil)
                                     handler:^(UITableViewRowAction *action, NSIndexPath *swipedIndexPath) {
                                         [self tableViewCellTappedDelete:swipedIndexPath];
                                     }];
    
    UITableViewRowAction *archiveAction = nil;
    if (self.viewingThreadsIn == kInboxState) {
        UITableViewRowAction *pinAction = nil;
        if (indexPath.section == 0) {  //  Pinned conversation
            pinAction = [UITableViewRowAction rowActionWithStyle:UITableViewRowActionStyleNormal
                                                           title:NSLocalizedString(@"UNPIN_ACTION", nil)
                                                         handler:^(UITableViewRowAction * _Nonnull action, NSIndexPath * _Nonnull tappedIndexPath) {
                                                             [self togglePinningForThreadAtIndexPath:indexPath];
                                                         }];
        } else if (indexPath.section == 1) {  // Unpinned conversation
            pinAction = [UITableViewRowAction rowActionWithStyle:UITableViewRowActionStyleNormal
                                                           title:NSLocalizedString(@"PIN_ACTION", nil)
                                                         handler:^(UITableViewRowAction * _Nonnull action, NSIndexPath * _Nonnull tappedIndexPath) {
                                                             [self togglePinningForThreadAtIndexPath:indexPath];
                                                         }];
        }
        pinAction.backgroundColor = [ForstaColors mediumGreen];
        
        archiveAction = [UITableViewRowAction
                         rowActionWithStyle:UITableViewRowActionStyleNormal
                         title:NSLocalizedString(@"ARCHIVE_ACTION", @"Pressing this button moves a thread from the inbox to the archive")
                         handler:^(UITableViewRowAction *_Nonnull action, NSIndexPath *_Nonnull tappedIndexPath) {
                             [self archiveIndexPath:tappedIndexPath];
                             [Environment.preferences setHasArchivedAMessage:YES];
                         }];
        return @[ archiveAction, pinAction, deleteAction ];
    } else {
        archiveAction = [UITableViewRowAction
                         rowActionWithStyle:UITableViewRowActionStyleNormal
                         title:NSLocalizedString(@"UNARCHIVE_ACTION", @"Pressing this button moves an archived thread from the archive back to the inbox")
                         handler:^(UITableViewRowAction *_Nonnull action, NSIndexPath *_Nonnull tappedIndexPath) {
                             [self archiveIndexPath:tappedIndexPath];
                         }];
        return @[ archiveAction, deleteAction ];
    }
}

- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
    return YES;
}

#pragma mark - Cell Swipe Actions
- (void)tableViewCellTappedDelete:(NSIndexPath *)indexPath
{
    dispatch_async(dispatch_get_main_queue(), ^{
    __block TSThread *thread = [self threadForIndexPath:indexPath];
    
    NSString *alertMessage = [NSString stringWithFormat:NSLocalizedString(@"DELETE_THREAD_VALIDATION_MESSAGE", nil), thread.displayName];
    UIAlertController *validationAlert = [UIAlertController alertControllerWithTitle:nil
                                                                             message:alertMessage
                                                                      preferredStyle:UIAlertControllerStyleActionSheet];
        [validationAlert addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"YES", nil)
                                                            style:UIAlertActionStyleDestructive
                                                          handler:^(UIAlertAction * _Nonnull action) {
                                                              [self.editingDbConnection asyncReadWriteWithBlock:^(YapDatabaseReadWriteTransaction * _Nonnull transaction) {
                                                                  [thread removeParticipants:[NSSet setWithObject:TSAccountManager.sharedInstance.myself.flTag.uniqueId] transaction:transaction];
                                                                  
                                                              } completionBlock:^{
                                                                  FLControlMessage *message = [[FLControlMessage alloc] initControlMessageForThread:thread
                                                                                                                                             ofType:FLControlMessageThreadUpdateKey];
                                                                  [Environment.getCurrent.messageSender sendControlMessage:message
                                                                                                              toRecipients:[NSCountedSet setWithArray:thread.participants]
                                                                                                                   success:^{
                                                                                                                       [self deleteThread:thread];
                                                                                                                   }
                                                                                                                   failure:^(NSError *error) {
                                                                                                                       DDLogDebug(@"Failed to delete thread.  Error: %@", error.localizedDescription);
                                                                                                                       [self deleteThread:thread];
                                                                                                                   }];
                                                              }];
                                                          }]];
        [validationAlert addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"NO", nil)
                                                            style:UIAlertActionStyleCancel
                                                      handler:^(UIAlertAction * _Nonnull action) {
                                                          //
                                                      }]];
        [self.navigationController presentViewController:validationAlert animated:YES completion:nil];
    });
}

- (void)deleteThread:(TSThread *)thread {
    [self.editingDbConnection asyncReadWriteWithBlock:^(YapDatabaseReadWriteTransaction *transaction) {
        [thread removeWithTransaction:transaction];
    }];
    
    _inboxCount -= (self.viewingThreadsIn == kArchiveState) ? 1 : 0;
    //    [self checkIfEmptyView];
}



#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
    if ([segue.identifier isEqualToString:@"SettingsPopoverSegue"]) {
        segue.destinationViewController.popoverPresentationController.delegate = self;
        segue.destinationViewController.preferredContentSize = CGSizeMake(self.tableView.frame.size.width*2/3, [self.settingsViewController heightForTableView]);
        segue.destinationViewController.popoverPresentationController.barButtonItem = self.navigationItem.rightBarButtonItem;
    }
    else if ([[segue identifier] isEqualToString:@"threadSelectedSegue"]) {
        self.navigationItem.backBarButtonItem.title = @"";
        MessagesViewController *destination = (MessagesViewController *)segue.destinationViewController;
        [destination configureForThread:[self threadForIndexPath:[self.tableView indexPathForSelectedRow]] keyboardOnViewAppearing:NO];
    }
}

-(IBAction)unwindToMessagesView:(UIStoryboardSegue *)sender
{
}

#pragma mark - Lifted from SignalsViewController
- (void)presentThread:(TSThread *)thread keyboardOnViewAppearing:(BOOL)keyboardOnViewAppearing
{
    dispatch_async(dispatch_get_main_queue(), ^{
        MessagesViewController *mvc = [[UIStoryboard storyboardWithName:AppDelegateStoryboardMain bundle:NULL]
                                       instantiateViewControllerWithIdentifier:@"MessagesViewController"];
        
        if (self.presentedViewController) {
            [self.presentedViewController dismissViewControllerAnimated:YES completion:nil];
        }
        [self.navigationController popToRootViewControllerAnimated:YES];
        
        [mvc configureForThread:thread keyboardOnViewAppearing:keyboardOnViewAppearing];
        [self.navigationController pushViewController:mvc animated:YES];
    });
}

- (NSNumber *)updateInboxCountLabel
{
    return [NSNumber numberWithInt:0];
}

#pragma mark - swipe handlers
#pragma mark Currently Disabled
//-(IBAction)onSwipeToTheRight:(id)sender
//{
//    if (self.domainTableViewController.view.hidden) {
//        if ([self.textView isFirstResponder])
//            [self.textView resignFirstResponder];
//        [self showDomainTableView];
//    }
//}
//
//-(IBAction)onSwipeToTheLeft:(id)sender
//{
//    if (!self.domainTableViewController.view.hidden) {
//        [self hideDomainTableView];
//    }
//}

#pragma mark - helpers
-(void)togglePinningForThreadAtIndexPath:(NSIndexPath *)indexPath
{
    TSThread *thread = [self threadForIndexPath:indexPath];
    if (thread) {
        if (thread.pinPosition) {
            thread.pinPosition = nil;
        } else {
            thread.pinPosition = [NSNumber numberWithInteger:[self.tableView numberOfRowsInSection:0] + 1];
        }
        [self.editingDbConnection asyncReadWriteWithBlock:^(YapDatabaseReadWriteTransaction *transaction) {
            [thread saveWithTransaction:transaction];
        }];
    }
}

- (void)archiveIndexPath:(NSIndexPath *)indexPath {
    TSThread *thread = [self threadForIndexPath:indexPath];
    
    BOOL viewingThreadsIn = self.viewingThreadsIn;
    [self.editingDbConnection readWriteWithBlock:^(YapDatabaseReadWriteTransaction *transaction) {
        viewingThreadsIn == kInboxState ? [thread archiveThreadWithTransaction:transaction]
        : [thread unarchiveThreadWithTransaction:transaction];
    }];
    
    FLControlMessage *controlMessage = nil;
    if (viewingThreadsIn == kInboxState) {
        // TODO: Change to FLControlMessageThreadArchiveKey after other clients setup handling for it.
        controlMessage = [[FLControlMessage alloc] initControlMessageForThread:thread ofType:FLControlMessageThreadCloseKey];
    } else if (viewingThreadsIn == kArchiveState) {
        controlMessage = [[FLControlMessage alloc] initControlMessageForThread:thread ofType:FLControlMessageThreadRestoreKey];
    }
    if (controlMessage) {
        dispatch_async([OWSDispatch sendingQueue], ^{
            [Environment.getCurrent.messageSender sendSyncTranscriptForMessage:controlMessage];
        });
    }
    
    //    [self checkIfEmptyView];
}

#pragma mark - Domain View handling
-(void)showDomainTableView
{
    CGFloat navBarHeight = self.navigationController.navigationBar.bounds.size.height;
    CGFloat statusBarHeight = [[UIApplication sharedApplication] statusBarFrame].size.height;
    
    //    self.domainTableViewController.view.hidden = NO;
    //    self.isDomainViewVisible = YES;
    self.domainTableViewController.view.hidden = NO;
    [UIView animateWithDuration:0.25 animations:^{
        self.domainTableViewController.view.frame = CGRectMake(0, (navBarHeight + statusBarHeight),
                                                               self.tableView.frame.size.width * 2/3,
                                                               self.tableView.frame.size.height);
    }];
}

-(void)hideDomainTableView
{
    CGFloat navBarHeight = self.navigationController.navigationBar.bounds.size.height;
    CGFloat statusBarHeight = [[UIApplication sharedApplication] statusBarFrame].size.height;
    
    [UIView animateWithDuration:0.25 animations:^{
        self.domainTableViewController.view.frame = CGRectMake(-self.domainTableViewController.view.frame.size.width
                                                               , (navBarHeight + statusBarHeight),
                                                               self.tableView.frame.size.width * 2/3,
                                                               self.tableView.frame.size.height);
    }
                     completion:^(BOOL finished) {
                         self.domainTableViewController.view.hidden = YES;
                     }];
}

#pragma mark - Message handling
- (TSInteraction *)interactionAtIndexPath:(NSIndexPath *)indexPath {
    __block TSInteraction *message = nil;
    [self.uiDatabaseConnection readWithBlock:^(YapDatabaseReadTransaction *transaction) {
        YapDatabaseViewTransaction *viewTransaction = [transaction ext:TSMessageDatabaseViewExtensionName];
        NSParameterAssert(viewTransaction != nil);
        NSParameterAssert(self.messageMappings != nil);
        NSParameterAssert(indexPath != nil);
        NSUInteger row                    = (NSUInteger)indexPath.row;
        NSUInteger section                = (NSUInteger)indexPath.section;
        NSUInteger numberOfItemsInSection __unused = [self.messageMappings numberOfItemsInSection:section];
        NSAssert(row < numberOfItemsInSection,
                 @"Cannot fetch message because row %d is >= numberOfItemsInSection %d",
                 (int)row,
                 (int)numberOfItemsInSection);
        
        message = [viewTransaction objectAtRow:row inSection:section withMappings:self.messageMappings];
        NSParameterAssert(message != nil);
    }];
    
    return message;
}

-(BOOL)isValidUserID:(NSString *)userid
{
    if ([self.userTags containsObject:userid])
        return YES;
    else
        return NO;
}

#pragma mark - Database delegates

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
    [self updateInboxCountLabel];
    
    if ([sectionChanges count] == 0 && [rowChanges count] == 0) {
        return;
    }
    
    __block BOOL scrollToBottom = NO;
    
    // Wrapping the table update in order to attach a completion handler in order to
    //   scroll to bottom if necessary.
    [CATransaction begin];
    [CATransaction setCompletionBlock:^{
        if (scrollToBottom) {
            [self scrollTableViewToBottom];
        }
    }];
    
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
                //                [self.tableView endUpdates];
                break;
            }
            case YapDatabaseViewChangeInsert: {
                [self.tableView insertRowsAtIndexPaths:@[ rowChange.newIndexPath ]
                                      withRowAnimation:UITableViewRowAnimationAutomatic];
                _inboxCount -= (self.viewingThreadsIn == kArchiveState) ? 1 : 0;
                scrollToBottom = YES;
                //                [self.tableView endUpdates];
                //                dispatch_async(dispatch_get_main_queue(), ^{
                //                    [self.tableView scrollToRowAtIndexPath:rowChange.newIndexPath atScrollPosition:UITableViewScrollPositionBottom animated:YES];
                //                });
                break;
            }
            case YapDatabaseViewChangeMove: {
                [self.tableView deleteRowsAtIndexPaths:@[ rowChange.indexPath ]
                                      withRowAnimation:UITableViewRowAnimationAutomatic];
                [self.tableView insertRowsAtIndexPaths:@[ rowChange.newIndexPath ]
                                      withRowAnimation:UITableViewRowAnimationAutomatic];
                scrollToBottom = YES;
                //                [self.tableView endUpdates];
                //                dispatch_async(dispatch_get_main_queue(), ^{
                //                    [self.tableView scrollToRowAtIndexPath:rowChange.newIndexPath atScrollPosition:UITableViewScrollPositionBottom animated:YES];
                //                });
                break;
            }
            case YapDatabaseViewChangeUpdate: {
                [self.tableView reloadRowsAtIndexPaths:@[ rowChange.indexPath ]
                                      withRowAnimation:UITableViewRowAnimationNone];
                //                [self.tableView endUpdates];
                break;
            }
            default: {
                //                [self.tableView endUpdates];
            }
        }
    }
    
    [self.tableView endUpdates];
    [CATransaction commit];
    
    //    [self checkIfEmptyView];
}

-(void)scrollTableViewToBottom
{
    //    dispatch_async(dispatch_get_main_queue(), ^{
    //        NSIndexPath *bottomPath = [NSIndexPath indexPathForRow:[self.tableView numberOfRowsInSection:0]-1 inSection:0];
    //        NSIndexPath *bottomPath = [NSIndexPath indexPathForRow:0 inSection:0];
    //        [self.tableView scrollToRowAtIndexPath:bottomPath atScrollPosition:UITableViewScrollPositionTop animated:YES];
    //    });
    
    //    if (self.tableView.contentSize.height > self.tableView.frame.size.height)
    //    {
    //        CGPoint offset = CGPointMake(0, self.tableView.contentSize.height - self.tableView.frame.size.height);
    //        [self.tableView setContentOffset:offset animated:YES];
    //    }
}

#pragma mark - TableView delegate and data source methods
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return (NSInteger)[self.threadMappings numberOfSections];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    if ([tableView isEqual:self.tableView]) {
        return (NSInteger)[self.threadMappings numberOfItemsInSection:(NSUInteger)section];
    }
    else {
        return (NSInteger)self.searchResult.count;
    }
}

-(NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
    NSInteger rows = [self tableView:tableView numberOfRowsInSection:section];
    if (rows > 0 && self.viewingThreadsIn == kInboxState) {
        if (section == 0) {
            return NSLocalizedString(@"PINNED_CONVERSATION_SECTION", nil);
        } else if (section == 1) {
            return NSLocalizedString(@"RECENT_CONVERSATION_SECTION", nil);
        }
    }
    return nil;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    
    if ([tableView isEqual:self.tableView]) {
        return CELL_HEIGHT;
    }
    else {
        return CELL_HEIGHT - 8.0;
    }
    
}

-(UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    return [self messageCellForRowAtIndexPath:indexPath];
}

-(UITableViewCell *)messageCellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    InboxTableViewCell *cell =
    [self.tableView dequeueReusableCellWithIdentifier:NSStringFromClass([InboxTableViewCell class])];
    TSThread *thread = [self threadForIndexPath:indexPath];
    
    if (!cell) {
        cell = [InboxTableViewCell inboxTableViewCell];
    }
    
    dispatch_async([OWSDispatch storageQueue], ^{
        [cell configureWithThread:thread contactsManager:self.contactsManager];
    });
    
    if ((unsigned long)indexPath.row == [self.threadMappings numberOfItemsInSection:0] - 1) {
        cell.separatorInset = UIEdgeInsetsMake(0.f, cell.bounds.size.width, 0.f, 0.f);
    }
    
    return cell;
}

-(void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    [self performSegueWithIdentifier:@"threadSelectedSegue" sender:[self.tableView cellForRowAtIndexPath:indexPath]];
    
    [self.tableView deselectRowAtIndexPath:indexPath animated:YES];
}

- (TSThread *)threadForIndexPath:(NSIndexPath *)indexPath {
    __block TSThread *thread = nil;
    [self.uiDatabaseConnection readWithBlock:^(YapDatabaseReadTransaction *transaction) {
        thread = [[transaction extension:TSThreadDatabaseViewExtensionName] objectAtIndexPath:indexPath
                                                                                 withMappings:self.threadMappings];
    }];
    
    // "Heal" any unnamed conversations which may be in the database.
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0), ^{
        if ([thread.displayName isEqualToString:NSLocalizedString(@"Unnamed converstaion", @"")]) {
            if (thread.universalExpression.length > 0) {
                [CCSMCommManager asyncTagLookupWithString:thread.universalExpression
                                                  success:^(NSDictionary * _Nonnull lookupDict) {
                                                      if (lookupDict) {
                                                          [self.editingDbConnection asyncReadWriteWithBlock:^(YapDatabaseReadWriteTransaction *transaction) {
                                                              thread.participants = [lookupDict objectForKey:@"userids"];
                                                              thread.prettyExpression = [lookupDict objectForKey:@"pretty"];
                                                              [thread saveWithTransaction:transaction];
                                                          }];
                                                      }
                                                  } failure:^(NSError * _Nonnull error) {
                                                      DDLogError(@"%@: TagMath lookup failed for thread repair.  Error: %@", self.tag, error.localizedDescription);
                                                  }];
            }
        }
    });

    return thread;
}

- (void)resetFrame {
    // fixes bug on frame being off after this selection
    CGRect frame    = [UIScreen mainScreen].applicationFrame;
    self.view.frame = frame;
}

-(void)markAllRead
{
    for (NSInteger row=0; row < [self.tableView numberOfRowsInSection:0]; row++) {
        TSThread *thread = [self threadForIndexPath:[NSIndexPath indexPathForRow:row inSection:0]];
        [thread markAllAsRead];
    }
    DDLogInfo(@"Marked all threads as read.");
}

-(void)configureNavigationBar
{
    self.title = [self.ccsmStorage getOrgName];
    
    [UINavigationBar appearance].barTintColor = [UIColor blackColor];
    [UINavigationBar appearance].tintColor = [UIColor whiteColor];
    
    //    self.navigationController.navigationBar.barTintColor = [UIColor blackColor];
    //    self.navigationController.navigationBar.tintColor = [UIColor whiteColor];
    self.navigationController.navigationBar.translucent = NO;
    
#ifdef DEVELOPMENT
    UIBarButtonItem *logoItem = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"Forsta_logo_DEV"]
                                                                 style:UIBarButtonItemStylePlain
                                                                target:self
                                                                action:nil];
#elif STAGE
    UIBarButtonItem *logoItem = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"Forsta_logo_PRE"]
                                                                 style:UIBarButtonItemStylePlain
                                                                target:self
                                                                action:nil];
#else // Assume Production build
    UIBarButtonItem *logoItem = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"Forsta_text_logo"]
                                                                 style:UIBarButtonItemStylePlain
                                                                target:self
                                                                action:nil];
#endif
    logoItem.tag = kLogoButtonTag;
    self.navigationItem.leftBarButtonItem = logoItem;
}

-(void)reloadTableView
{
    [self.tableView reloadData];
}

-(void)tagsRefreshed
{
    // set to nil, it will rebuild through lazy instantiation.
    self.userTags = nil;
}

#pragma mark - Button actions
-(void)fabTapped:(id)sender
{
    [self performSegueWithIdentifier:@"composeThreadSegue" sender:self];
}
//-(IBAction)composeNew:(id)sender
//{
//    [self performSegueWithIdentifier:@"SettingsPopoverSegue" sender:sender];
//}

//-(IBAction)onLogoTap:(id)sender
//{
//    // Logo icon tapped
//}

//-(IBAction)onSettingsTap:(UIBarButtonItem *)sender
//{
//    // Display settings view
//    [self performSegueWithIdentifier:@"SettingsPopoverSegue" sender:sender];
//}

#pragma mark - UIPopover delegate methods
- (UIModalPresentationStyle)adaptivePresentationStyleForPresentationController:(UIPresentationController *)controller
{
    return UIModalPresentationNone;
}

#pragma mark - UISearchResultsUpdating

- (void)updateSearchResultsForSearchController:(UISearchController *)searchController {
    //    NSString *searchString = [self.searchController.searchBar text];
    //
    //    [self filterContentForSearchText:searchString scope:nil];
    //
    //    [self.tableView reloadData];
}


#pragma mark - UISearchBarDelegate

- (void)searchBar:(UISearchBar *)searchBar selectedScopeButtonIndexDidChange:(NSInteger)selectedScope {
    //    [self updateSearchResultsForSearchController:self.searchController];
}

- (void)searchBarCancelButtonClicked:(UISearchBar *)searchBar {
    //    self.sendTextButton.hidden = YES;
}

#pragma mark - UISegmentController methods
- (IBAction)archiveSelectorValueChanged:(id)sender {
    if (self.archiveSelector.selectedSegmentIndex == 0) {
        [self selectedInbox:sender];
    } else if (self.archiveSelector.selectedSegmentIndex == 1) {
        [self selectedArchive:sender];
    }
}

#pragma mark - Accessors
-(UIButton *)fabButton
{
    if (_fabButton == nil) {
        _fabButton = [UIButton buttonWithType:UIButtonTypeRoundedRect];
        _fabButton.backgroundColor = [ForstaColors mediumDarkBlue2];
        [_fabButton setImage:[UIImage imageNamed:@"pencil-1"] forState:UIControlStateNormal];
        _fabButton.tintColor = [UIColor whiteColor];
        //        [_fabButton setTitle:@"+" forState:UIControlStateNormal];
        _fabButton.titleLabel.font = [UIFont systemFontOfSize:30.0 weight:UIFontWeightBold];
        [_fabButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        CGSize buttonSize = CGSizeMake(60.0, 60.0);
        CGRect screenRect = UIScreen.mainScreen.bounds;
        CGFloat navBarHeight = self.navigationController.navigationBar.bounds.size.height;
        CGFloat statusBarHeight = [[UIApplication sharedApplication] statusBarFrame].size.height;
        
        _fabButton.frame = CGRectMake(screenRect.size.width - (40.0 + buttonSize.width),
                                      screenRect.size.height - (40.0 + buttonSize.height) - (navBarHeight + statusBarHeight),
                                      buttonSize.width,
                                      buttonSize.height);
        
        _fabButton.layer.cornerRadius = buttonSize.height/2.0f;
        _fabButton.layer.shadowColor = [UIColor darkGrayColor].CGColor;
        _fabButton.layer.shadowOffset = CGSizeMake(1.0f, 3.0f);
        _fabButton.layer.shadowOpacity = 0.8f;
        _fabButton.layer.shadowRadius = 5.0f;
        [_fabButton addTarget:self action:@selector(fabTapped:) forControlEvents:UIControlEventTouchUpInside];
    }
    return _fabButton;
}

-(NSSet *)taggedRecipientIDs
{
    if (_taggedRecipientIDs == nil) {
        _taggedRecipientIDs = [NSSet new];
    }
    return _taggedRecipientIDs;
}

//-(FLDomainViewController *)domainTableViewController
//{
//    if (_domainTableViewController == nil) {
//        UIStoryboard *storyboard = [UIStoryboard storyboardWithName:@"Main_v2" bundle:[NSBundle mainBundle]];
//        _domainTableViewController = [storyboard instantiateViewControllerWithIdentifier:@"domainViewController"];
//        _domainTableViewController.hostViewController = self;
//        _domainTableViewController.view.frame =  CGRectMake(-self.tableView.frame.size.width * 2/3,
//                                                            self.tableView.frame.origin.y,
//                                                            self.tableView.frame.size.width * 2/3,
//                                                            self.tableView.frame.size.height);
//    }
//    return _domainTableViewController;
//}

-(SettingsPopupMenuViewController *)settingsViewController
{
    if (_settingsViewController == nil) {
        UIStoryboard *storyboard = [UIStoryboard storyboardWithName:@"Main_v2" bundle:[NSBundle mainBundle]];
        
        _settingsViewController = [storyboard instantiateViewControllerWithIdentifier:@"settingsViewController"];
        _settingsViewController.popoverPresentationController.delegate = self;
        //        _settingsViewController.tableView.frame = CGRectMake(0, 0, self.tableView.frame.size.width/2,
        //                                                             [_settingsViewController tableView:_settingsViewController.tableView heightForRowAtIndexPath:[NSIndexPath indexPathForRow:0 inSection:1]]);
        
        [self addChildViewController:_settingsViewController];
    }
    return _settingsViewController;
}

//-(UISearchController *)searchController
//{
//    if (_searchController == nil) {
//        _searchController = [[UISearchController alloc] initWithSearchResultsController:nil];
//        self.searchController.searchResultsUpdater = self;
//        self.searchController.dimsBackgroundDuringPresentation = NO;
//        self.searchController.hidesNavigationBarDuringPresentation = NO;
//
//        _searchController.delegate = self;
//    }
//    return _searchController;
//}

//-(UISwipeGestureRecognizer *)rightSwipeRecognizer
//{
//    if (_rightSwipeRecognizer == nil) {
//        _rightSwipeRecognizer = [[UISwipeGestureRecognizer alloc] initWithTarget:self action:@selector(onSwipeToTheRight:)];
//        _rightSwipeRecognizer.direction = UISwipeGestureRecognizerDirectionRight;
//        [self.tableView addGestureRecognizer:_rightSwipeRecognizer];
//    }
//    return _rightSwipeRecognizer;
//}
//
//-(UISwipeGestureRecognizer *)leftSwipeRecognizer
//{
//    if (_leftSwipeRecognizer == nil) {
//        _leftSwipeRecognizer = [[UISwipeGestureRecognizer alloc] initWithTarget:self action:@selector(onSwipeToTheLeft:)];
//        _leftSwipeRecognizer.direction = UISwipeGestureRecognizerDirectionLeft;
//        [self.tableView addGestureRecognizer:_leftSwipeRecognizer];
//    }
//    return _leftSwipeRecognizer;
//}

- (IBAction)selectedInbox:(id)sender {
    self.viewingThreadsIn = kInboxState;
    [self changeToGrouping:@[ TSPinnedGroup, TSInboxGroup ]];
}

- (IBAction)selectedArchive:(id)sender {
    self.viewingThreadsIn = kArchiveState;
    [self changeToGrouping:@[ TSArchiveGroup ]];
}

- (void)changeToGrouping:(NSArray *)grouping {
    self.threadMappings =
    [[YapDatabaseViewMappings alloc] initWithGroups:grouping view:TSThreadDatabaseViewExtensionName];
    for (NSString *group in grouping) {
        [self.threadMappings setIsReversed:YES forGroup:group];
    }
    
    [self.uiDatabaseConnection asyncReadWithBlock:^(YapDatabaseReadTransaction *transaction) {
        [self.threadMappings updateWithTransaction:transaction];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.tableView reloadData];
            //            [self checkIfEmptyView];
        });
    }];
}

//-(YapDatabaseViewMappings *)threadMappings
//{
//    if (_threadMappings == nil) {
//        NSArray *groups = nil;
//        if (self.viewingThreadsIn == kInboxState) {
//            groups = @[ TSPinnedGroup, TSInboxGroup ];
//        } else {
//            groups =  @[ TSArchiveGroup ];
//        }
//        _threadMappings =
//        [[YapDatabaseViewMappings alloc] initWithGroups:groups
//                                                   view:TSThreadDatabaseViewExtensionName];
//        [_threadMappings setIsReversed:YES forGroup:TSInboxGroup];
//        [_threadMappings setIsReversed:YES forGroup:TSArchiveGroup];
//        [_threadMappings setIsReversed:YES forGroup:TSPinnedGroup];
//
//        [self.uiDatabaseConnection asyncReadWithBlock:^(YapDatabaseReadTransaction *transaction) {
//            [_threadMappings updateWithTransaction:transaction];
//            dispatch_async(dispatch_get_main_queue(), ^{
//                [self.tableView reloadData];
//                //            [self checkIfEmptyView];
//            });
//        }];
//
//    }
//    return _threadMappings;
//}

-(NSArray *)userTags
{
    if (_userTags == nil) {
        // Pull the tags dictionary, pull the keys, and sort them alphabetically
        _userTags = [[[[Environment getCurrent].ccsmStorage getTags] allKeys] sortedArrayUsingSelector:@selector(localizedCaseInsensitiveCompare:)];
    }
    return _userTags;
}


-(NSString *)userId
{
    return [[[Environment getCurrent].ccsmStorage getUserInfo] objectForKey:kUserIDKey];
}

-(NSString *)userDisplayName
{
    return TSAccountManager.sharedInstance.myself.fullName;
}

-(NSMutableArray *)recipientTags
{
    if (_recipientTags ==  nil) {
        _recipientTags = [NSMutableArray new];
    }
    return _recipientTags;
}

-(NSMutableArray *)attachmentIDs
{
    if (_attachmentIDs == nil) {
        _attachmentIDs = [NSMutableArray new];
    }
    return _attachmentIDs;
}

-(CCSMStorage *)ccsmStorage
{
    if (_ccsmStorage == nil) {
        _ccsmStorage = [CCSMStorage new];
    }
    return _ccsmStorage;
}

#pragma mark - Logging

+ (NSString *)tag
{
    return [NSString stringWithFormat:@"[%@]", self.class];
}

- (NSString *)tag
{
    return self.class.tag;
}


@end
