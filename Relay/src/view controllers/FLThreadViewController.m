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
#import "OWSContactsManager.h"
#import "OWSConversationSettingsTableViewController.h"
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
#import "TSGroupThread.h"
#import "TSStorageManager.h"
#import "UIUtil.h"
#import "VersionMigrations.h"
#import "TSAttachmentPointer.h"
#import "TSCall.h"
#import "TSContactThread.h"
#import "TSContentAdapters.h"
#import "TSErrorMessage.h"
#import "TSGroupThread.h"
#import "TSIncomingMessage.h"
#import "TSInfoMessage.h"
#import "TSInvalidIdentityKeyErrorMessage.h"
#import <RelayServiceKit/MimeTypeUtil.h>
#import <RelayServiceKit/OWSAttachmentsProcessor.h>
#import <RelayServiceKit/OWSDisappearingMessagesConfiguration.h>
#import <RelayServiceKit/OWSFingerprint.h>
#import <RelayServiceKit/OWSFingerprintBuilder.h>
#import <RelayServiceKit/OWSMessageSender.h>
#import <RelayServiceKit/SignalRecipient.h>
#import <RelayServiceKit/TSAccountManager.h>
#import <RelayServiceKit/TSInvalidIdentityKeySendingErrorMessage.h>
#import <RelayServiceKit/TSMessagesManager.h>
#import <RelayServiceKit/TSNetworkManager.h>
#import <YapDatabase/YapDatabaseViewChange.h>
#import <YapDatabase/YapDatabaseViewConnection.h>
#import <JSQSystemSoundPlayer.h>
#import "MessagesViewController.h"

@import Photos;

#define CELL_HEIGHT 72.0f
#define kLogoButtonTag 1001

NSString *kSelectedThreadIDKey = @"LastSelectedThreadID";
NSString *kUserIDKey = @"phone";
NSString *FLUserSelectedFromDirectory = @"FLUserSelectedFromDirectory";


@interface FLThreadViewController ()

@property (nonatomic, strong) CCSMStorage *ccsmStorage;

@property (strong, nonatomic, readonly) OWSContactsManager *contactsManager;
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

@property (nonatomic, strong) NSMutableArray *taggedRecipients;
@property (nonatomic, strong) NSMutableArray *attachmentIDs;
@property (nonatomic, strong) NSMutableArray *messages;

@property (nonatomic, strong) IBOutlet UISearchBar *searchBar;
@property (nonatomic, weak) IBOutlet UILabel *bannerLabel;

@property (nonatomic, strong) FLDomainViewController *domainTableViewController;
@property (nonatomic, strong) SettingsPopupMenuViewController *settingsViewController;
@property (nonatomic, assign) BOOL isDomainViewVisible;
@property (nonatomic, strong) NSArray *userTags;

//@property (nonatomic, strong) NSArray *users;
//@property (nonatomic, strong) NSArray *channels;
//@property (nonatomic, strong) NSArray *emojis;
//@property (nonatomic, strong) NSArray *commands;

@property (nonatomic, strong) NSMutableArray *searchResult;

//@property (nonatomic, strong) UIWindow *pipWindow;

@property (nonatomic, strong) NSString *userId;
@property (nonatomic, strong) NSString *userDispalyName;

@property (nonatomic, strong) UIBarButtonItem *attachmentButton;
@property (nonatomic, strong) UIBarButtonItem *sendButton;
@property (nonatomic, strong) UIBarButtonItem *tagButton;
@property (nonatomic, strong) UIBarButtonItem *recipientCountButton;

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
    _messageSender = [[FLMessageSender alloc] initWithNetworkManager:[Environment getCurrent].networkManager
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

-(void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)viewDidLoad {
    [super viewDidLoad];

    [self.navigationController.navigationBar setTranslucent:NO];
    
    self.editingDbConnection = TSStorageManager.sharedManager.newDatabaseConnection;
    
    [self.uiDatabaseConnection beginLongLivedReadTransaction];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(yapDatabaseModified:)
                                                 name:TSUIDatabaseConnectionDidUpdateNotification
                                               object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(tagsRefreshed)
                                                 name:FLCCSMTagsUpdated
                                               object:nil];
    
    [[Environment getCurrent].contactsManager.getObservableContacts watchLatestValue:^(id latestValue) {
         [self.tableView reloadData];
     }
     onThread:[NSThread mainThread]
     untilCancelled:nil];
    
    if ([self.traitCollection respondsToSelector:@selector(forceTouchCapability)] &&
        (self.traitCollection.forceTouchCapability == UIForceTouchCapabilityAvailable)) {
        [self registerForPreviewingWithDelegate:self sourceView:self.tableView];
    }

    // Build the domain view/thread list
    [self.view addSubview:self.domainTableViewController.view];
    [self hideDomainTableView];
    
//    self.isDomainViewVisible = NO;
    
    self.inverted = NO;
    [self configureNavigationBar];
    [self configureBottomButtons];
//    [self rightSwipeRecognizer];
//    [self leftSwipeRecognizer];
    [self longPressOnDirButton];

    // Popover handling
    self.modalPresentationStyle = UIModalPresentationPopover;
    self.popoverPresentationController.delegate = self;

    self.textView.delegate = self;
    
    [self registerPrefixesForAutoCompletion:@[@"@", @"#", @":", @"+:", @"/"]];
    
    // Temporarily disable the searchbar since it isn't funcational yet
    self.searchBar.userInteractionEnabled = NO;
    
    self.textView.keyboardType = UIKeyboardTypeDefault;
    
    // Banner label - for testing purposes
    [self.view bringSubviewToFront:self.bannerLabel];
    self.bannerLabel.backgroundColor = [UIColor lightGrayColor];
    self.bannerLabel.hidden = YES;

    // setup methodology lifted from Signals
    [self ensureNotificationsUpToDate];
    [[Environment getCurrent].contactsManager doAfterEnvironmentInitSetup];
}

