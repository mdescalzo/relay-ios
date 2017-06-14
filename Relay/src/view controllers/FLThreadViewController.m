//
//  FLThreadViewController.m
//  Forsta
//
//  Created by Mark on 6/2/17.
//  Copyright © 2017 Forsta. All rights reserved.
//

#import "AppDelegate.h"
#import "CCSMStorage.h"

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
#import "TSDatabaseView.h"
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

#define CELL_HEIGHT 72.0f

NSString *kSelectedThreadIDKey = @"LastSelectedThreadID";
NSString *kUserIDKey = @"phone";
NSString *FLUserSelectedFromDirectory = @"FLUserSelectedFromDirectory";


@interface FLThreadViewController ()

@property (nonatomic, strong) CCSMStorage *ccsmStorage;

@property (strong, nonatomic, readonly) OWSContactsManager *contactsManager;
@property (nonatomic, readonly) TSMessagesManager *messagesManager;
@property (nonatomic, readonly) OWSMessageSender *messageSender;
@property (nonatomic, strong) YapDatabaseViewMappings *threadMappings;
@property (nonatomic, strong) YapDatabaseViewMappings *messageMappings;

@property (nonatomic, strong) YapDatabaseConnection *editingDbConnection;
@property (nonatomic, strong) YapDatabaseConnection *uiDatabaseConnection;
@property NSCache *messageAdapterCache;
@property (nonatomic) CellState viewingThreadsIn;
@property (nonatomic) long inboxCount;
@property (nonatomic, strong) id previewingContext;

// Gesture recognizers
@property (strong, nonatomic) UISwipeGestureRecognizer *rightSwipeRecognizer;
@property (strong, nonatomic) UISwipeGestureRecognizer *leftSwipeRecognizer;
@property (strong, nonatomic) UILongPressGestureRecognizer *longPressOnDirButton;

@property (nonatomic, strong) NSMutableArray *taggedRecipients;
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

//@property (nonatomic, weak) Message *editingMessage;

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

    [self.navigationController.navigationBar setTranslucent:NO];
    
    self.editingDbConnection = TSStorageManager.sharedManager.newDatabaseConnection;
    
    [self.uiDatabaseConnection beginLongLivedReadTransaction];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(yapDatabaseModified:)
                                                 name:TSUIDatabaseConnectionDidUpdateNotification
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
    [self rightSwipeRecognizer];
    [self leftSwipeRecognizer];
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
}

-(void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];

    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(selectedUserNotification:) name:FLUserSelectedFromDirectory object:nil];
}

-(BOOL)textView:(UITextView *)textView shouldChangeTextInRange:(NSRange)range replacementText:(NSString *)text
{
    return [super textView:textView shouldChangeTextInRange:range replacementText:text];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
    if ([[segue identifier] isEqualToString:@"SettingsPopoverSegue"]) {
        [segue destinationViewController].popoverPresentationController.delegate = self;
        [segue destinationViewController].preferredContentSize = CGSizeMake(self.tableView.frame.size.width/2, [self.settingsViewController heightForTableView]);
        [segue destinationViewController].popoverPresentationController.sourceRect = [self frameForSettingsBarButton];
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

-(CGRect)frameForSettingsBarButton
{
    // Workaround for UIBarButtomItem not inheriting from UIView
    NSMutableArray* buttons = [[NSMutableArray alloc] init];
    for (UIControl* btn in self.navigationController.navigationBar.subviews)
        if ([btn isKindOfClass:[UIControl class]])
            [buttons addObject:btn];
    UIView* view = [buttons objectAtIndex:1];
    return [view convertRect:view.bounds toView:nil];
//    return view;
}

-(IBAction)unwindToMessagesView:(UIStoryboardSegue *)sender
{
}

#pragma mark - Lifted from SignalsViewController

// One of the following should be implemented at some later date
- (void)presentThread:(TSThread *)thread keyboardOnViewAppearing:(BOOL)keyboardOnViewAppearing
{
    
}

- (void)configureForThread:(TSThread *)thread keyboardOnViewAppearing:(BOOL)keyboardAppearing
{
    
}


- (NSNumber *)updateInboxCountLabel
{
    return [NSNumber numberWithInt:0];
}

- (void)composeNew
{
    
}

- (void)didPressSendButton:(UIButton *)button
           withMessageText:(NSString *)text
                  senderId:(NSString *)senderId
         senderDisplayName:(NSString *)senderDisplayName
                      date:(NSDate *)date
{
        // Check the tagged user list.
    switch ([self.taggedRecipients count]) {
        case 0:       //  Empty, alert and bail
        {
            UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Alert" message:@"Please @tag recipients." delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
            [alert show];
        }
            break;
        case 1:      // Single recipient, converstaion thread
        {
            
        }
            break;
        default:   //   Multiple recipients, group thread
        {
            UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Alert" message:@"Multiple recipient support is current under development.  Using only the first @tagged recipient." delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
            [alert show];

        }
            break;
    }
    
    // Build the message parts
#warning Kick this out into a convenience method
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
                                                 attachmentIds:[NSMutableArray new]
                                              expiresInSeconds:configuration.durationSeconds];
    } else {
        message = [[TSOutgoingMessage alloc] initWithTimestamp:[NSDate ows_millisecondTimeStamp]
                                                      inThread:thread
                                                   messageBody:text];
    }
    
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
    //        [self finishSendingMessage];
}