-(void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(selectedUserNotification:)
                                                 name:FLUserSelectedFromPopoverDirectoryNotification
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(markAllRead)
                                                 name:FLMarkAllReadNotification
                                               object:nil];
}

-(void)viewDidDisappear:(BOOL)animated
{
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:FLUserSelectedFromPopoverDirectoryNotification
                                                  object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:FLMarkAllReadNotification
                                                  object:nil];
    [super viewDidDisappear:animated];
}

-(BOOL)textView:(UITextView *)textView shouldChangeTextInRange:(NSRange)range replacementText:(NSString *)text
{
    return [super textView:textView shouldChangeTextInRange:range replacementText:text];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)didAppearForNewlyRegisteredUser
{
    ABAuthorizationStatus status = ABAddressBookGetAuthorizationStatus();
    switch (status) {
        case kABAuthorizationStatusNotDetermined:
        case kABAuthorizationStatusRestricted: {
            UIAlertController *controller =
            [UIAlertController alertControllerWithTitle:NSLocalizedString(@"REGISTER_CONTACTS_WELCOME", nil)
                                                message:NSLocalizedString(@"REGISTER_CONTACTS_BODY", nil)
                                         preferredStyle:UIAlertControllerStyleAlert];
            
            [controller
             addAction:[UIAlertAction
                        actionWithTitle:NSLocalizedString(@"REGISTER_CONTACTS_CONTINUE", nil)
                        style:UIAlertActionStyleCancel
                        handler:^(UIAlertAction *action) {
                            [self ensureNotificationsUpToDate];
                            [[Environment getCurrent].contactsManager doAfterEnvironmentInitSetup];
                        }]];
            
            [self presentViewController:controller animated:YES completion:nil];
            break;
        }
        default: {
            DDLogError(@"%@ Unexpected for new user to have kABAuthorizationStatus:%ld", self.tag, status);
            [self ensureNotificationsUpToDate];
            [[Environment getCurrent].contactsManager doAfterEnvironmentInitSetup];
            
            break;
        }
    }
}

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
forRowAtIndexPath:(NSIndexPath *)indexPath {
    return;
}


- (NSArray *)tableView:(UITableView *)tableView editActionsForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewRowAction *deleteAction =
    [UITableViewRowAction rowActionWithStyle:UITableViewRowActionStyleDefault
                                       title:NSLocalizedString(@"TXT_DELETE_TITLE", nil)
                                     handler:^(UITableViewRowAction *action, NSIndexPath *swipedIndexPath) {
                                         [self tableViewCellTappedDelete:swipedIndexPath];
                                     }];
    return @[ deleteAction ];
}

- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
    return YES;
}

#pragma mark - HomeFeedTableViewCellDelegate

- (void)tableViewCellTappedDelete:(NSIndexPath *)indexPath {
    TSThread *thread = [self threadForIndexPath:indexPath];
    if ([thread isKindOfClass:[TSGroupThread class]]) {
        
        TSGroupThread *gThread = (TSGroupThread *)thread;
        if ([gThread.groupModel.groupMemberIds containsObject:[TSAccountManager localNumber]]) {
            UIAlertController *removingFromGroup = [UIAlertController
                                                    alertControllerWithTitle:[NSString
                                                                              stringWithFormat:NSLocalizedString(@"GROUP_REMOVING", nil), [thread name]]
                                                    message:nil
                                                    preferredStyle:UIAlertControllerStyleAlert];
            [self presentViewController:removingFromGroup animated:YES completion:nil];
            
            TSOutgoingMessage *message = [[TSOutgoingMessage alloc] initWithTimestamp:[NSDate ows_millisecondTimeStamp]
                                                                             inThread:thread
                                                                          messageBody:@""
                                                                        attachmentIds:[NSMutableArray new]];
            message.groupMetaMessage = TSGroupMessageQuit;
            [self.messageSender sendMessage:message
                                    success:^{
                                        [self dismissViewControllerAnimated:YES
                                                                 completion:^{
                                                                     [self deleteThread:thread];
                                                                 }];
                                    }
                                    failure:^(NSError *error) {
                                        [self dismissViewControllerAnimated:YES
                                                                 completion:^{
                                                                     SignalAlertView(NSLocalizedString(@"GROUP_REMOVING_FAILED", nil),
                                                                                     error.localizedRecoverySuggestion);
                                                                 }];
                                    }];
        } else {
            [self deleteThread:thread];
        }
    } else {
        [self deleteThread:thread];
    }
}
- (void)deleteThread:(TSThread *)thread {
    [self.editingDbConnection readWriteWithBlock:^(YapDatabaseReadWriteTransaction *transaction) {
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
    if ([[segue identifier] isEqualToString:@"SettingsPopoverSegue"]) {
        [segue destinationViewController].popoverPresentationController.delegate = self;
        [segue destinationViewController].preferredContentSize = CGSizeMake(self.tableView.frame.size.width*2/3, [self.settingsViewController heightForTableView]);
        
//        CGRect aFrame = CGRectMake(self.navigationController.navigationBar.frame.size.width - [self frameForSettingsBarButton].size.width,
//                                   self.navigationController.navigationBar.frame.size.height - [self frameForSettingsBarButton].size.height,
//                                   self.navigationController.navigationBar.frame.size.height,
//                                   self.navigationController.navigationBar.frame.size.height + 20);

        [segue destinationViewController].popoverPresentationController.sourceRect = [self frameForLogoBarButton];
    }
    else if ([[segue identifier] isEqualToString:@"directoryPopoverSegue"]) {
        [segue destinationViewController].popoverPresentationController.delegate = self;
        [segue destinationViewController].preferredContentSize = CGSizeMake(self.tableView.frame.size.width * 0.75, self.tableView.frame.size.height * 0.75);
        CGRect aFrame = CGRectMake(self.textInputbar.frame.origin.x,
                                   self.textInputbar.frame.origin.y,
                                   self.leftButton.frame.size.width,
                                   self.leftButton.frame.size.height);
        [segue destinationViewController].popoverPresentationController.sourceRect = aFrame;
    }

    else if ([[segue identifier] isEqualToString:@"threadSelectedSegue"]) {
        self.navigationItem.backBarButtonItem.title = @"";

        MessagesViewController *destination = (MessagesViewController *)segue.destinationViewController;
        [destination configureForThread:[self threadForIndexPath:[self.tableView indexPathForSelectedRow]] keyboardOnViewAppearing:NO];
    }
}

-(CGRect)frameForLogoBarButton
{
    // Workaround for UIBarButtomItem not inheriting from UIView
    NSMutableArray* buttons = [[NSMutableArray alloc] init];
    for (UIControl* btn in self.navigationController.navigationBar.subviews) {
        if ([btn isKindOfClass:[UIControl class]] && btn.tag == kLogoButtonTag) {
            [buttons addObject:btn];
        }
    }
    CGRect buttonFrame = ((UIView*)[buttons lastObject]).frame;
    CGRect returnFrame = CGRectMake(buttonFrame.origin.x,
                                    buttonFrame.origin.y,
                                    buttonFrame.size.width + 72,
                                    buttonFrame.size.height + 60);

    return returnFrame;
}

-(IBAction)unwindToMessagesView:(UIStoryboardSegue *)sender
{
}

#pragma mark - Lifted from SignalsViewController

// One of the following should be implemented at some later date
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

//- (void)configureForThread:(TSThread *)thread keyboardOnViewAppearing:(BOOL)keyboardAppearing
//{
//    
//}


- (NSNumber *)updateInboxCountLabel
{
    return [NSNumber numberWithInt:0];
}


// Compose new message
- (void)composeNew:(id)sender
{
    [self performSegueWithIdentifier:@"composeNew" sender:nil];
}

- (void)didPressSendButton:(UIButton *)button
           withMessageText:(NSString *)text
                  senderId:(NSString *)senderId
         senderDisplayName:(NSString *)senderDisplayName
                      date:(NSDate *)date
{
    // Check the tagged user list.
    if ([self.taggedRecipients count] > 1) {
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"ALERT", @"")
                                                                       message:@"Multiple recipient support is current under development.  Using only the first @tagged recipient."
                                                                preferredStyle:UIAlertControllerStyleActionSheet];
        UIAlertAction *okButton = [UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleCancel handler:^(UIAlertAction * action) {}];
        [alert addAction:okButton];
        [self presentViewController:alert animated:YES completion:nil];
    } else {
        
        // Build the message parts
        NSString *recipientTag = [self.taggedRecipients firstObject];
        NSDictionary *tmpDict = [[self.ccsmStorage getTags] objectForKey:recipientTag];
        NSDictionary *recipientBlob = [tmpDict objectForKey:[tmpDict allKeys].lastObject];
        NSString *recipientID = [recipientBlob objectForKey:kUserIDKey];
        
        TSContactThread *thread = [TSContactThread getOrCreateThreadWithContactId:recipientID];
        
        TSOutgoingMessage *message;
        
        OWSDisappearingMessagesConfiguration *configuration =
        [OWSDisappearingMessagesConfiguration fetchObjectWithUniqueID:thread.uniqueId];
        
        if (configuration.isEnabled) {
            message = [[TSOutgoingMessage alloc] initWithTimestamp:[NSDate ows_millisecondTimeStamp]
                                                          inThread:thread
                                                       messageBody:text
                                                     attachmentIds:_attachmentIDs
                                                  expiresInSeconds:configuration.durationSeconds];
        } else {
            message = [[TSOutgoingMessage alloc] initWithTimestamp:[NSDate ows_millisecondTimeStamp]
                                                          inThread:thread
                                                       messageBody:text
                                                     attachmentIds:_attachmentIDs];
        }
        
        [self.taggedRecipients removeAllObjects];
        [self updateRecipientsLabel];
        
        [self.messageSender sendMessage:message
                                success:^{
                                    self.newConversation = NO;
                                    DDLogInfo(@"%@ Successfully sent message.", self.tag);
                                }
                                failure:^(NSError *error) {
                                    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Error"
                                                                                    message:[NSString stringWithFormat:@"Message failed to send.\n%@", [error localizedDescription] ]
                                                                                   delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
                                    [alert show];
                                    DDLogWarn(@"%@ Failed to deliver message with error: %@", self.tag, error);
                                }];
    }
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

//- (id<OWSMessageData>)messageAtIndexPath:(NSIndexPath *)indexPath
//{
//    TSInteraction *interaction = [self interactionAtIndexPath:indexPath];
//    
//    id<OWSMessageData> messageAdapter = [self.messageAdapterCache objectForKey:interaction.uniqueId];
//    
//    if (!messageAdapter) {
//        messageAdapter = [TSMessageAdapter messageViewDataWithInteraction:interaction inThread:self.selectedThread contactsManager:self.contactsManager];
//        [self.messageAdapterCache setObject:messageAdapter forKey: interaction.uniqueId];
//    }
//    
//    return messageAdapter;
//}

#pragma mark - Completion handling
- (void)didChangeAutoCompletionPrefix:(NSString *)prefix andWord:(NSString *)word
{
    NSArray *array = nil;
    
    [self.searchResult removeAllObjects];
    
    if ([prefix isEqualToString:@"@"]) {
        if (word.length > 0) {
            array = [self.userTags filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"self CONTAINS[c] %@", word]];
        }
        else {
            array = self.userTags;
        }
    }
    
    if (array.count > 0) {
        array = [array sortedArrayUsingSelector:@selector(localizedCaseInsensitiveCompare:)];
    }
    
    self.searchResult = [array mutableCopy];
    
    BOOL show = (self.searchResult.count > 0);
    
    [self showAutoCompletionView:show];
}