#pragma mark - swipe handlers
-(IBAction)onSwipeToTheRight:(id)sender
{
    if (self.domainTableViewController.view.hidden) {
        if ([self.textView isFirstResponder])
            [self.textView resignFirstResponder];
        [self showDomainTableView];
    }
}

-(IBAction)onSwipeToTheLeft:(id)sender
{
    if (!self.domainTableViewController.view.hidden) {
        [self hideDomainTableView];
    }
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
    
    [self updateBannerLabel];
    
    // Check to see if new input ends the match and switch color back to black.
    textView.attributedText = attributedText;
    textView.selectedRange = initialSelectedRange;
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


#pragma mark - convenience methods
-(void)selectedUserNotification:(NSNotification *)notification
{
    // Extract the string and insert it
    NSString *aString = [NSString stringWithFormat:@"@%@ ", [notification.userInfo objectForKey:@"tag"]];
    [self insertTextIntoTextInputView:aString];
    
    if (![self.textView isFirstResponder])
        [self.textView becomeFirstResponder];
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

    [self.rightButton setTitle:NSLocalizedString(@"Send", nil) forState:UIControlStateNormal];
    self.textInputbar.autoHideRightButton = NO;

}

-(void)configureNavigationBar
{
    UIBarButtonItem *logoItem = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"forsta_logo_blk"]
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
    [self didPressSendButton:self.rightButton
             withMessageText:self.textView.text
                    senderId:self.userId
           senderDisplayName:self.userDispalyName
                        date:[NSDate date]];

    [super didPressRightButton:sender];
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

-(UISwipeGestureRecognizer *)rightSwipeRecognizer
{
    if (_rightSwipeRecognizer == nil) {
        _rightSwipeRecognizer = [[UISwipeGestureRecognizer alloc] initWithTarget:self action:@selector(onSwipeToTheRight:)];
        _rightSwipeRecognizer.direction = UISwipeGestureRecognizerDirectionRight;
        [self.tableView addGestureRecognizer:_rightSwipeRecognizer];
    }
    return _rightSwipeRecognizer;
}

-(UISwipeGestureRecognizer *)leftSwipeRecognizer
{
    if (_leftSwipeRecognizer == nil) {
        _leftSwipeRecognizer = [[UISwipeGestureRecognizer alloc] initWithTarget:self action:@selector(onSwipeToTheLeft:)];
        _leftSwipeRecognizer.direction = UISwipeGestureRecognizerDirectionLeft;
        [self.tableView addGestureRecognizer:_leftSwipeRecognizer];
    }
    return _leftSwipeRecognizer;
}

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
        [self.threadMappings setIsReversed:YES forGroup:TSInboxGroup];
        
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
    return [[Environment.ccsmStorage getUserInfo] objectForKey:kUserIDKey];
}

-(NSString *)userDispalyName
{
    return [NSString stringWithFormat:@"%@ %@", [[Environment.ccsmStorage getUserInfo] objectForKey:@"first_name"],[[Environment.ccsmStorage getUserInfo] objectForKey:@"last_name"]];
}

-(NSMutableArray *)taggedRecipients
{
    if (_taggedRecipients ==  nil) {
        _taggedRecipients = [NSMutableArray new];
    }
    return _taggedRecipients;
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