- (CGFloat)heightForAutoCompletionView
{
    CGFloat cellHeight = [self.autoCompletionView.delegate tableView:self.autoCompletionView heightForRowAtIndexPath:[NSIndexPath indexPathForRow:0 inSection:0]];
    return cellHeight*self.searchResult.count;
}

-(void)textViewDidChange:(UITextView *)textView
{
    // Grab initial selected range (cursor position) to restore later
    NSRange initialSelectedRange = textView.selectedRange;
    
    NSMutableAttributedString *attributedText = [[NSMutableAttributedString alloc] initWithString:textView.text];
    
    NSRange range = NSMakeRange(0, textView.text.length);
    
    NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:@"@[a-zA-Z0-9-]+" options:0 error:nil];
    NSArray *matches = [regex matchesInString:textView.text options:0 range:range];
    
    [self.taggedRecipients removeAllObjects];
    for (NSTextCheckingResult *match in matches)
    {
        UIColor *highlightColor;
        NSString *tag = [attributedText.string substringWithRange:NSMakeRange(match.range.location+1, match.range.length-1)];
        
        // Check to see if matched tag is a userid.  If it matches and not already in the selected dictionary, add it
        // Also, select highlight color based on validity
        if ([self isValidUserID:tag]) {
            highlightColor = [UIColor blueColor];
            if (![self.taggedRecipients containsObject:tag]) {
                [self.taggedRecipients addObject:tag];
            }
        } else {
            highlightColor = [UIColor redColor];
        }
        
        [attributedText addAttribute:NSForegroundColorAttributeName value:highlightColor range:match.range];
    }
        
    [self updateRecipientsLabel];
    
    // Check to see if new input ends the match and switch color back to black.
    textView.attributedText = attributedText;
    textView.selectedRange = initialSelectedRange;
}

-(void)textViewDidEndEditing:(UITextView *)textView
{
    [super textViewDidEndEditing:textView];
    [self updateRecipientsLabel];
}

-(BOOL)isValidUserID:(NSString *)userid
{
    if ([self.userTags containsObject:userid])
        return YES;
    else
        return NO;
}

// Label used for testing purposes.  Do not include in release or demonstration builds.
-(void)updateBannerLabel
{
    NSMutableString *holdingString = [NSMutableString new];
    
    if ([self.taggedRecipients count] > 0) {
        for (NSString *tag in self.taggedRecipients) {
            [holdingString appendString:tag];
            [holdingString appendString:@" "];
        }
    }
    self.bannerLabel.text = holdingString;
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
    }],
    
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
    dispatch_async(dispatch_get_main_queue(), ^{
        NSIndexPath *bottomPath = [NSIndexPath indexPathForRow:[self.tableView numberOfRowsInSection:0]-1 inSection:0];
        [self.tableView scrollToRowAtIndexPath:bottomPath atScrollPosition:UITableViewScrollPositionBottom animated:YES];
    });

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

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    if ([tableView isEqual:self.tableView]) {
        return (NSInteger)[self.threadMappings numberOfItemsInSection:(NSUInteger)section];
    }
    else {
        return (NSInteger)self.searchResult.count;
    }
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
    if ([tableView isEqual:self.tableView]) {
        return [self messageCellForRowAtIndexPath:indexPath];
    }
    else {
        return [self autoCompletionCellForRowAtIndexPath:indexPath];
    }
}

-(UITableViewCell *)messageCellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    InboxTableViewCell *cell =
    [self.tableView dequeueReusableCellWithIdentifier:NSStringFromClass([InboxTableViewCell class])];
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

-(UITableViewCell *)autoCompletionCellForRowAtIndexPath:indexPath
{
    NSString *cellID = @"Cell";
    UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:cellID];
    
    NSString *text = [self.searchResult objectAtIndex:(NSUInteger)[indexPath row]];
    
    if ([self.foundPrefix isEqualToString:@"#"]) {
        text = [NSString stringWithFormat:@"# %@", text];
    }
    else if (([self.foundPrefix isEqualToString:@":"] || [self.foundPrefix isEqualToString:@"+:"])) {
        text = [NSString stringWithFormat:@":%@:", text];
    }
    
    cell.backgroundColor = [UIColor colorWithRed:215.0/255.0 green:230.0/255.0 blue:245.0/255.0 alpha:1.0];
    cell.textLabel.text = text;
    cell.selectionStyle = UITableViewCellSelectionStyleDefault;
    return cell;

}

-(void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    if ([tableView isEqual:self.autoCompletionView]) {
        
        NSMutableString *item = [[self.searchResult objectAtIndex:(NSUInteger)[indexPath row] ] mutableCopy];
        
        if ([self.foundPrefix isEqualToString:@"@"] && self.foundPrefixRange.location == 0) {
            [item appendString:@""];
        }
        else if (([self.foundPrefix isEqualToString:@":"] || [self.foundPrefix isEqualToString:@"+:"])) {
            [item appendString:@":"];
        }
        
        [item appendString:@" "];
        
        [self acceptAutoCompletionWithString:item keepPrefix:YES];
        [self textViewDidChange:self.textView];
    }
    else
    {
         [self performSegueWithIdentifier:@"threadSelectedSegue" sender:[self.tableView cellForRowAtIndexPath:indexPath]];
        
        [self.tableView deselectRowAtIndexPath:indexPath animated:YES];
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

#pragma mark - UIImagePickerController

/*
 *  Presenting UIImagePickerController
 */

- (void)takePictureOrVideo {
    NSString *mediaType = AVMediaTypeVideo;
    AVAuthorizationStatus authStatus = [AVCaptureDevice authorizationStatusForMediaType:mediaType];
    if(authStatus == AVAuthorizationStatusAuthorized) {
        [self showCamera];
//    } else if(authStatus == AVAuthorizationStatusDenied){
//    } else if(authStatus == AVAuthorizationStatusRestricted){
    } else if(authStatus == AVAuthorizationStatusNotDetermined){
        // not determined?!
        [AVCaptureDevice requestAccessForMediaType:mediaType completionHandler:^(BOOL granted) {
            [self showCamera];
        }];
    } else {
        // impossible, unknown authorization status
        [self noCameraAccess];
    }
}

-(void)showCamera
{
    UIImagePickerController *picker = [[UIImagePickerController alloc] init];
    picker.sourceType = UIImagePickerControllerSourceTypeCamera;
    picker.mediaTypes = @[ (__bridge NSString *)kUTTypeImage, (__bridge NSString *)kUTTypeMovie ];
    picker.allowsEditing = NO;
    picker.delegate = self;
    [self presentViewController:picker animated:YES completion:[UIUtil modalCompletionBlock]];
}

-(void)noCameraAccess
{
    UIAlertController* alert = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"MISSING_CAMERA_PERMISSION_TITLE", @"Alert title")
                                                                   message:NSLocalizedString(@"MISSING_CAMERA_PERMISSION_MESSAGE", @"Alert body")
                                                            preferredStyle:UIAlertControllerStyleAlert];
    
    NSString *settingsTitle = NSLocalizedString(@"OPEN_SETTINGS_BUTTON", @"Button text which opens the settings app");
    UIAlertAction *openSettingsAction = [UIAlertAction actionWithTitle:settingsTitle style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        [[UIApplication sharedApplication] openURL:[NSURL URLWithString:UIApplicationOpenSettingsURLString]];
    }];
    [alert addAction:openSettingsAction];
    
    UIAlertAction *dismissAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"DISMISS_BUTTON_TEXT", nil)
                                                            style:UIAlertActionStyleCancel
                                                          handler:^(UIAlertAction *action) { } ];
    [alert addAction:dismissAction];
    
    [self presentViewController:alert animated:YES completion:nil];
}


- (void)chooseFromLibrary {
    if (![UIImagePickerController isSourceTypeAvailable:UIImagePickerControllerSourceTypePhotoLibrary]) {
        DDLogError(@"PhotoLibrary ImagePicker source not available");
        return;
    }
    
    UIImagePickerController *picker = [[UIImagePickerController alloc] init];
    picker.sourceType = UIImagePickerControllerSourceTypePhotoLibrary;
    picker.delegate = self;
    picker.mediaTypes = @[ (__bridge NSString *)kUTTypeImage, (__bridge NSString *)kUTTypeMovie ];
    [self presentViewController:picker animated:YES completion:[UIUtil modalCompletionBlock]];
}

/*
 *  Dismissing UIImagePickerController
 */

- (void)imagePickerControllerDidCancel:(UIImagePickerController *)picker {
    [UIUtil modalCompletionBlock]();
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)resetFrame {
    // fixes bug on frame being off after this selection
    CGRect frame    = [UIScreen mainScreen].applicationFrame;
    self.view.frame = frame;
}

/*
 *  Fetching data from UIImagePickerController
 */
- (void)imagePickerController:(UIImagePickerController *)picker
didFinishPickingMediaWithInfo:(NSDictionary<NSString *, id> *)info
{
    [UIUtil modalCompletionBlock]();
    [self resetFrame];
    
    void (^failedToPickAttachment)(NSError *error) = ^void(NSError *error) {
        DDLogError(@"failed to pick attachment with error: %@", error);
    };
    
    NSString *mediaType = info[UIImagePickerControllerMediaType];
    if ([mediaType isEqualToString:(__bridge NSString *)kUTTypeMovie]) {
        // Video picked from library or captured with camera
        
        NSURL *videoURL = info[UIImagePickerControllerMediaURL];
        [self sendQualityAdjustedAttachmentForVideo:videoURL];
    } else if (picker.sourceType == UIImagePickerControllerSourceTypeCamera) {
        // Static Image captured from camera
        
        UIImage *imageFromCamera = [info[UIImagePickerControllerOriginalImage] normalizedImage];
        if (imageFromCamera) {
            [self sendMessageAttachment:[self qualityAdjustedAttachmentForImage:imageFromCamera] ofType:@"image/jpeg"];
        } else {
            failedToPickAttachment(nil);
        }
    } else {
        // Non-Video image picked from library
        
        NSURL *assetURL = info[UIImagePickerControllerReferenceURL];
        PHAsset *asset = [[PHAsset fetchAssetsWithALAssetURLs:@[ assetURL ] options:nil] lastObject];
        if (!asset) {
            return failedToPickAttachment(nil);
        }
        
        PHImageRequestOptions *options = [[PHImageRequestOptions alloc] init];
        options.synchronous = YES; // We're only fetching one asset.
        options.networkAccessAllowed = YES; // iCloud OK
        options.deliveryMode = PHImageRequestOptionsDeliveryModeHighQualityFormat; // Don't need quick/dirty version
        [[PHImageManager defaultManager]
         requestImageDataForAsset:asset
         options:options
         resultHandler:^(NSData *_Nullable imageData,
                         NSString *_Nullable dataUTI,
                         UIImageOrientation orientation,
                         NSDictionary *_Nullable assetInfo) {
             
             NSError *assetFetchingError = assetInfo[PHImageErrorKey];
             if (assetFetchingError || !imageData) {
                 return failedToPickAttachment(assetFetchingError);
             }
             DDLogVerbose(
                          @"Size in bytes: %lu; detected filetype: %@", (unsigned long)imageData.length, dataUTI);
             
             if ([dataUTI isEqualToString:(__bridge NSString *)kUTTypeGIF]
                 && imageData.length <= 5 * 1024 * 1024) {
                 DDLogVerbose(@"Sending raw image/gif to retain any animation");
                 /**
                  * Media Size constraints lifted from Signal-Android
                  * (org/thoughtcrime/securesms/mms/PushMediaConstraints.java)
                  *
                  * GifMaxSize return 5 * MB;
                  * For reference, other media size limits we're not explicitly enforcing:
                  * ImageMaxSize return 420 * KB;
                  * VideoMaxSize return 100 * MB;
                  * getAudioMaxSize 100 * MB;
                  */
                 [self sendMessageAttachment:imageData ofType:@"image/gif"];
             } else {
                 DDLogVerbose(@"Compressing attachment as image/jpeg");
                 UIImage *pickedImage = [[UIImage alloc] initWithData:imageData];
                 [self sendMessageAttachment:[self qualityAdjustedAttachmentForImage:pickedImage]
                                      ofType:@"image/jpeg"];
             }
         }];
    }
}

- (void)sendMessageAttachment:(NSData *)attachmentData ofType:(NSString *)attachmentType
{
//    TSOutgoingMessage *message;
//    OWSDisappearingMessagesConfiguration *configuration =
//    [OWSDisappearingMessagesConfiguration fetchObjectWithUniqueID:self.thread.uniqueId];
//    if (configuration.isEnabled) {
//        message = [[TSOutgoingMessage alloc] initWithTimestamp:[NSDate ows_millisecondTimeStamp]
//                                                      inThread:self.thread
//                                                   messageBody:nil
//                                                 attachmentIds:[NSMutableArray new]
//                                              expiresInSeconds:configuration.durationSeconds];
//    } else {
//        message = [[TSOutgoingMessage alloc] initWithTimestamp:[NSDate ows_millisecondTimeStamp]
//                                                      inThread:self.thread
//                                                   messageBody:nil
//                                                 attachmentIds:[NSMutableArray new]];
//    }
//    
//    [self dismissViewControllerAnimated:YES
//                             completion:^{
//                                 DDLogVerbose(@"Sending attachment. Size in bytes: %lu, contentType: %@",
//                                              (unsigned long)attachmentData.length,
//                                              attachmentType);
//                                 [self.messageSender sendAttachmentData:attachmentData
//                                                            contentType:attachmentType
//                                                              inMessage:message
//                                                                success:^{
//                                                                    DDLogDebug(@"%@ Successfully sent message attachment.", self.tag);
//                                                                }
//                                                                failure:^(NSError *error) {
//                                                                    DDLogError(
//                                                                               @"%@ Failed to send message attachment with error: %@", self.tag, error);
//                                                                }];
//                             }];
}

- (NSURL *)videoTempFolder {
    NSArray *paths     = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES);
    NSString *basePath = ([paths count] > 0) ? [paths objectAtIndex:0] : nil;
    basePath           = [basePath stringByAppendingPathComponent:@"videos"];
    if (![[NSFileManager defaultManager] fileExistsAtPath:basePath]) {
        [[NSFileManager defaultManager] createDirectoryAtPath:basePath
                                  withIntermediateDirectories:YES
                                                   attributes:nil
                                                        error:nil];
    }
    return [NSURL fileURLWithPath:basePath];
}

- (void)sendQualityAdjustedAttachmentForVideo:(NSURL *)movieURL {
    AVAsset *video = [AVAsset assetWithURL:movieURL];
    AVAssetExportSession *exportSession =
    [AVAssetExportSession exportSessionWithAsset:video presetName:AVAssetExportPresetMediumQuality];
    exportSession.shouldOptimizeForNetworkUse = YES;
    exportSession.outputFileType              = AVFileTypeMPEG4;
    
    double currentTime     = [[NSDate date] timeIntervalSince1970];
    NSString *strImageName = [NSString stringWithFormat:@"%f", currentTime];
    NSURL *compressedVideoUrl =
    [[self videoTempFolder] URLByAppendingPathComponent:[NSString stringWithFormat:@"%@.mp4", strImageName]];
    
    exportSession.outputURL = compressedVideoUrl;
    [exportSession exportAsynchronouslyWithCompletionHandler:^{
        NSError *error;
        [self sendMessageAttachment:[NSData dataWithContentsOfURL:compressedVideoUrl] ofType:@"video/mp4"];
        [[NSFileManager defaultManager] removeItemAtURL:compressedVideoUrl error:&error];
        if (error) {
            DDLogWarn(@"Failed to remove cached video file: %@", error.debugDescription);
        }
    }];
}

- (NSData *)qualityAdjustedAttachmentForImage:(UIImage *)image {
    return UIImageJPEGRepresentation([self adjustedImageSizedForSending:image], [self compressionRate]);
}

- (UIImage *)adjustedImageSizedForSending:(UIImage *)image {
    CGFloat correctedWidth;
    switch ([Environment.preferences imageUploadQuality]) {
        case TSImageQualityUncropped:
            return image;
            
        case TSImageQualityHigh:
            correctedWidth = 2048;
            break;
        case TSImageQualityMedium:
            correctedWidth = 1024;
            break;
        case TSImageQualityLow:
            correctedWidth = 512;
            break;
        default:
            break;
    }
    
    return [self imageScaled:image toMaxSize:correctedWidth];
}

- (UIImage *)imageScaled:(UIImage *)image toMaxSize:(CGFloat)size {
    CGFloat scaleFactor;
    CGFloat aspectRatio = image.size.height / image.size.width;
    
    if (aspectRatio > 1) {
        scaleFactor = size / image.size.width;
    } else {
        scaleFactor = size / image.size.height;
    }
    
    CGSize newSize = CGSizeMake(image.size.width * scaleFactor, image.size.height * scaleFactor);
    
    UIGraphicsBeginImageContext(newSize);
    [image drawInRect:CGRectMake(0, 0, newSize.width, newSize.height)];
    UIImage *updatedImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    
    return updatedImage;
}

- (CGFloat)compressionRate {
    switch ([Environment.preferences imageUploadQuality]) {
        case TSImageQualityUncropped:
            return 1;
        case TSImageQualityHigh:
            return 0.9f;
        case TSImageQualityMedium:
            return 0.5f;
        case TSImageQualityLow:
            return 0.3f;
        default:
            break;
    }
}



#pragma mark - convenience methods
-(void)updateRecipientsLabel
{
    self.recipientCountButton.title = [NSString stringWithFormat:@"%@: %lu", NSLocalizedString(@"Recipients", @""), (unsigned long)[self.taggedRecipients count]];
}

-(void)selectedUserNotification:(NSNotification *)notification
{
    // Extract the string and insert it
    NSString *aString = [NSString stringWithFormat:@"@%@ ", [notification.userInfo objectForKey:@"tag"]];
    [self insertTextIntoTextInputView:aString];
    
    if (![self.textView isFirstResponder])
        [self.textView becomeFirstResponder];
}

-(void)markAllRead
{
    for (NSInteger row=0; row < [self.tableView numberOfRowsInSection:0]; row++) {
        TSThread *thread = [self threadForIndexPath:[NSIndexPath indexPathForRow:row inSection:0]];
        [thread markAllAsRead];
    }
    DDLogInfo(@"Marked all threads as read.");
}

-(void)insertTextIntoTextInputView:(NSString *)string
{
    NSRange cursorPosition = self.textView.selectedRange;
    
    NSMutableString *textViewText = [self.textView.text mutableCopy];
    [textViewText insertString:string atIndex:cursorPosition.location];
    
    self.textView.text = [NSString stringWithString:textViewText];
    [self textViewDidChange:self.textView];
}

-(void)configureBottomButtons
{
    // Look at using segmentedcontrol to simulate multiple buttons on one side
    [self.leftButton setImage:[UIImage imageNamed:@"Tag_1"] forState:UIControlStateNormal];

    [self.rightButton setTitle:NSLocalizedString(@" ", nil) forState:UIControlStateNormal];
    [self.rightButton setImage:[UIImage imageNamed:@"Send_solid"] forState:UIControlStateNormal];
    [self.rightButton setTintColor:[UIColor colorWithRed:0.0/255.0 green:144.0/255.0 blue:226.0/255.0 alpha:1.0]];
    self.textInputbar.autoHideRightButton = NO;
    
    UIToolbar *bottomBannerView = [UIToolbar new];
    bottomBannerView.translatesAutoresizingMaskIntoConstraints = NO;
    bottomBannerView.backgroundColor = [UIColor clearColor];
    
    UIBarButtonItem *flexSpace = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace
                                                                               target:nil action:nil];
    bottomBannerView.items = @[ /* self.attachmentButton, */ flexSpace, self.recipientCountButton ];
    
    NSDictionary *views = NSDictionaryOfVariableBindings(bottomBannerView);
    
    [self.textInputbar.contentView addSubview:bottomBannerView];
    [self.textInputbar.contentView addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"H:|[bottomBannerView]|" options:0 metrics:nil views:views]];
    [self.textInputbar.contentView addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:|[bottomBannerView(40)]|" options:0 metrics:nil views:views]];

}

-(void)configureNavigationBar
{
    UIBarButtonItem *logoItem = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"Forsta_text_logo"]
                                                                style:UIBarButtonItemStylePlain
                                                               target:self
                                                               action:@selector(onSettingsTap:)];
    logoItem.tag = kLogoButtonTag;

//    UIBarButtonItem *composeItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCompose target:self action:@selector(composeNew:)];

//    UIBarButtonItem *settingsItem = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"settings"]
//                                                                style:UIBarButtonItemStylePlain
//                                                               target:self
//                                                               action:@selector(onSettingsTap:)];
    self.navigationItem.leftBarButtonItem = logoItem;
    self.navigationItem.titleView = self.searchBar;
//    self.navigationItem.rightBarButtonItem = settingsItem;
//    self.navigationItem.rightBarButtonItem = composeItem;
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
-(IBAction)onLogoTap:(id)sender
{
    // Logo icon tapped
}

-(IBAction)onSettingsTap:(UIBarButtonItem *)sender
{
    // Display settings view
    [self performSegueWithIdentifier:@"SettingsPopoverSegue" sender:sender];
}

-(void)didPressLeftButton:(id)sender  // Popup directory in popover
{
    // insert @ into textview
    [self insertTextIntoTextInputView:@"@"];
    
    if (![self.textView isFirstResponder])
        [self.textView becomeFirstResponder];
    
    [super didPressLeftButton:sender];
}

-(void)onLongPressLeftButton:(id)sender
{
    [self performSegueWithIdentifier:@"directoryPopoverSegue" sender:self.leftButton];
}

-(void)didPressRightButton:(id)sender  // This is the send button
{
    if ([self.taggedRecipients count] == 0) {  // No recipients, bail
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"ALERT", @"")
                                                                       message:NSLocalizedString(@"NO_RECIPIENTS_IN_MESSAGE", @"")
                                                                preferredStyle:UIAlertControllerStyleActionSheet];
        UIAlertAction *okButton = [UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleCancel handler:^(UIAlertAction * action) {}];
        [alert addAction:okButton];
        [self presentViewController:alert animated:YES completion:nil];
    } else {
        
        [self didPressSendButton:self.rightButton
                 withMessageText:self.textView.text
                        senderId:self.userId
               senderDisplayName:self.userDispalyName
                            date:[NSDate date]];
        
        [super didPressRightButton:sender];
    }
}

//- (BOOL)canPressRightButton
//{
//    if ([self.taggedRecipients count] > 0 && ![self.textInputbar limitExceeded]) {
//        return YES;
//    }
//    return NO;
//}


-(void)onAttachmentButtonTap:(id)sender
{
    BOOL preserveKeyboard = [self.textInputbar.textView isFirstResponder];
    
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:nil
                                                                   message:nil
                                                            preferredStyle:UIAlertControllerStyleActionSheet];
    UIAlertAction *takePictureButton = [UIAlertAction actionWithTitle:NSLocalizedString(@"TAKE_MEDIA_BUTTON", @"")
                                                                style:UIAlertActionStyleDefault
                                                              handler:^(UIAlertAction *_Nonnull action){ [self takePictureOrVideo];
                                                                  if (preserveKeyboard) {
                                                                      [self.textInputbar.textView becomeFirstResponder];
                                                                  }
                                                              }];
    UIAlertAction *chooseMediaButton = [UIAlertAction actionWithTitle:NSLocalizedString(@"CHOOSE_MEDIA_BUTTON", @"")
                                                                style:UIAlertActionStyleDefault
                                                              handler:^(UIAlertAction *_Nonnull action){ [self chooseFromLibrary];
                                                                  if (preserveKeyboard) {
                                                                      [self.textInputbar.textView becomeFirstResponder];
                                                                  }
                                                              }];
    UIAlertAction *cancelButton = [UIAlertAction actionWithTitle:NSLocalizedString(@"TXT_CANCEL_TITLE", @"")
                                                           style:UIAlertActionStyleCancel
                                                         handler:^(UIAlertAction *_Nonnull action){
                                                             if (preserveKeyboard) {
                                                                 [self.textInputbar.textView becomeFirstResponder];
                                                             }
                                                         }];
    [alert addAction:takePictureButton];
    [alert addAction:chooseMediaButton];
    [alert addAction:cancelButton];
    [self presentViewController:alert animated:YES completion:nil];
}

#pragma mark - UIPopover delegate methods
- (UIModalPresentationStyle)adaptivePresentationStyleForPresentationController:(UIPresentationController *)controller
{
    return UIModalPresentationNone;
}


#pragma mark - Lazy instantiation
-(FLDomainViewController *)domainTableViewController
{
    if (_domainTableViewController == nil) {
        UIStoryboard *storyboard = [UIStoryboard storyboardWithName:@"Main_v2" bundle:[NSBundle mainBundle]];
        _domainTableViewController = [storyboard instantiateViewControllerWithIdentifier:@"domainViewController"];
        _domainTableViewController.hostViewController = self;
        _domainTableViewController.view.frame =  CGRectMake(-self.tableView.frame.size.width * 2/3,
                                                            self.tableView.frame.origin.y,
                                                            self.tableView.frame.size.width * 2/3,
                                                            self.tableView.frame.size.height);
    }
    return _domainTableViewController;
}

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

-(UISearchBar *)searchBar
{
    if (_searchBar == nil) {
        _searchBar = [UISearchBar new];
    }
    return _searchBar;
}

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

-(UILongPressGestureRecognizer *)longPressOnDirButton
{
    if (_longPressOnDirButton == nil) {
        _longPressOnDirButton = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(onLongPressLeftButton:)];
        [self.leftButton addGestureRecognizer:_longPressOnDirButton];
    }
    return _longPressOnDirButton;
}

-(YapDatabaseViewMappings *)threadMappings
{
    if (_threadMappings == nil) {
        _threadMappings =
        [[YapDatabaseViewMappings alloc] initWithGroups:@[ TSInboxGroup ] view:TSThreadDatabaseViewExtensionName];
        [self.threadMappings setIsReversed:NO forGroup:TSInboxGroup];
        
        [self.uiDatabaseConnection asyncReadWithBlock:^(YapDatabaseReadTransaction *transaction) {
            [self.threadMappings updateWithTransaction:transaction];
            dispatch_async(dispatch_get_main_queue(), ^{
                [self.tableView reloadData];
                //            [self checkIfEmptyView];
            });
        }];

    }
        return _threadMappings;
}

-(NSArray *)userTags
{
    if (_userTags == nil) {
        // Pull the tags dictionary, pull the keys, and sort them alphabetically
        _userTags = [[[[CCSMStorage new] getTags] allKeys] sortedArrayUsingSelector:@selector(localizedCaseInsensitiveCompare:)];
    }
    return _userTags;
}


-(NSString *)userId
{
    return [[[Environment getCurrent].ccsmStorage getUserInfo] objectForKey:kUserIDKey];
}

-(NSString *)userDispalyName
{
    return [NSString stringWithFormat:@"%@ %@", [[[Environment getCurrent].ccsmStorage getUserInfo] objectForKey:@"first_name"],[[[Environment getCurrent].ccsmStorage getUserInfo] objectForKey:@"last_name"]];
}

-(NSMutableArray *)taggedRecipients
{
    if (_taggedRecipients ==  nil) {
        _taggedRecipients = [NSMutableArray new];
    }
    return _taggedRecipients;
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

-(UIBarButtonItem *)attachmentButton
{
    if (_attachmentButton == nil) {
        _attachmentButton = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"Attachment_1"]
                                                             style:UIBarButtonItemStylePlain
                                                            target:self
                                                            action:@selector(onAttachmentButtonTap:)];
        _attachmentButton.tintColor = [UIColor blackColor];
    }
    return _attachmentButton;
}

-(UIBarButtonItem *)sendButton
{
    if (_sendButton == nil) {
        _sendButton = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"Send_solid"]
                                                       style:UIBarButtonItemStylePlain
                                                      target:self
                                                      action:@selector(didPressRightButton:)];
        _sendButton.tintColor = [UIColor blueColor];
    }
    return _sendButton;
}

-(UIBarButtonItem *)tagButton
{
    if (_tagButton == nil) {
        _tagButton = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"Tag_1"]
                                                      style:UIBarButtonItemStylePlain
                                                     target:self
                                                     action:@selector(didPressLeftButton:)];
        _tagButton.tintColor = [UIColor blackColor];
    }
    return _tagButton;
}

-(UIBarButtonItem *)recipientCountButton
{
    if (_recipientCountButton == nil) {
        _recipientCountButton = [[UIBarButtonItem alloc] initWithTitle:[NSString stringWithFormat:@"%@: %ld", NSLocalizedString(@"Recipients", @""), [self.taggedRecipients count]]
                                                                 style:UIBarButtonItemStylePlain
                                                                target:nil
                                                                action:nil];
        _recipientCountButton.tintColor = [UIColor darkGrayColor];
    }
    return _recipientCountButton;
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
