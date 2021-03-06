//
//  MessagesViewController.m
//  Signal
//
//  Created by Dylan Bourgeois on 28/10/14.
//  Copyright (c) 2014 Open Whisper Systems. All rights reserved.
//

#import "AppDelegate.h"

#import "Relay-Swift.h"
#import "Environment.h"
#import "FingerprintViewController.h"
#import "FullImageViewController.h"
#import "MessagesViewController.h"
#import "NSDate+millisecondTimeStamp.h"
#import "ConversationUpdateViewController.h"
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
#import "SignalKeyingStorage.h"
#import "TSAttachmentPointer.h"
#import "TSContentAdapters.h"
#import "TSDatabaseView.h"
#import "TSErrorMessage.h"
#import "TSThread.h"
#import "TSIncomingMessage.h"
#import "TSInfoMessage.h"
#import "TSInvalidIdentityKeyErrorMessage.h"
#import "UIFont+OWS.h"
#import "UIUtil.h"
#import "UIViewController+CameraPermissions.h"
#import <ContactsUI/CNContactViewController.h>
#import <JSQMessagesViewController/JSQMessagesBubbleImage.h>
#import <JSQMessagesViewController/JSQMessagesBubbleImageFactory.h>
#import <JSQMessagesViewController/JSQMessagesCollectionViewFlowLayoutInvalidationContext.h>
#import <JSQMessagesViewController/JSQMessagesTimestampFormatter.h>
#import <JSQMessagesViewController/JSQSystemSoundPlayer+JSQMessages.h>
#import <JSQMessagesViewController/UIColor+JSQMessages.h>
#import <JSQSystemSoundPlayer/JSQSystemSoundPlayer.h>
#import <MobileCoreServices/UTCoreTypes.h>
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
#import <YapDatabase/YapDatabaseView.h>
#import "ImagePreviewViewController.h"


@import Photos;

#define kYapDatabaseRangeLength 50
#define kYapDatabaseRangeMaxLength 300
#define kYapDatabaseRangeMinLength 20
#define JSQ_TOOLBAR_ICON_HEIGHT 22
#define JSQ_TOOLBAR_ICON_WIDTH 22
#define JSQ_IMAGE_INSET 5

static NSTimeInterval const kTSMessageSentDateShowTimeInterval = 5 * 60;
static NSString *const OWSMessagesViewControllerSegueShowFingerprint = @"fingerprintSegue";
static NSString *const OWSMessagesViewControllerSeguePushConversationSettings =
    @"OWSMessagesViewControllerSeguePushConversationSettings";
NSString *const OWSMessagesViewControllerDidAppearNotification = @"OWSMessagesViewControllerDidAppear";

typedef enum : NSUInteger {
    kMediaTypePicture,
    kMediaTypeVideo,
} kMediaTypes;

@interface MessagesViewController() <ImagePreviewViewControllerDelegate, UIDocumentPickerDelegate>
{
    UIImage *tappedImage;
    BOOL isGroupConversation;

    UIView *_unreadContainer;
    UIImageView *_unreadBackground;
    UILabel *_unreadLabel;
    NSUInteger _unreadCount;
}

@property (nonatomic, strong) PropertyListPreferences *prefs;
@property TSThread *thread;
@property TSMessageAdapter *lastDeliveredMessage;
@property (nonatomic, strong) YapDatabaseConnection *editingDatabaseConnection;
@property (nonatomic, strong) YapDatabaseConnection *uiDatabaseConnection;
@property (nonatomic, strong) YapDatabaseViewMappings *messageMappings;

@property (nonatomic, strong) JSQMessagesBubbleImage *outgoingBubbleImageData;
@property (nonatomic, strong) JSQMessagesBubbleImage *incomingBubbleImageData;
@property (nonatomic, strong) JSQMessagesBubbleImage *currentlyOutgoingBubbleImageData;
@property (nonatomic, strong) JSQMessagesBubbleImage *outgoingMessageFailedImageData;

@property (nonatomic, strong) NSTimer *audioPlayerPoller;
@property (nonatomic, strong) TSVideoAttachmentAdapter *currentMediaAdapter;

@property (nonatomic, strong) NSTimer *readTimer;
//@property (nonatomic, strong) UILabel *navbarTitleLabel;
@property (nonatomic, strong) UIButton *attachButton;

@property (nonatomic) CGFloat previousCollectionViewFrameWidth;

@property NSUInteger page;
@property (nonatomic) BOOL composeOnOpen;
@property (nonatomic) BOOL peek;

@property (nonatomic, readonly) FLContactsManager *contactsManager;
@property (nonatomic, readonly) FLMessageSender *messageSender;
@property (nonatomic, readonly) TSStorageManager *storageManager;
@property (nonatomic, readonly) OWSDisappearingMessagesJob *disappearingMessagesJob;
@property (nonatomic, readonly) TSMessagesManager *messagesManager;
@property (nonatomic, readonly) TSNetworkManager *networkManager;

@property (nonatomic, strong) UIImage *imageToPreview;
@property (nonatomic, strong) NSString *filenameToPreview;

@property (nonatomic, strong) UIButton *infoButton;

@property NSCache *messageAdapterCache;

@end

@implementation MessagesViewController

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (instancetype)init
{
    self = [super init];
    if (!self) {
        return self;
    }

    [self commonInit];

    return self;
}

- (instancetype)initWithCoder:(NSCoder *)aDecoder
{
    self = [super initWithCoder:aDecoder];
    if (!self) {
        return self;
    }

    [self commonInit];

    return self;
}

- (void)commonInit
{
    _contactsManager = [Environment getCurrent].contactsManager;
    _messageSender = [Environment getCurrent].messageSender;
    _storageManager = [TSStorageManager sharedManager];
    _disappearingMessagesJob = [[OWSDisappearingMessagesJob alloc] initWithStorageManager:_storageManager];
    _messagesManager = [TSMessagesManager sharedManager];
    _networkManager = [TSNetworkManager sharedManager];
}

- (void)peekSetup {
    _peek = YES;
    [self setComposeOnOpen:NO];
}

- (void)popped {
    _peek = NO;
    [self hideInputIfNeeded];
}

- (void)configureForThread:(TSThread *)thread keyboardOnViewAppearing:(BOOL)keyboardAppearing {
    _thread                        = thread;
    isGroupConversation = YES;
    _composeOnOpen                 = keyboardAppearing;

    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{
        [self markAllMessagesAsRead];
    });

    [self.uiDatabaseConnection beginLongLivedReadTransaction];
    self.messageMappings =
        [[YapDatabaseViewMappings alloc] initWithGroups:@[ thread.uniqueId ] view:TSMessageDatabaseViewExtensionName];
    [self.uiDatabaseConnection readWithBlock:^(YapDatabaseReadTransaction *transaction) {
      [self.messageMappings updateWithTransaction:transaction];
      self.page = 0;
      [self updateRangeOptionsForPage:self.page];
      [self.collectionView reloadData];
    }];
    [self updateLoadEarlierVisible];
}

- (BOOL)userLeftGroup
{
    return ![self.thread.participants containsObject:TSAccountManager.sharedInstance.myself.uniqueId];
}

- (void)hideInputIfNeeded {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (self.peek) {
            self.inputToolbar.hidden = YES;
            [self.inputToolbar endEditing:TRUE];
            return;
        }
        
        if ([self userLeftGroup]) {
            self.inputToolbar.hidden = YES; // user has requested they leave the group. further sends disallowed
            [self.inputToolbar endEditing:TRUE];
        } else {
            self.inputToolbar.hidden = NO;
            [self loadDraftInCompose];
        }
    });
}

-(void)disableInfoButtonIfNeeded
{
    dispatch_async(dispatch_get_main_queue(), ^{
        if ([self userLeftGroup]) {
            self.infoButton.enabled = NO;
        } else {
            self.infoButton.enabled = YES;
        }
    });
}

- (void)viewDidLoad
{
    [super viewDidLoad];

    DDLogDebug(@"Loading MessagesViewController.");
    [self.navigationController.navigationBar setTranslucent:NO];

    self.messageAdapterCache = [[NSCache alloc] init];

    _attachButton = [[UIButton alloc] init];
    [_attachButton setFrame:CGRectMake(0,
                                       0,
                                       JSQ_TOOLBAR_ICON_WIDTH + JSQ_IMAGE_INSET * 2,
                                       JSQ_TOOLBAR_ICON_HEIGHT + JSQ_IMAGE_INSET * 2)];
    _attachButton.imageEdgeInsets =
        UIEdgeInsetsMake(JSQ_IMAGE_INSET, JSQ_IMAGE_INSET, JSQ_IMAGE_INSET, JSQ_IMAGE_INSET);
    [_attachButton setImage:[UIImage imageNamed:@"btnAttachments--blue"] forState:UIControlStateNormal];

    [self initializeTextView];

    [JSQMessagesCollectionViewCell registerMenuAction:@selector(delete:)];
    SEL saveSelector = NSSelectorFromString(@"save:");
    [JSQMessagesCollectionViewCell registerMenuAction:saveSelector];
    [UIMenuController sharedMenuController].menuItems = @[ [[UIMenuItem alloc] initWithTitle:NSLocalizedString(@"EDIT_ITEM_SAVE_ACTION", @"Short name for edit menu item to save contents of media message.")
                                                                                      action:saveSelector] ];

    [self initializeCollectionViewLayout];
    [self registerCustomMessageNibs];

    self.senderId          = ME_MESSAGE_IDENTIFIER;
    self.senderDisplayName = ME_MESSAGE_IDENTIFIER;

    [self initializeToolbars];
}

- (void)viewDidLayoutSubviews
{
    [super viewDidLayoutSubviews];

    // JSQMVC width is initially 375px on iphone6/ios9 (as specified by the xib), which causes
    // our initial bubble calculations to be off since they happen before the containing
    // view is layed out. https://github.com/jessesquires/JSQMessagesViewController/issues/1257
    if (CGRectGetWidth(self.collectionView.frame) != self.previousCollectionViewFrameWidth) {
        // save frame value from next comparison
        self.previousCollectionViewFrameWidth = CGRectGetWidth(self.collectionView.frame);

        // invalidate layout
        [self.collectionView.collectionViewLayout
            invalidateLayoutWithContext:[JSQMessagesCollectionViewFlowLayoutInvalidationContext context]];
    }
}

- (void)registerCustomMessageNibs
{
    [self.collectionView registerNib:[OWSCallCollectionViewCell nib]
          forCellWithReuseIdentifier:[OWSCallCollectionViewCell cellReuseIdentifier]];

    [self.collectionView registerNib:[OWSDisplayedMessageCollectionViewCell nib]
          forCellWithReuseIdentifier:[OWSDisplayedMessageCollectionViewCell cellReuseIdentifier]];

    self.outgoingCellIdentifier = [OWSOutgoingMessageCollectionViewCell cellReuseIdentifier];
    [self.collectionView registerNib:[OWSOutgoingMessageCollectionViewCell nib]
          forCellWithReuseIdentifier:[OWSOutgoingMessageCollectionViewCell cellReuseIdentifier]];

    self.outgoingMediaCellIdentifier = [OWSOutgoingMessageCollectionViewCell mediaCellReuseIdentifier];
    [self.collectionView registerNib:[OWSOutgoingMessageCollectionViewCell nib]
          forCellWithReuseIdentifier:[OWSOutgoingMessageCollectionViewCell mediaCellReuseIdentifier]];

    self.incomingCellIdentifier = [OWSIncomingMessageCollectionViewCell cellReuseIdentifier];
    [self.collectionView registerNib:[OWSIncomingMessageCollectionViewCell nib]
          forCellWithReuseIdentifier:[OWSIncomingMessageCollectionViewCell cellReuseIdentifier]];

    self.incomingMediaCellIdentifier = [OWSIncomingMessageCollectionViewCell mediaCellReuseIdentifier];
    [self.collectionView registerNib:[OWSIncomingMessageCollectionViewCell nib]
          forCellWithReuseIdentifier:[OWSIncomingMessageCollectionViewCell mediaCellReuseIdentifier]];
}

- (void)toggleObservers:(BOOL)shouldObserve
{
    if (shouldObserve) {
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(yapDatabaseModified:)
                                                     name:YapDatabaseModifiedNotification
                                                   object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(startReadTimer)
                                                     name:UIApplicationWillEnterForegroundNotification
                                                   object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(startExpirationTimerAnimations)
                                                     name:UIApplicationWillEnterForegroundNotification
                                                   object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(cancelReadTimer)
                                                     name:UIApplicationDidEnterBackgroundNotification
                                                   object:nil];
    } else {
        [[NSNotificationCenter defaultCenter] removeObserver:self
                                                     name:YapDatabaseModifiedNotification
                                                   object:nil];
        [[NSNotificationCenter defaultCenter] removeObserver:self
                                                     name:UIApplicationWillEnterForegroundNotification
                                                   object:nil];
        [[NSNotificationCenter defaultCenter] removeObserver:self
                                                     name:UIApplicationDidEnterBackgroundNotification
                                                   object:nil];
    }
}

- (void)initializeTextView {
    [self.inputToolbar.contentView.textView setFont:[UIFont ows_dynamicTypeBodyFont]];

    self.inputToolbar.contentView.leftBarButtonItem = self.attachButton;
    [self.inputToolbar setBackgroundImage:[UIImage new] forToolbarPosition:UIBarPositionAny barMetrics:UIBarMetricsDefault];
    self.inputToolbar.backgroundColor = [ForstaColors lightGray];
    
    self.inputToolbar.contentView.textView.font = [UIFont ows_regularFontWithSize:17.0f];

    UILabel *sendLabel = self.inputToolbar.contentView.rightBarButtonItem.titleLabel;
    // override superclass translations since we support more translations than upstream.
    sendLabel.text = NSLocalizedString(@"SEND_BUTTON_TITLE", nil);
    sendLabel.font = [UIFont ows_regularFontWithSize:17.0f];
    sendLabel.textColor = [UIColor ows_materialBlueColor];
    sendLabel.textAlignment = NSTextAlignmentCenter;

}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    [self.uiDatabaseConnection beginLongLivedReadTransaction];
    [self.uiDatabaseConnection readWithBlock:^(YapDatabaseReadTransaction * _Nonnull transaction) {
        [self.messageMappings updateWithTransaction:transaction];
    }];

    [UIUtil applyForstaAppearence];

    // We need to recheck on every appearance, since the user may have left the group in the settings VC,
    // or on another device.
    [self hideInputIfNeeded];
    [self disableInfoButtonIfNeeded];

    [self toggleObservers:YES];

    // Triggering modified notification renders "call notification" when leaving full screen call view
    [self.editingDatabaseConnection asyncReadWriteWithBlock:^(YapDatabaseReadWriteTransaction * _Nonnull transaction) {
        [self.thread touchWithTransaction:transaction];
    }];

    // restart any animations that were stopped e.g. while inspecting the contact info screens.
    [self startExpirationTimerAnimations];

    OWSDisappearingMessagesConfiguration *configuration =
        [OWSDisappearingMessagesConfiguration fetchObjectWithUniqueID:self.thread.uniqueId];
    [self setBarButtonItemsForDisappearingMessagesConfiguration:configuration];
    [self setNavigationTitle];

    NSInteger numberOfMessages = (NSInteger)[self.messageMappings numberOfItemsInGroup:self.thread.uniqueId];
    if (numberOfMessages > 0) {
        NSIndexPath *lastCellIndexPath = [NSIndexPath indexPathForRow:numberOfMessages - 1 inSection:0];
        [self.collectionView scrollToItemAtIndexPath:lastCellIndexPath
                                    atScrollPosition:UICollectionViewScrollPositionBottom
                                            animated:NO];
    }
}

- (void)startReadTimer {
    self.readTimer = [NSTimer scheduledTimerWithTimeInterval:1
                                                      target:self
                                                    selector:@selector(markAllMessagesAsRead)
                                                    userInfo:nil
                                                     repeats:YES];
}

- (void)cancelReadTimer {
    [self.readTimer invalidate];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    [self dismissKeyBoard];
    [self startReadTimer];

    // TODO prep this sync one time before view loads so we don't have to repaint.
    [self updateBackButtonAsync];

    [self.inputToolbar.contentView.textView endEditing:YES];

    self.inputToolbar.contentView.textView.editable = YES;
    if (_composeOnOpen && !self.inputToolbar.hidden) {
        [self popKeyBoard];
    }
}

- (void)updateBackButtonAsync {
    NSUInteger count = [self.messagesManager unreadMessagesCountExcept:self.thread];
    if (self) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self setUnreadCount:count];
        });
    }
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    [self toggleObservers:NO];

    [_unreadContainer removeFromSuperview];
    self->_unreadContainer = nil;

    [_audioPlayerPoller invalidate];
    [_audioPlayer stop];

    // reset all audio bars to 0
    JSQMessagesCollectionView *collectionView = self.collectionView;
    NSInteger num_bubbles                     = [self collectionView:collectionView numberOfItemsInSection:0];
    for (NSInteger i = 0; i < num_bubbles; i++) {
        NSIndexPath *indexPath = [NSIndexPath indexPathForRow:i inSection:0];
        id<OWSMessageData> message = [self messageAtIndexPath:indexPath];
        if (message.messageType == TSIncomingMessageAdapter && message.isMediaMessage &&
            [message isKindOfClass:[TSVideoAttachmentAdapter class]]) {
            TSVideoAttachmentAdapter *msgMedia = (TSVideoAttachmentAdapter *)message.media;
            if ([msgMedia isAudio]) {
                msgMedia.isPaused       = NO;
                msgMedia.isAudioPlaying = NO;
                [msgMedia setAudioProgressFromFloat:0];
                [msgMedia setAudioIconToPlay];
            }
        }
    }

    [self cancelReadTimer];
    [self saveDraft];
}

- (void)startExpirationTimerAnimations
{
    [[NSNotificationCenter defaultCenter] postNotificationName:OWSMessagesViewControllerDidAppearNotification
                                                        object:nil];
}

- (void)viewDidDisappear:(BOOL)animated {
    [self.uiDatabaseConnection endLongLivedReadTransaction];
    self.inputToolbar.contentView.textView.editable = NO;

    [super viewDidDisappear:animated];
}

#pragma mark - Initiliazers

- (void)setNavigationTitle
{
    dispatch_async(dispatch_get_main_queue(), ^{
        NSString *navTitle = self.thread.displayName;
        self.title = navTitle;
    });
}

- (void)setBarButtonItemsForDisappearingMessagesConfiguration:
    (OWSDisappearingMessagesConfiguration *)disappearingMessagesConfiguration

{
    NSMutableArray<UIBarButtonItem *> *barButtons = [NSMutableArray new];
    
    // Info button to push converstaion settings view.
    UIBarButtonItem *infoItem = [[UIBarButtonItem alloc] initWithCustomView:self.infoButton];
    [barButtons addObject:infoItem];

    // Call button will display if phone # is available
    if ([self canCall]) {
        UIBarButtonItem *callButton = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"btnPhone--white"]
                                                                       style:UIBarButtonItemStylePlain
                                                                      target:self
                                                                      action:@selector(callAction)];
//        callButton.imageInsets = UIEdgeInsetsMake(0, -10, 0, 10);
        [barButtons addObject:callButton];
    }
    
    self.navigationItem.rightBarButtonItems = [NSArray arrayWithArray:barButtons];
}

- (void)initializeToolbars
{
    // HACK JSQMessagesViewController doesn't yet support dynamic type in the inputToolbar.
    // See: https://github.com/jessesquires/JSQMessagesViewController/pull/1169/files
    [self.inputToolbar.contentView.textView sizeToFit];
    self.inputToolbar.preferredDefaultHeight = self.inputToolbar.contentView.textView.frame.size.height + 16;

    // prevent draft from obscuring message history in case user wants to scroll back to refer to something
    // while composing a long message.
    self.inputToolbar.maximumHeight = 300;
}

// Overiding JSQMVC layout defaults
- (void)initializeCollectionViewLayout
{
    [self.collectionView.collectionViewLayout setMessageBubbleFont:[UIFont ows_regularFontWithSize:FLMessageViewFontSize]];

    self.collectionView.showsVerticalScrollIndicator = NO;
    self.collectionView.showsHorizontalScrollIndicator = NO;

    [self updateLoadEarlierVisible];

    self.collectionView.collectionViewLayout.incomingAvatarViewSize = CGSizeZero;
    self.collectionView.collectionViewLayout.outgoingAvatarViewSize = CGSizeZero;

    if ([UIDevice currentDevice].userInterfaceIdiom != UIUserInterfaceIdiomPad) {
        // Narrow the bubbles a bit to create more white space in the messages view
        // Since we're not using avatars it gets a bit crowded otherwise.
        self.collectionView.collectionViewLayout.messageBubbleLeftRightMargin = 80.0f;
    }

    // Bubbles
    UIColor *outgoingBubbleColor = [[ForstaColors outgoingBubbleColors] objectForKey:self.prefs.outgoingBubbleColorKey];
    if (outgoingBubbleColor == nil) {
        outgoingBubbleColor = [ForstaColors lightGray];
    }
    UIColor *incomingBubbleColor = [[ForstaColors incomingBubbleColors] objectForKey:self.prefs.incomingBubbleColorKey];
    if (incomingBubbleColor == nil) {
        incomingBubbleColor = [ForstaColors blackColor];
    }

    self.collectionView.collectionViewLayout.bubbleSizeCalculator = [[OWSMessagesBubblesSizeCalculator alloc] init];
    JSQMessagesBubbleImageFactory *bubbleFactory = [[JSQMessagesBubbleImageFactory alloc] init];
    self.incomingBubbleImageData = [bubbleFactory incomingMessagesBubbleImageWithColor:incomingBubbleColor];
    self.outgoingBubbleImageData = [bubbleFactory outgoingMessagesBubbleImageWithColor:outgoingBubbleColor];
    self.currentlyOutgoingBubbleImageData = [bubbleFactory outgoingMessagesBubbleImageWithColor:outgoingBubbleColor];
    self.outgoingMessageFailedImageData = [bubbleFactory outgoingMessagesBubbleImageWithColor:[UIColor grayColor]];

}

#pragma mark - Fingerprints

- (void)showFingerprintWithTheirIdentityKey:(NSData *)theirIdentityKey theirSignalId:(NSString *)theirSignalId
{
    OWSFingerprintBuilder *builder =
        [[OWSFingerprintBuilder alloc] initWithStorageManager:self.storageManager contactsManager:self.contactsManager];
    NSString *otherId = nil;
    for (NSString *uid in self.thread.participants) {
        if (![uid isEqualToString:TSAccountManager.sharedInstance.myself.uniqueId]) {
            otherId = uid;
            break;
        }
    }
    OWSFingerprint *fingerprint =
        [builder fingerprintWithTheirSignalId:otherId theirIdentityKey:theirIdentityKey];
    [self markAllMessagesAsRead];
    [self performSegueWithIdentifier:OWSMessagesViewControllerSegueShowFingerprint sender:fingerprint];
}

#pragma mark - Calls

//- (SignalRecipient *)signalRecipient {
//    __block SignalRecipient *recipient;
//    [self.editingDatabaseConnection readWithBlock:^(YapDatabaseReadTransaction *transaction) {
//      recipient = [SignalRecipient recipientWithTextSecureIdentifier:[self phoneNumberForThread].toE164
//                                                     withTransaction:transaction];
//    }];
//    return recipient;
//}
//
//- (BOOL)isTextSecureReachable {
//    return isGroupConversation || [self signalRecipient];
//}

- (PhoneNumber *)phoneNumberForThread {
    NSString *userid = nil;
    for (NSString *uid in self.thread.participants) {
        if (![uid isEqualToString:[TSAccountManager localNumber]]) {
            userid = uid;
        }
    }
    SignalRecipient *recipient = [Environment.getCurrent.contactsManager recipientWithUserId:userid];
    return [PhoneNumber phoneNumberFromUserSpecifiedText:recipient.phoneNumber];
}

- (void)callAction {
    if ([self canCall]) {
        PhoneNumber *number = [self phoneNumberForThread];
        NSString *phoneStr = [[NSString alloc] initWithFormat:@"tel://%@",number];
        // Prepare the NSURL
        NSURL *phoneURL = [[NSURL alloc] initWithString:phoneStr];
        // Make the call
        [[UIApplication sharedApplication] openURL:phoneURL];
    } else {
        DDLogWarn(@"Tried to initiate a call but thread is not callable.");
    }
}

- (BOOL)canCall
{
    if (self.thread.participants.count > 2) {
        return NO;
    } else {
        NSString *userid = nil;
        for (NSString *uid in self.thread.participants) {
            if (![uid isEqualToString:[TSAccountManager localNumber]]) {
                userid = uid;
            }
        }
        SignalRecipient *recipient = [Environment.getCurrent.contactsManager recipientWithUserId:userid];
        if (recipient.phoneNumber) {
            return YES;
        } else {
            return NO;
        }
    }
}

#pragma mark - JSQMessagesViewController method overrides

- (void)didPressSendButton:(UIButton *)button
           withMessageText:(NSString *)text
                  senderId:(NSString *)senderId
         senderDisplayName:(NSString *)senderDisplayName
                      date:(NSDate *)date
{
    button.enabled = NO;
    if (text.length > 0) {
        TSOutgoingMessage *message = nil;
        OWSDisappearingMessagesConfiguration *configuration =
            [OWSDisappearingMessagesConfiguration fetchObjectWithUniqueID:self.thread.uniqueId];
        if (configuration.isEnabled) {
            message = [[TSOutgoingMessage alloc] initWithTimestamp:[NSDate ows_millisecondTimeStamp]
                                                          inThread:self.thread
                                                       messageBody:@""
                                                     attachmentIds:[NSMutableArray new]
                                                  expiresInSeconds:configuration.durationSeconds];
        } else {
            message = [[TSOutgoingMessage alloc] initWithTimestamp:[NSDate ows_millisecondTimeStamp]
                                                          inThread:self.thread
                                                       messageBody:@""];
        }
        message.plainTextBody = text;
        message.messageType = @"content";
        message.uniqueId = [[NSUUID UUID] UUIDString];

        [self.editingDatabaseConnection readWriteWithBlock:^(YapDatabaseReadWriteTransaction *transaction) {
            [message saveWithTransaction:transaction];
            [self.thread setDraft:@"" transaction:transaction];
        }];
        
        [self.messageSender sendMessage:message
            success:^{
                DDLogInfo(@"%@ Successfully sent message.", self.tag);
                if ([Environment.preferences soundInForeground]) {
                    [JSQSystemSoundPlayer jsq_playMessageSentSound];
                }
            }
            failure:^(NSError *error) {
                DDLogWarn(@"%@ Failed to deliver message with error: %@", self.tag, error);
            }];
        [self finishSendingMessage];
    }
}

#pragma mark - UICollectionViewDelegate

// Override JSQMVC
- (BOOL)collectionView:(JSQMessagesCollectionView *)collectionView shouldShowMenuForItemAtIndexPath:(NSIndexPath *)indexPath
{
    if (indexPath == nil) {
        DDLogError(@"Aborting shouldShowMenuForItemAtIndexPath because indexPath is nil");
        // Not sure why this is nil, but occasionally it is, which crashes.
        return NO;
    }

    // JSQM does some setup in super method
    [super collectionView:collectionView shouldShowMenuForItemAtIndexPath:indexPath];

    // Super method returns false for media methods. We want menu for *all* items
    return YES;
}

- (void)collectionView:(UICollectionView *)collectionView
    didEndDisplayingCell:(nonnull UICollectionViewCell *)cell
      forItemAtIndexPath:(nonnull NSIndexPath *)indexPath
{
    if ([cell conformsToProtocol:@protocol(OWSExpirableMessageView)]) {
        id<OWSExpirableMessageView> expirableView = (id<OWSExpirableMessageView>)cell;
        [expirableView stopExpirationTimer];
    }
}

#pragma mark - JSQMessages CollectionView DataSource

- (id<OWSMessageData>)collectionView:(JSQMessagesCollectionView *)collectionView
       messageDataForItemAtIndexPath:(NSIndexPath *)indexPath
{
    return [self messageAtIndexPath:indexPath];
}

- (id<JSQMessageBubbleImageDataSource>)collectionView:(JSQMessagesCollectionView *)collectionView
             messageBubbleImageDataForItemAtIndexPath:(NSIndexPath *)indexPath
{
    TSInteraction *message = [self interactionAtIndexPath:indexPath];

    if ([message isKindOfClass:[TSOutgoingMessage class]]) {
        TSOutgoingMessage *outgoingMessage = (TSOutgoingMessage *)message;
        switch (outgoingMessage.messageState) {
            case TSOutgoingMessageStateUnsent:
                return self.outgoingMessageFailedImageData;
            case TSOutgoingMessageStateAttemptingOut:
                return self.currentlyOutgoingBubbleImageData;
            default:
                return self.outgoingBubbleImageData;
        }
    }

    return self.incomingBubbleImageData;
}

- (id<JSQMessageAvatarImageDataSource>)collectionView:(JSQMessagesCollectionView *)collectionView
                    avatarImageDataForItemAtIndexPath:(NSIndexPath *)indexPath {
    return nil;
}

#pragma mark - UICollectionView DataSource

- (UICollectionViewCell *)collectionView:(JSQMessagesCollectionView *)collectionView
                  cellForItemAtIndexPath:(NSIndexPath *)indexPath
{
    id<OWSMessageData> message = [self messageAtIndexPath:indexPath];
    NSParameterAssert(message != nil);

    JSQMessagesCollectionViewCell *cell;
    switch (message.messageType) {
        case TSCallAdapter: {
            OWSCall *call = (OWSCall *)message;
            cell = [self loadCallCellForCall:call atIndexPath:indexPath];
        } break;
        case TSInfoMessageAdapter: {
            cell = [self loadInfoMessageCellForMessage:(TSMessageAdapter *)message atIndexPath:indexPath];
        } break;
        case TSErrorMessageAdapter: {
            cell = [self loadErrorMessageCellForMessage:(TSMessageAdapter *)message atIndexPath:indexPath];
        } break;
        case TSIncomingMessageAdapter: {
            cell = [self loadIncomingMessageCellForMessage:message atIndexPath:indexPath];
        } break;
        case TSOutgoingMessageAdapter: {
            cell = [self loadOutgoingCellForMessage:message atIndexPath:indexPath];
        } break;
        default: {
            DDLogWarn(@"using default cell constructor for message: %@", message);
            cell = (JSQMessagesCollectionViewCell *)[super collectionView:collectionView cellForItemAtIndexPath:indexPath];
        } break;
    }
    cell.delegate = collectionView;
    
    // Document message catch:
    if (message.isMediaMessage && [[message.media class] isEqual:[FLDocumentAdapter class]]) {
        id<JSQMessageBubbleImageDataSource> bubbleImageDataSource = [collectionView.dataSource collectionView:collectionView messageBubbleImageDataForItemAtIndexPath:indexPath];
        cell.messageBubbleImageView.image = [bubbleImageDataSource messageBubbleImage];
        cell.messageBubbleImageView.highlightedImage = [bubbleImageDataSource messageBubbleHighlightedImage];
    }

    if (message.shouldStartExpireTimer && [cell conformsToProtocol:@protocol(OWSExpirableMessageView)]) {
        id<OWSExpirableMessageView> expirableView = (id<OWSExpirableMessageView>)cell;
        [expirableView startExpirationTimerWithExpiresAtSeconds:message.expiresAtSeconds
                                         initialDurationSeconds:message.expiresInSeconds];
    }

    return cell;
}

#pragma mark - Loading message cells

- (JSQMessagesCollectionViewCell *)loadIncomingMessageCellForMessage:(id<OWSMessageData>)message
                                                         atIndexPath:(NSIndexPath *)indexPath
{
    OWSIncomingMessageCollectionViewCell *cell
        = (OWSIncomingMessageCollectionViewCell *)[super collectionView:self.collectionView
                                                 cellForItemAtIndexPath:indexPath];
    
    if (![cell isKindOfClass:[OWSIncomingMessageCollectionViewCell class]]) {
        DDLogError(@"%@ Unexpected cell type: %@", self.tag, cell);
        return cell;
    }
    
    cell.textView.selectable = NO;
    cell.textView.userInteractionEnabled = NO;
    
    [cell ows_didLoad];
    return cell;
}

- (JSQMessagesCollectionViewCell *)loadOutgoingCellForMessage:(id<OWSMessageData>)message
                                                  atIndexPath:(NSIndexPath *)indexPath
{
    OWSOutgoingMessageCollectionViewCell *cell
        = (OWSOutgoingMessageCollectionViewCell *)[super collectionView:self.collectionView
                                                 cellForItemAtIndexPath:indexPath];

    if (![cell isKindOfClass:[OWSOutgoingMessageCollectionViewCell class]]) {
        DDLogError(@"%@ Unexpected cell type: %@", self.tag, cell);
        return cell;
    }
    
    cell.textView.selectable = NO;
    cell.textView.userInteractionEnabled = NO;
    
    [cell ows_didLoad];

    if (message.isMediaMessage) {
        if (![message isKindOfClass:[TSMessageAdapter class]]) {
            DDLogError(@"%@ Unexpected media message:%@", self.tag, message.class);
        }
        TSMessageAdapter *messageAdapter = (TSMessageAdapter *)message;
        cell.mediaView.alpha = messageAdapter.mediaViewAlpha;
    }

    return cell;
}

- (OWSCallCollectionViewCell *)loadCallCellForCall:(OWSCall *)call atIndexPath:(NSIndexPath *)indexPath
{
    OWSCallCollectionViewCell *callCell = [self.collectionView dequeueReusableCellWithReuseIdentifier:[OWSCallCollectionViewCell cellReuseIdentifier]
                                                                                         forIndexPath:indexPath];

    NSString *text =  call.date != nil ? [call text] : call.senderDisplayName;
    NSString *allText = call.date != nil ? [text stringByAppendingString:[call dateText]] : text;

    UIFont *boldFont = [UIFont fontWithName:@"HelveticaNeue-Medium" size:12.0f];
    NSMutableAttributedString *attributedText = [[NSMutableAttributedString alloc] initWithString:allText
                                                                                       attributes:@{ NSFontAttributeName: boldFont }];
    if([call date]!=nil) {
        // Not a group meta message
        UIFont *regularFont = [UIFont fontWithName:@"HelveticaNeue-Light" size:12.0f];
        const NSRange range = NSMakeRange([text length], [[call dateText] length]);
        [attributedText setAttributes:@{ NSFontAttributeName: regularFont }
                                range:range];
    }
    callCell.textView.text = nil;
    callCell.textView.attributedText = attributedText;

    callCell.textView.textAlignment = NSTextAlignmentCenter;
    callCell.textView.textColor = [UIColor ows_materialBlueColor];
    callCell.layer.shouldRasterize = YES;
    callCell.layer.rasterizationScale = [UIScreen mainScreen].scale;

    // Disable text selectability. Specifying this in prepareForReuse/awakeFromNib was not sufficient.
    callCell.textView.userInteractionEnabled = NO;
    callCell.textView.selectable = NO;

    return callCell;
}

- (OWSDisplayedMessageCollectionViewCell *)loadDisplayedMessageCollectionViewCellForIndexPath:(NSIndexPath *)indexPath
{
    OWSDisplayedMessageCollectionViewCell *messageCell = [self.collectionView dequeueReusableCellWithReuseIdentifier:[OWSDisplayedMessageCollectionViewCell cellReuseIdentifier]
                                                                                                        forIndexPath:indexPath];
    messageCell.layer.shouldRasterize = YES;
    messageCell.layer.rasterizationScale = [UIScreen mainScreen].scale;
    messageCell.textView.textColor = [UIColor darkGrayColor];
    messageCell.cellTopLabel.attributedText = [self.collectionView.dataSource collectionView:self.collectionView attributedTextForCellTopLabelAtIndexPath:indexPath];

    return messageCell;
}

- (OWSDisplayedMessageCollectionViewCell *)loadInfoMessageCellForMessage:(TSMessageAdapter *)infoMessage
                                                             atIndexPath:(NSIndexPath *)indexPath
{
    OWSDisplayedMessageCollectionViewCell *infoCell = [self loadDisplayedMessageCollectionViewCellForIndexPath:indexPath];

    // HACK this will get called when we get a new info message, but there's gotta be a better spot for this.
    OWSDisappearingMessagesConfiguration *configuration =
        [OWSDisappearingMessagesConfiguration fetchObjectWithUniqueID:self.thread.uniqueId];
    [self setBarButtonItemsForDisappearingMessagesConfiguration:configuration];

    infoCell.textView.text = [infoMessage text];

    // Disable text selectability. Specifying this in prepareForReuse/awakeFromNib was not sufficient.
    infoCell.textView.userInteractionEnabled = NO;
    infoCell.textView.selectable = NO;

    infoCell.messageBubbleContainerView.layer.borderColor = [[UIColor ows_infoMessageBorderColor] CGColor];
    if (infoMessage.infoMessageType == TSInfoMessageTypeDisappearingMessagesUpdate) {
        infoCell.headerImageView.image = [UIImage imageNamed:@"ic_timer"];
        infoCell.headerImageView.backgroundColor = [UIColor whiteColor];
        // Lighten up the broad stroke header icon to match the perceived color of the border.
        infoCell.headerImageView.tintColor = [UIColor ows_infoMessageBorderColor];
    } else {
        infoCell.headerImageView.image = [UIImage imageNamed:@"warning_white"];
    }


    return infoCell;
}

- (OWSDisplayedMessageCollectionViewCell *)loadErrorMessageCellForMessage:(TSMessageAdapter *)errorMessage
                                                              atIndexPath:(NSIndexPath *)indexPath
{
    OWSDisplayedMessageCollectionViewCell *errorCell = [self loadDisplayedMessageCollectionViewCellForIndexPath:indexPath];
    errorCell.textView.text = [errorMessage text];

    // Disable text selectability. Specifying this in prepareForReuse/awakeFromNib was not sufficient.
    errorCell.textView.userInteractionEnabled = NO;
    errorCell.textView.selectable = NO;

    errorCell.messageBubbleContainerView.layer.borderColor = [[UIColor ows_errorMessageBorderColor] CGColor];
    errorCell.headerImageView.image = [UIImage imageNamed:@"error_white"];

    return errorCell;
}

#pragma mark - Adjusting cell label heights

- (CGFloat)collectionView:(JSQMessagesCollectionView *)collectionView
                              layout:(JSQMessagesCollectionViewFlowLayout *)collectionViewLayout
    heightForCellTopLabelAtIndexPath:(NSIndexPath *)indexPath {
    if ([self showDateAtIndexPath:indexPath]) {
        return kJSQMessagesCollectionViewCellLabelHeightDefault;
    }

    return 0.0f;
}

- (BOOL)showDateAtIndexPath:(NSIndexPath *)indexPath {
    BOOL showDate = NO;
    if (indexPath.row == 0) {
        showDate = YES;
    } else {
        id<OWSMessageData> currentMessage = [self messageAtIndexPath:indexPath];

        id<OWSMessageData> previousMessage =
            [self messageAtIndexPath:[NSIndexPath indexPathForItem:indexPath.row - 1 inSection:indexPath.section]];

        NSTimeInterval timeDifference = [currentMessage.date timeIntervalSinceDate:previousMessage.date];
        if (timeDifference > kTSMessageSentDateShowTimeInterval) {
            showDate = YES;
        }
    }
    return showDate;
}

- (NSAttributedString *)collectionView:(JSQMessagesCollectionView *)collectionView
    attributedTextForCellTopLabelAtIndexPath:(NSIndexPath *)indexPath {
    if ([self showDateAtIndexPath:indexPath]) {
        id<OWSMessageData> currentMessage = [self messageAtIndexPath:indexPath];

        return [[JSQMessagesTimestampFormatter sharedFormatter] attributedTimestampForDate:currentMessage.date];
    }

    return nil;
}

- (BOOL)shouldShowMessageStatusAtIndexPath:(NSIndexPath *)indexPath
{
    id<OWSMessageData> currentMessage = [self messageAtIndexPath:indexPath];

    if (currentMessage.isExpiringMessage) {
        return YES;
    }

    return !![self collectionView:self.collectionView attributedTextForCellBottomLabelAtIndexPath:indexPath];
}

- (id<OWSMessageData>)nextOutgoingMessage:(NSIndexPath *)indexPath
{
    id<OWSMessageData> nextMessage =
        [self messageAtIndexPath:[NSIndexPath indexPathForRow:indexPath.row + 1 inSection:indexPath.section]];
    int i = 1;

    while (indexPath.item + i < [self.collectionView numberOfItemsInSection:indexPath.section] - 1
        && !nextMessage.isOutgoingAndDelivered) {
        i++;
        nextMessage =
            [self messageAtIndexPath:[NSIndexPath indexPathForRow:indexPath.row + i inSection:indexPath.section]];
    }

    return nextMessage;
}

- (NSAttributedString *)collectionView:(JSQMessagesCollectionView *)collectionView
    attributedTextForCellBottomLabelAtIndexPath:(NSIndexPath *)indexPath
{
    id<OWSMessageData> messageData = [self messageAtIndexPath:indexPath];
    if (![messageData isKindOfClass:[TSMessageAdapter class]]) {
        return nil;
    }

    TSMessageAdapter *message = (TSMessageAdapter *)messageData;
    if (message.messageType == TSOutgoingMessageAdapter) {
        TSOutgoingMessage *outgoingMessage = (TSOutgoingMessage *)message.interaction;
        if (outgoingMessage.messageState == TSOutgoingMessageStateUnsent) {
            return [[NSAttributedString alloc] initWithString:NSLocalizedString(@"FAILED_SENDING_TEXT", nil)];
        } else if (message.isOutgoingAndDelivered) {
            NSAttributedString *deliveredString =
                [[NSAttributedString alloc] initWithString:NSLocalizedString(@"DELIVERED_MESSAGE_TEXT", @"")];

            // Show when it's the last message in the thread
            if (indexPath.item == [self.collectionView numberOfItemsInSection:indexPath.section] - 1) {
                [self updateLastDeliveredMessage:message];
                return deliveredString;
            }

            // Or when the next message is *not* an outgoing delivered message.
            TSMessageAdapter *nextMessage = [self nextOutgoingMessage:indexPath];
            if (!nextMessage.isOutgoingAndDelivered) {
                [self updateLastDeliveredMessage:message];
                return deliveredString;
            }
        } else if (message.isMediaBeingSent) {
            return [[NSAttributedString alloc] initWithString:NSLocalizedString(@"UPLOADING_MESSAGE_TEXT",
                                                                  @"message footer while attachment is uploading")];
        }
    } else if (message.messageType == TSIncomingMessageAdapter) {
        TSIncomingMessage *incomingMessage = (TSIncomingMessage *)message.interaction;
        if (!incomingMessage.hasAnnotation) {
            NSString *_Nonnull name = [self.contactsManager nameStringForContactId:incomingMessage.authorId];
            NSAttributedString *senderNameString = [[NSAttributedString alloc] initWithString:name];
            
            return senderNameString;
        }
    }
    return nil;
}

- (void)updateLastDeliveredMessage:(TSMessageAdapter *)newLastDeliveredMessage
{
    if (newLastDeliveredMessage.interaction.timestamp > self.lastDeliveredMessage.interaction.timestamp) {
        TSMessageAdapter *penultimateDeliveredMessage = self.lastDeliveredMessage;
        self.lastDeliveredMessage = newLastDeliveredMessage;
        [penultimateDeliveredMessage.interaction touch];
    }
}

- (CGFloat)collectionView:(JSQMessagesCollectionView *)collectionView
                                 layout:(JSQMessagesCollectionViewFlowLayout *)collectionViewLayout
    heightForCellBottomLabelAtIndexPath:(NSIndexPath *)indexPath
{
    if ([self shouldShowMessageStatusAtIndexPath:indexPath]) {
        return 16.0f;
    }

    return 0.0f;
}

#pragma mark - Actions

- (void)showConversationSettings
{
    if (self.userLeftGroup) {
        DDLogDebug(@"%@ Ignoring request to show conversation settings, since user left group", self.tag);
        return;
    }
    [self performSegueWithIdentifier:OWSMessagesViewControllerSeguePushConversationSettings sender:self];
}

- (void)didTapTitle
{
    DDLogDebug(@"%@ Tapped title in navbar", self.tag);
    [self showConversationSettings];
}

- (void)didTapManageGroupButton:(id)sender
{
    DDLogDebug(@"%@ Tapped options menu in navbar", self.tag);
    [self showConversationSettings];
}

- (void)didTapTimerInNavbar
{
    DDLogDebug(@"%@ Tapped timer in navbar", self.tag);
    [self showConversationSettings];
}


- (void)collectionView:(JSQMessagesCollectionView *)collectionView
    didTapMessageBubbleAtIndexPath:(NSIndexPath *)indexPath
{
    id<OWSMessageData> messageItem = [self messageAtIndexPath:indexPath];
    TSInteraction *interaction = [self interactionAtIndexPath:indexPath];

    switch (messageItem.messageType) {
        case TSOutgoingMessageAdapter: {
            TSOutgoingMessage *outgoingMessage = (TSOutgoingMessage *)interaction;
            if (outgoingMessage.messageState == TSOutgoingMessageStateUnsent) {
                [self handleUnsentMessageTap:outgoingMessage];

                // This `break` is intentionally within the if.
                // We want to activate fullscreen media view for sent items
                // but not those which failed-to-send
                break;
            }
            // No `break` as we want to fall through to capture tapping on Outgoing media items too
        }
        case TSIncomingMessageAdapter: {
            BOOL isMediaMessage = [messageItem isMediaMessage];

            if (isMediaMessage) {
                if ([[messageItem media] isKindOfClass:[FLDocumentAdapter class]]) {
                    FLDocumentAdapter *document = (FLDocumentAdapter *)[messageItem media];
                    NSURL *documentURL = document.attachment.mediaURL;
                    UIActivityViewController *activityController = [[UIActivityViewController alloc] initWithActivityItems:@[ documentURL ]
                                                                                                    applicationActivities:nil];
                    [self presentViewController:activityController animated:YES completion:nil];
                    
                } else if ([[messageItem media] isKindOfClass:[TSPhotoAdapter class]]) {
                    TSPhotoAdapter *messageMedia = (TSPhotoAdapter *)[messageItem media];

                    tappedImage = ((UIImageView *)[messageMedia mediaView]).image;
                    if(tappedImage == nil) {
                        DDLogWarn(@"tapped TSPhotoAdapter with nil image");
                    } else {
                        CGRect convertedRect =
                        [self.collectionView convertRect:[collectionView cellForItemAtIndexPath:indexPath].frame
                                                  toView:nil];
                        __block TSAttachment *attachment = nil;
                        [self.uiDatabaseConnection readWithBlock:^(YapDatabaseReadTransaction *transaction) {
                            attachment =
                            [TSAttachment fetchObjectWithUniqueID:messageMedia.attachmentId transaction:transaction];
                        }];

                        if ([attachment isKindOfClass:[TSAttachmentStream class]]) {
                            TSAttachmentStream *attStream = (TSAttachmentStream *)attachment;
                            FullImageViewController *vc   = [[FullImageViewController alloc]
                                                             initWithAttachment:attStream
                                                             fromRect:convertedRect
                                                             forInteraction:[self interactionAtIndexPath:indexPath]
                                                             isAnimated:NO];

                            [vc presentFromViewController:self.navigationController];
                        }
                    }
                } else if ([[messageItem media] isKindOfClass:[TSAnimatedAdapter class]]) {
                    // Show animated image full-screen
                    TSAnimatedAdapter *messageMedia = (TSAnimatedAdapter *)[messageItem media];
                    tappedImage                     = ((UIImageView *)[messageMedia mediaView]).image;
                    if(tappedImage == nil) {
                        DDLogWarn(@"tapped TSAnimatedAdapter with nil image");
                    } else {
                        CGRect convertedRect =
                        [self.collectionView convertRect:[collectionView cellForItemAtIndexPath:indexPath].frame
                                                  toView:nil];
                        __block TSAttachment *attachment = nil;
                        [self.uiDatabaseConnection readWithBlock:^(YapDatabaseReadTransaction *transaction) {
                            attachment =
                            [TSAttachment fetchObjectWithUniqueID:messageMedia.attachmentId transaction:transaction];
                        }];
                        if ([attachment isKindOfClass:[TSAttachmentStream class]]) {
                            TSAttachmentStream *attStream = (TSAttachmentStream *)attachment;
                            FullImageViewController *vc =
                            [[FullImageViewController alloc] initWithAttachment:attStream
                                                                       fromRect:convertedRect
                                                                 forInteraction:[self interactionAtIndexPath:indexPath]
                                                                     isAnimated:YES];
                            [vc presentFromViewController:self.navigationController];
                        }
                    }
                } else if ([[messageItem media] isKindOfClass:[TSVideoAttachmentAdapter class]]) {
                    // fileurl disappeared should look up in db as before. will do refactor
                    // full screen, check this setup with a .mov
                    TSVideoAttachmentAdapter *messageMedia = (TSVideoAttachmentAdapter *)[messageItem media];
                    _currentMediaAdapter                   = messageMedia;
                    __block TSAttachment *attachment       = nil;
                    [self.uiDatabaseConnection readWithBlock:^(YapDatabaseReadTransaction *transaction) {
                      attachment =
                          [TSAttachment fetchObjectWithUniqueID:messageMedia.attachmentId transaction:transaction];
                    }];

                    if ([attachment isKindOfClass:[TSAttachmentStream class]]) {
                        TSAttachmentStream *attStream = (TSAttachmentStream *)attachment;
                        NSFileManager *fileManager    = [NSFileManager defaultManager];
                        if ([messageMedia isVideo]) {
                            if ([fileManager fileExistsAtPath:[attStream.mediaURL path]]) {
                                [self dismissKeyBoard];
                                _videoPlayer = [[MPMoviePlayerController alloc] initWithContentURL:attStream.mediaURL];
                                [_videoPlayer prepareToPlay];

                                [[NSNotificationCenter defaultCenter]
                                    addObserver:self
                                       selector:@selector(moviePlayBackDidFinish:)
                                           name:MPMoviePlayerPlaybackDidFinishNotification
                                         object:_videoPlayer];

                                _videoPlayer.controlStyle   = MPMovieControlStyleDefault;
                                _videoPlayer.shouldAutoplay = YES;
                                [self.view addSubview:_videoPlayer.view];
                                [_videoPlayer setFullscreen:YES animated:YES];
                            }
                        } else if ([messageMedia isAudio]) {
                            if (messageMedia.isAudioPlaying) {
                                // if you had started playing an audio msg and now you're tapping it to pause
                                messageMedia.isAudioPlaying = NO;
                                [_audioPlayer pause];
                                messageMedia.isPaused = YES;
                                [_audioPlayerPoller invalidate];
                                double current = [_audioPlayer currentTime] / [_audioPlayer duration];
                                [messageMedia setAudioProgressFromFloat:(float)current];
                                [messageMedia setAudioIconToPlay];
                            } else {
                                BOOL isResuming = NO;
                                [_audioPlayerPoller invalidate];

                                // loop through all the other bubbles and set their isPlaying to false
                                NSInteger num_bubbles = [self collectionView:collectionView numberOfItemsInSection:0];
                                for (NSInteger i = 0; i < num_bubbles; i++) {
                                    NSIndexPath *indexPathI = [NSIndexPath indexPathForRow:i inSection:0];
                                    id<OWSMessageData> message = [self messageAtIndexPath:indexPathI];

                                    if (message.messageType == TSIncomingMessageAdapter && message.isMediaMessage) {
                                        TSVideoAttachmentAdapter *msgMedia
                                            = (TSVideoAttachmentAdapter *)[message media];
                                        if ([msgMedia isAudio]) {
                                            if (msgMedia == messageMedia && messageMedia.isPaused) {
                                                isResuming = YES;
                                            } else {
                                                msgMedia.isAudioPlaying = NO;
                                                msgMedia.isPaused       = NO;
                                                [msgMedia setAudioIconToPlay];
                                                [msgMedia setAudioProgressFromFloat:0];
                                                [msgMedia resetAudioDuration];
                                            }
                                        }
                                    }
                                }

                                if (isResuming) {
                                    // if you had paused an audio msg and now you're tapping to resume
                                    [_audioPlayer prepareToPlay];
                                    [_audioPlayer play];
                                    [messageMedia setAudioIconToPause];
                                    messageMedia.isAudioPlaying = YES;
                                    messageMedia.isPaused       = NO;
                                    _audioPlayerPoller =
                                        [NSTimer scheduledTimerWithTimeInterval:.05
                                                                         target:self
                                                                       selector:@selector(audioPlayerUpdated:)
                                                                       userInfo:@{
                                                                           @"adapter" : messageMedia
                                                                       }
                                                                        repeats:YES];
                                } else {
                                    // if you are tapping an audio msg for the first time to play
                                    messageMedia.isAudioPlaying = YES;
                                    NSError *error;
                                    _audioPlayer =
                                        [[AVAudioPlayer alloc] initWithContentsOfURL:attStream.mediaURL error:&error];
                                    if (error) {
                                        DDLogError(@"error: %@", error);
                                    }
                                    [_audioPlayer prepareToPlay];
                                    [_audioPlayer play];
                                    [messageMedia setAudioIconToPause];
                                    _audioPlayer.delegate = self;
                                    _audioPlayerPoller =
                                        [NSTimer scheduledTimerWithTimeInterval:.05
                                                                         target:self
                                                                       selector:@selector(audioPlayerUpdated:)
                                                                       userInfo:@{
                                                                           @"adapter" : messageMedia
                                                                       }
                                                                        repeats:YES];
                                }
                            }
                        }
                    }
                }
            }
        } break;
        case TSErrorMessageAdapter:
            [self handleErrorMessageTap:(TSErrorMessage *)interaction];
            break;
        case TSInfoMessageAdapter:
            [self handleWarningTap:interaction];
            break;
        case TSCallAdapter:
            break;
        default:
            DDLogDebug(@"Unhandled bubble touch for interaction: %@.", interaction);
            break;
    }
}

- (void)handleWarningTap:(TSInteraction *)interaction
{
    if ([interaction isKindOfClass:[TSIncomingMessage class]]) {
        TSIncomingMessage *message = (TSIncomingMessage *)interaction;

        for (NSString *attachmentId in message.attachmentIds) {
            __block TSAttachment *attachment;

            [self.editingDatabaseConnection readWithBlock:^(YapDatabaseReadTransaction *transaction) {
              attachment = [TSAttachment fetchObjectWithUniqueID:attachmentId transaction:transaction];
            }];

            if ([attachment isKindOfClass:[TSAttachmentPointer class]]) {
                TSAttachmentPointer *pointer = (TSAttachmentPointer *)attachment;

                // FIXME: possible for pointer to get stuck in isDownloading state if app is closed while downloading.
                // see: https://github.com/WhisperSystems/Signal-iOS/issues/1254
                if (!pointer.isDownloading) {
                    OWSAttachmentsProcessor *processor =
                        [[OWSAttachmentsProcessor alloc] initWithAttachmentPointer:pointer
                                                                    networkManager:self.networkManager];
                    [processor fetchAttachmentsForMessage:message
                        success:^(TSAttachmentStream *_Nonnull attachmentStream) {
                            DDLogInfo(
                                @"%@ Successfully redownloaded attachment in thread: %@", self.tag, message.thread);
                        }
                        failure:^(NSError *_Nonnull error) {
                            DDLogWarn(@"%@ Failed to redownload message with error: %@", self.tag, error);
                        }];
                }
            }
        }
    }
}


- (void)moviePlayBackDidFinish:(id)sender {
    DDLogDebug(@"playback finished");
}

- (void)collectionView:(JSQMessagesCollectionView *)collectionView
                             header:(JSQMessagesLoadEarlierHeaderView *)headerView
    didTapLoadEarlierMessagesButton:(UIButton *)sender {
    if ([self shouldShowLoadEarlierMessages]) {
        self.page++;
    }

    NSInteger item = (NSInteger)[self scrollToItem];

    [self updateRangeOptionsForPage:self.page];

    [self.uiDatabaseConnection readWithBlock:^(YapDatabaseReadTransaction *transaction) {
      [self.messageMappings updateWithTransaction:transaction];
    }];

    [self updateLayoutForEarlierMessagesWithOffset:item];
}

- (BOOL)shouldShowLoadEarlierMessages {
    __block BOOL show = YES;

    [self.uiDatabaseConnection readWithBlock:^(YapDatabaseReadTransaction *transaction) {
      show = [self.messageMappings numberOfItemsInGroup:self.thread.uniqueId] <
             [[transaction ext:TSMessageDatabaseViewExtensionName] numberOfItemsInGroup:self.thread.uniqueId];
    }];

    return show;
}

- (NSUInteger)scrollToItem {
    __block NSUInteger item =
        kYapDatabaseRangeLength * (self.page + 1) - [self.messageMappings numberOfItemsInGroup:self.thread.uniqueId];

    [self.uiDatabaseConnection readWithBlock:^(YapDatabaseReadTransaction *transaction) {

      NSUInteger numberOfVisibleMessages = [self.messageMappings numberOfItemsInGroup:self.thread.uniqueId];
      NSUInteger numberOfTotalMessages =
          [[transaction ext:TSMessageDatabaseViewExtensionName] numberOfItemsInGroup:self.thread.uniqueId];
      NSUInteger numberOfMessagesToLoad = numberOfTotalMessages - numberOfVisibleMessages;

      BOOL canLoadFullRange = numberOfMessagesToLoad >= kYapDatabaseRangeLength;

      if (!canLoadFullRange) {
          item = numberOfMessagesToLoad;
      }
    }];

    return item == 0 ? item : item - 1;
}

- (void)updateLoadEarlierVisible {
    [self setShowLoadEarlierMessagesHeader:[self shouldShowLoadEarlierMessages]];
}

- (void)updateLayoutForEarlierMessagesWithOffset:(NSInteger)offset {
    [self.collectionView.collectionViewLayout
        invalidateLayoutWithContext:[JSQMessagesCollectionViewFlowLayoutInvalidationContext context]];
    [self.collectionView reloadData];

    [self.collectionView scrollToItemAtIndexPath:[NSIndexPath indexPathForItem:offset inSection:0]
                                atScrollPosition:UICollectionViewScrollPositionTop
                                        animated:NO];

    [self updateLoadEarlierVisible];
}

- (void)updateRangeOptionsForPage:(NSUInteger)page {
    YapDatabaseViewRangeOptions *rangeOptions =
        [YapDatabaseViewRangeOptions flexibleRangeWithLength:kYapDatabaseRangeLength * (page + 1)
                                                      offset:0
                                                        from:YapDatabaseViewEnd];

    rangeOptions.maxLength = kYapDatabaseRangeMaxLength;
    rangeOptions.minLength = kYapDatabaseRangeMinLength;

    [self.messageMappings setRangeOptions:rangeOptions forGroup:self.thread.uniqueId];
}

#pragma mark - Bubble User Actions

- (void)handleUnsentMessageTap:(TSOutgoingMessage *)message {
    [self dismissKeyBoard];
    UIAlertController *alertSheet = [UIAlertController alertControllerWithTitle:nil
                                                                        message:message.mostRecentFailureText
                                                                 preferredStyle:UIAlertControllerStyleActionSheet];
    [alertSheet addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"SEND_AGAIN_BUTTON", @"")
                                                   style:UIAlertActionStyleDefault
                                                 handler:^(UIAlertAction * _Nonnull action) {
                                                     [self.messageSender sendMessage:message
                                                                             success:^{
                                                                                 DDLogInfo(@"%@ Successfully resent failed message.", self.tag);
                                                                             }
                                                                             failure:^(NSError *_Nonnull error) {
                                                                                 DDLogWarn(@"%@ Failed to send message with error: %@", self.tag, error);
                                                                             }];
                                                 }]];
    [alertSheet addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"TXT_DELETE_TITLE", @"")
                                                   style:UIAlertActionStyleDestructive
                                                 handler:^(UIAlertAction * _Nonnull action) {
                                                     DDLogInfo(@"%@ User chose to delete unsent message.", self.tag);
                                                     [message remove];
                                                 }]];
    [alertSheet addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"TXT_CANCEL_TITLE", @"")
                                                   style:UIAlertActionStyleCancel
                                                 handler:^(UIAlertAction * _Nonnull action) {
                                                     DDLogDebug(@"%@ User cancelled unsent dialog", self.tag);
                                                 }]];
    [self.parentViewController presentViewController:alertSheet animated:YES completion:nil];
}

- (void)handleErrorMessageTap:(TSErrorMessage *)message
{
    [self dismissKeyBoard];

    if ([message isKindOfClass:[TSInvalidIdentityKeyErrorMessage class]]) {
        [self tappedInvalidIdentityKeyErrorMessage:(TSInvalidIdentityKeyErrorMessage *)message];
    } else if (message.errorType == TSErrorMessageInvalidMessage) {
        [self tappedCorruptedMessage:message];
    } else {
        DDLogWarn(@"%@ Unhandled tap for error message:%@", self.tag, message);
    }
}

- (void)tappedCorruptedMessage:(TSErrorMessage *)message
{

    NSString *actionSheetTitle = [NSString
        stringWithFormat:NSLocalizedString(@"CORRUPTED_SESSION_DESCRIPTION", @"ActionSheet title"), self.thread.displayName];

    UIAlertController *alertSheet = [UIAlertController alertControllerWithTitle:nil
                                                                        message:actionSheetTitle
                                                                 preferredStyle:UIAlertControllerStyleActionSheet];
    
    [alertSheet addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"FINGERPRINT_SHRED_KEYMATERIAL_BUTTON", nil)
                                                   style:UIAlertActionStyleDefault
                                                 handler:^(UIAlertAction * _Nonnull action) {
#warning XXX Corrupted message handling here
//                                      if (![self.thread isKindOfClass:[TSContactThread class]]) {
//                                          // Corrupt Message errors only appear in contact threads.
                                                     DDLogError(
                                                                @"%@ Unexpected request to reset session in group thread. Refusing",
                                                                self.tag);
                                                     return;
//                                      }
//                                      TSContactThread *contactThread = (TSContactThread *)self.thread;
//                                      [OWSSessionResetJob runWithCorruptedMessage:message
//                                                                    contactThread:contactThread
//                                                                    messageSender:self.messageSender
//                                                                   storageManager:self.storageManager];
                                                 }]];
    [alertSheet addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"TXT_CANCEL_TITLE", @"")
                                                   style:UIAlertActionStyleCancel
                                                 handler:^(UIAlertAction * _Nonnull action) {
                                                     DDLogDebug(@"User Cancelled");
                                                 }]];
    [self.parentViewController presentViewController:alertSheet animated:YES completion:nil];
}

- (void)tappedInvalidIdentityKeyErrorMessage:(TSInvalidIdentityKeyErrorMessage *)errorMessage
{
    [self acceptNewIDKeyWithMessage:errorMessage];
}

-(void)acceptNewIDKeyWithMessage:(TSInvalidIdentityKeyErrorMessage *)errorMessage
{
    DDLogInfo(@"%@ Remote Key Changed actions: Accepted new identity key", self.tag);
    
    [errorMessage acceptNewIdentityKey];
    if ([errorMessage isKindOfClass:[TSInvalidIdentityKeySendingErrorMessage class]]) {
        [self.messageSender
         resendMessageFromKeyError:(TSInvalidIdentityKeySendingErrorMessage *)
         errorMessage
         success:^{
             DDLogDebug(@"%@ Successfully resent key-error message.", self.tag);
         }
         failure:^(NSError *_Nonnull error) {
             DDLogError(@"%@ Failed to resend key-error message with error:%@",
                        self.tag,
                        error);
         }];
    }
}

#pragma mark - Navigation

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    if ([segue.identifier isEqualToString:OWSMessagesViewControllerSegueShowFingerprint]) {
        if (![segue.destinationViewController isKindOfClass:[FingerprintViewController class]]) {
            DDLogError(@"%@ Expected Fingerprint VC but got: %@", self.tag, segue.destinationViewController);
            return;
        }
        FingerprintViewController *vc = (FingerprintViewController *)segue.destinationViewController;

        if (![sender isKindOfClass:[OWSFingerprint class]]) {
            DDLogError(@"%@ Attempting to segue to fingerprint VC without a valid fingerprint: %@", self.tag, sender);
            return;
        }
        OWSFingerprint *fingerprint = (OWSFingerprint *)sender;

        NSString *contactName = [self.contactsManager nameStringForContactId:fingerprint.theirStableId];
        [vc configureWithThread:self.thread fingerprint:fingerprint contactName:contactName];
    } else if ([segue.destinationViewController isKindOfClass:[ConversationSettingsViewController class]]) {
        ConversationSettingsViewController *controller
            = (ConversationSettingsViewController *)segue.destinationViewController;
        [controller configureWithThread:self.thread];
    } else if ([segue.identifier isEqualToString:@"imagePreviewSegue"]) {
        UINavigationController *nvc = (UINavigationController *)segue.destinationViewController;
        ImagePreviewViewController *ipvc = (ImagePreviewViewController *)[[nvc viewControllers] lastObject];
        ipvc.delegate = self;
        UIImage *image = (UIImage *)sender;
        ipvc.image = image;
    }

}

#pragma mark - ImagePreviewController Delegate methods
-(void)didPressSend:(id)sender
{
    [self sendMessageAttachment:[self qualityAdjustedAttachmentForImage:self.imageToPreview]
                   withFilename:self.filenameToPreview
                         ofType:@"image/jpeg"];
    [sender dismissViewControllerAnimated:YES completion:nil];
}
-(void)didPressCancel:(id)sender
{
    [sender dismissViewControllerAnimated:YES completion:nil];
}

#pragma mark - Document picker methods
-(void)chooseDocument
{
    //TODO: ask for/validate iCloud permission
    [UIUtil applyDefaultSystemAppearence];

    UIDocumentPickerViewController *docPicker = [[UIDocumentPickerViewController alloc] initWithDocumentTypes:@[ (__bridge NSString *)kUTTypeItem ] inMode:UIDocumentPickerModeImport];
    docPicker.delegate = self;
    [self.navigationController presentViewController:docPicker animated:YES completion:^{
        [UIUtil applyDefaultSystemAppearence];
    }];
}

-(void)documentPicker:(UIDocumentPickerViewController *)controller didPickDocumentsAtURLs:(NSArray<NSURL *> *)urls
{
    for (NSURL *url in urls) {
        NSString *filePath = url.path;
        if (![[NSFileManager defaultManager] fileExistsAtPath:filePath]) {
            DDLogDebug(@"Selected file not does exist at: %@", url);
            return;
        }
        BOOL isDirectory;
        if ([[NSFileManager defaultManager] fileExistsAtPath:filePath isDirectory:&isDirectory]) {
            if (isDirectory) {
                DDLogDebug(@"Selected item is a directory.  Skipping: %@", url);
                return;
            }
        }
        
        NSString *validationString = NSLocalizedString(@"ATTACHMENT_FILE_VALIDATION", nil);
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:nil
                                                                       message:[NSString stringWithFormat:@"%@%@", validationString, url.lastPathComponent]
                                                                preferredStyle:UIAlertControllerStyleActionSheet];
        UIAlertAction *yesAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"YES", nil)
                                                            style:UIAlertActionStyleDefault
                                                          handler:^(UIAlertAction *action) {
                                                              [UIUtil applyForstaAppearence];

                                                              NSString *mimeType = [MIMETypeUtil getSupportedMIMETypeFromDocumentFile:filePath];
                                                              NSData *fileData = [NSData dataWithContentsOfFile:filePath];
                                                              [self sendMessageAttachment:fileData
                                                                             withFilename:url.lastPathComponent
                                                                                   ofType:mimeType];
                                                          }];
        UIAlertAction *noAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"NO", nil)
                                                           style:UIAlertActionStyleDefault
                                                         handler:^(UIAlertAction *action) {
                                                             [UIUtil applyForstaAppearence];
                                                         }];
        [alert addAction:yesAction];
        [alert addAction:noAction];
        
        [self.navigationController presentViewController:alert animated:YES completion:nil];
    }
}

-(void)documentPickerWasCancelled:(UIDocumentPickerViewController *)controller
{
    [self.navigationController dismissViewControllerAnimated:YES
                                                  completion:^{
                                                      [UIUtil applyForstaAppearence];
                                                  } ];
}

#pragma mark - UIImagePickerController

/*
 *  Presenting UIImagePickerController
 */

- (void)takePictureOrVideo {
    [self ows_askForCameraPermissions:^{
        UIImagePickerController *picker = [[UIImagePickerController alloc] init];
        picker.sourceType = UIImagePickerControllerSourceTypeCamera;
        picker.mediaTypes = @[ (__bridge NSString *)kUTTypeImage, (__bridge NSString *)kUTTypeMovie ];
        picker.allowsEditing = NO;
        picker.delegate = self;
        [self.navigationController presentViewController:picker animated:YES completion:[UIUtil modalCompletionBlock]];
    }];
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
    [self.navigationController presentViewController:picker animated:YES completion:[UIUtil modalCompletionBlock]];
}

/*
 *  Dismissing UIImagePickerController
 */

- (void)imagePickerControllerDidCancel:(UIImagePickerController *)picker {
    [UIUtil modalCompletionBlock]();
    [self.navigationController dismissViewControllerAnimated:YES completion:nil];
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

    __block NSString *filename = @"";
    
    void (^failedToPickAttachment)(NSError *error) = ^void(NSError *error) {
        DDLogError(@"failed to pick attachment with error: %@", error);
    };

    NSString *mediaType = info[UIImagePickerControllerMediaType];
    if ([mediaType isEqualToString:(__bridge NSString *)kUTTypeMovie]) {
        // Video picked from library or captured with camera

        NSURL *videoURL = info[UIImagePickerControllerMediaURL];
        filename = videoURL.lastPathComponent;
        [self sendQualityAdjustedAttachmentForVideo:videoURL];
    } else if (picker.sourceType == UIImagePickerControllerSourceTypeCamera) {
        // Static Image captured from camera

        UIImage *imageFromCamera = [info[UIImagePickerControllerOriginalImage] normalizedImage];
        if (imageFromCamera) {
            [self sendMessageAttachment:[self qualityAdjustedAttachmentForImage:imageFromCamera]
                           withFilename:filename
                                 ofType:@"image/jpeg"];
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

                           if ([assetInfo objectForKey:@"PHImageFileURLKey"]) {
                               NSURL *filenameURL = [assetInfo objectForKey:@"PHImageFileURLKey"];
                               filename = filenameURL.lastPathComponent;
                           }
                           
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
                               [self sendMessageAttachment:imageData
                                              withFilename:filename
                                                    ofType:@"image/gif"];
                           } else {
                               DDLogVerbose(@"Compressing attachment as image/jpeg");
                               UIImage *pickedImage = [[UIImage alloc] initWithData:imageData];
                               
                               self.imageToPreview = pickedImage;
                               self.filenameToPreview = filename;
                               [self dismissViewControllerAnimated:YES completion:^{
                                   [self performSegueWithIdentifier:@"imagePreviewSegue" sender:pickedImage];
                               }];

//                               [self sendMessageAttachment:[self qualityAdjustedAttachmentForImage:pickedImage]
//                                                    ofType:@"image/jpeg"];
                           }
                       }];
    }
}

- (void)sendMessageAttachment:(NSData *)attachmentData withFilename:(NSString *)filename ofType:(NSString *)attachmentType
{
    TSOutgoingMessage *message;
    OWSDisappearingMessagesConfiguration *configuration =
        [OWSDisappearingMessagesConfiguration fetchObjectWithUniqueID:self.thread.uniqueId];
    if (configuration.isEnabled) {
        message = [[TSOutgoingMessage alloc] initWithTimestamp:[NSDate ows_millisecondTimeStamp]
                                                      inThread:self.thread
                                                   messageBody:nil
                                                 attachmentIds:[NSMutableArray new]
                                              expiresInSeconds:configuration.durationSeconds];
    } else {
        message = [[TSOutgoingMessage alloc] initWithTimestamp:[NSDate ows_millisecondTimeStamp]
                                                      inThread:self.thread
                                                   messageBody:nil
                                                 attachmentIds:[NSMutableArray new]];
    }
    message.uniqueId = [[NSUUID UUID] UUIDString];
    message.messageType = @"content";
    
    // Check to see if a model view is being presented and dismiss if necessary.
    UIViewController *vc = [self.navigationController presentedViewController];
    if (vc) {
    [self.navigationController dismissViewControllerAnimated:YES
                             completion:^{
                                 DDLogVerbose(@"Sending attachment. Size in bytes: %lu, contentType: %@",
                                              (unsigned long)attachmentData.length,
                                              attachmentType);
                                 [self.messageSender sendAttachmentData:attachmentData
                                                               filename:filename
                                     contentType:attachmentType
                                     inMessage:message
                                     success:^{
                                         DDLogDebug(@"%@ Successfully sent message attachment.", self.tag);
                                     }
                                     failure:^(NSError *error) {
                                         DDLogError(
                                             @"%@ Failed to send message attachment with error: %@", self.tag, error);
                                     }];
                             }];
    } else {
        DDLogVerbose(@"Sending attachment. Size in bytes: %lu, contentType: %@",
                     (unsigned long)attachmentData.length,
                     attachmentType);
        [self.messageSender sendAttachmentData:attachmentData
                                      filename:filename
                                   contentType:attachmentType
                                     inMessage:message
                                       success:^{
                                           DDLogDebug(@"%@ Successfully sent message attachment.", self.tag);
                                       }
                                       failure:^(NSError *error) {
                                           DDLogError(
                                                      @"%@ Failed to send message attachment with error: %@", self.tag, error);
                                       }];
    }
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
        [self sendMessageAttachment:[NSData dataWithContentsOfURL:compressedVideoUrl]
                       withFilename:@""
                             ofType:@"video/mp4"];
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

#pragma mark - Storage access

- (YapDatabaseConnection *)uiDatabaseConnection {
    NSAssert([NSThread isMainThread], @"Must access uiDatabaseConnection on main thread!");
    if (!_uiDatabaseConnection) {
        _uiDatabaseConnection = [self.storageManager newDatabaseConnection];
        [_uiDatabaseConnection beginLongLivedReadTransaction];
    }
    return _uiDatabaseConnection;
}

- (YapDatabaseConnection *)editingDatabaseConnection {
    if (!_editingDatabaseConnection) {
        _editingDatabaseConnection = [self.storageManager newDatabaseConnection];
    }
    return _editingDatabaseConnection;
}


- (void)yapDatabaseModified:(NSNotification *)notification
{
    [self updateBackButtonAsync];

    NSArray *notifications = [self.uiDatabaseConnection beginLongLivedReadTransaction];
    
    // Check for updates to the thread/conversation
    if ([self.uiDatabaseConnection hasChangeForKey:self.thread.uniqueId
                                      inCollection:[TSThread collection]
                                   inNotifications:notifications]) {
        [self.uiDatabaseConnection asyncReadWithBlock:^(YapDatabaseReadTransaction *transaction) {
            self.thread = [TSThread fetchObjectWithUniqueID:self.thread.uniqueId transaction:transaction];
        } completionBlock:^{
            [self setNavigationTitle];
        }];
    }
    
    // Check for updates to the mappings
    if (![[self.uiDatabaseConnection ext:TSMessageDatabaseViewExtensionName]
          hasChangesForNotifications:notifications]) {
        [self.uiDatabaseConnection readWithBlock:^(YapDatabaseReadTransaction *transaction) {
            [self.messageMappings updateWithTransaction:transaction];
        }];
        return;
    }

    if ([self userLeftGroup]) {
        [self hideInputIfNeeded];
        [self disableInfoButtonIfNeeded];
    }

    // HACK to work around radar #28167779
    // "UICollectionView performBatchUpdates can trigger a crash if the collection view is flagged for layout"
    // more: https://github.com/PSPDFKit-labs/radar.apple.com/tree/master/28167779%20-%20CollectionViewBatchingIssue
    // This was our #2 crash, and much exacerbated by the refactoring somewhere between 2.6.2.0-2.6.3.8
    [self.collectionView layoutIfNeeded];
    // ENDHACK to work around radar #28167779

    NSArray *messageRowChanges = nil;
    NSArray *sectionChanges    = nil;
    [[self.uiDatabaseConnection ext:TSMessageDatabaseViewExtensionName] getSectionChanges:&sectionChanges
                                                                               rowChanges:&messageRowChanges
                                                                         forNotifications:notifications
                                                                             withMappings:self.messageMappings];

    __block BOOL scrollToBottom = NO;

    if ([sectionChanges count] == 0 && [messageRowChanges count] == 0) {
        return;
    }

    [self.collectionView performBatchUpdates:^{
      for (YapDatabaseViewRowChange *rowChange in messageRowChanges) {
          switch (rowChange.type) {
              case YapDatabaseViewChangeDelete: {
                  [self.collectionView deleteItemsAtIndexPaths:@[ rowChange.indexPath ]];

                  YapCollectionKey *collectionKey = rowChange.collectionKey;
                  if (collectionKey.key) {
                      [self.messageAdapterCache removeObjectForKey:collectionKey.key];
                  }
                  break;
              }
              case YapDatabaseViewChangeInsert: {
                  [self.collectionView insertItemsAtIndexPaths:@[ rowChange.newIndexPath ]];
                  scrollToBottom = YES;
                  break;
              }
              case YapDatabaseViewChangeMove: {
                  [self.collectionView deleteItemsAtIndexPaths:@[ rowChange.indexPath ]];
                  [self.collectionView insertItemsAtIndexPaths:@[ rowChange.newIndexPath ]];
                  break;
              }
              case YapDatabaseViewChangeUpdate: {
                  YapCollectionKey *collectionKey = rowChange.collectionKey;
                  if (collectionKey.key) {
                      [self.messageAdapterCache removeObjectForKey:collectionKey.key];
                  }
                  [self.collectionView reloadItemsAtIndexPaths:@[ rowChange.indexPath ]];
                  break;
              }
          }
      }
    }
        completion:^(BOOL success) {
          if (!success) {
              [self.collectionView.collectionViewLayout
                  invalidateLayoutWithContext:[JSQMessagesCollectionViewFlowLayoutInvalidationContext context]];
              [self.collectionView reloadData];
          }
          if (scrollToBottom) {
              [self scrollToBottomAnimated:YES];
          }
        }];
}

#pragma mark - UICollectionView DataSource

- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section {
    NSInteger numberOfMessages = (NSInteger)[self.messageMappings numberOfItemsInSection:(NSUInteger)section];
    return numberOfMessages;
}

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

- (id<OWSMessageData>)messageAtIndexPath:(NSIndexPath *)indexPath
{
    TSInteraction *interaction = [self interactionAtIndexPath:indexPath];

    id<OWSMessageData> messageAdapter = [self.messageAdapterCache objectForKey:interaction.uniqueId];

    if (!messageAdapter) {
        messageAdapter = [TSMessageAdapter messageViewDataWithInteraction:interaction inThread:self.thread contactsManager:self.contactsManager];
        [self.messageAdapterCache setObject:messageAdapter forKey: interaction.uniqueId];
    }

    return messageAdapter;
}

#pragma mark - Audio

- (void)recordAudio {
    // Define the recorder setting
    NSArray *pathComponents = [NSArray
        arrayWithObjects:[NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) lastObject],
                         [NSString stringWithFormat:@"%lld.m4a", [NSDate ows_millisecondTimeStamp]],
                         nil];
    NSURL *outputFileURL = [NSURL fileURLWithPathComponents:pathComponents];

    // Setup audio session
    AVAudioSession *session = [AVAudioSession sharedInstance];
    [session setCategory:AVAudioSessionCategoryPlayAndRecord error:nil];

    NSMutableDictionary *recordSetting = [[NSMutableDictionary alloc] init];
    [recordSetting setValue:[NSNumber numberWithInt:kAudioFormatMPEG4AAC] forKey:AVFormatIDKey];
    [recordSetting setValue:[NSNumber numberWithFloat:44100.0] forKey:AVSampleRateKey];
    [recordSetting setValue:[NSNumber numberWithInt:2] forKey:AVNumberOfChannelsKey];

    // Initiate and prepare the recorder
    _audioRecorder          = [[AVAudioRecorder alloc] initWithURL:outputFileURL settings:recordSetting error:NULL];
    _audioRecorder.delegate = self;
    _audioRecorder.meteringEnabled = YES;
    [_audioRecorder prepareToRecord];
}

- (void)audioPlayerUpdated:(NSTimer *)timer {
    double current  = [_audioPlayer currentTime] / [_audioPlayer duration];
    double interval = [_audioPlayer duration] - [_audioPlayer currentTime];
    [_currentMediaAdapter setDurationOfAudio:interval];
    [_currentMediaAdapter setAudioProgressFromFloat:(float)current];
}

- (void)audioPlayerDidFinishPlaying:(AVAudioPlayer *)player successfully:(BOOL)flag {
    [_audioPlayerPoller invalidate];
    [_currentMediaAdapter setAudioProgressFromFloat:0];
    [_currentMediaAdapter setDurationOfAudio:_audioPlayer.duration];
    [_currentMediaAdapter setAudioIconToPlay];
}

- (void)audioRecorderDidFinishRecording:(AVAudioRecorder *)recorder successfully:(BOOL)flag {
    if (flag) {
        [self sendMessageAttachment:[NSData dataWithContentsOfURL:recorder.url]
                       withFilename:@""
                             ofType:@"audio/m4a"];
    }
}

#pragma mark - Accessory View

- (void)didPressAccessoryButton:(UIButton *)sender { // Attachment button

    BOOL preserveKeyboard = [self.inputToolbar.contentView.textView isFirstResponder];
    
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:nil
                                                                   message:nil
                                                            preferredStyle:UIAlertControllerStyleActionSheet];
    UIAlertAction *takePictureButton = [UIAlertAction actionWithTitle:NSLocalizedString(@"TAKE_MEDIA_BUTTON", @"")
                                                                style:UIAlertActionStyleDefault
                                                              handler:^(UIAlertAction *_Nonnull action){ [self takePictureOrVideo];
                                                                  if (preserveKeyboard) {
                                                                      [self popKeyBoard];
                                                                  }
                                                              }];
    UIAlertAction *chooseMediaButton = [UIAlertAction actionWithTitle:NSLocalizedString(@"CHOOSE_MEDIA_BUTTON", @"")
                                                                style:UIAlertActionStyleDefault
                                                              handler:^(UIAlertAction *_Nonnull action){ [self chooseFromLibrary];
                                                                  if (preserveKeyboard) {
                                                                      [self popKeyBoard];
                                                                  }
                                                              }];
    UIAlertAction *chooseDocutmentButton = [UIAlertAction actionWithTitle:NSLocalizedString(@"CHOOSE_FILE_BUTTON", @"")
                                                                style:UIAlertActionStyleDefault
                                                              handler:^(UIAlertAction *_Nonnull action){ [self chooseDocument];
                                                                  if (preserveKeyboard) {
                                                                      [self popKeyBoard];
                                                                  }
                                                              }];
    UIAlertAction *cancelButton = [UIAlertAction actionWithTitle:NSLocalizedString(@"TXT_CANCEL_TITLE", @"")
                                                           style:UIAlertActionStyleCancel
                                                         handler:^(UIAlertAction *_Nonnull action){
                                                             if (preserveKeyboard) {
                                                                 [self popKeyBoard];
                                                             }
                                                         }];
    [alert addAction:takePictureButton];
    [alert addAction:chooseMediaButton];
    [alert addAction:chooseDocutmentButton];
    [alert addAction:cancelButton];
    [self.navigationController presentViewController:alert animated:YES completion:nil];
}

- (void)markAllMessagesAsRead
{
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{
        [self.thread markAllAsRead];
        // In theory this should be unnecessary as read-status starts expiration
        // but in practice I've seen messages not have their timer started.
        [self.disappearingMessagesJob setExpirationsForThread:self.thread];
    });
}

- (BOOL)collectionView:(UICollectionView *)collectionView
      canPerformAction:(SEL)action
    forItemAtIndexPath:(NSIndexPath *)indexPath
            withSender:(id)sender
{
    id<OWSMessageData> messageData = [self messageAtIndexPath:indexPath];
    return [messageData canPerformEditingAction:action];
}

- (void)collectionView:(UICollectionView *)collectionView
         performAction:(SEL)action
    forItemAtIndexPath:(NSIndexPath *)indexPath
            withSender:(id)sender
{
    id<OWSMessageData> messageData = [self messageAtIndexPath:indexPath];
    [messageData performEditingAction:action];
}

- (IBAction)unwindGroupUpdated:(UIStoryboardSegue *)segue {
    [self.collectionView.collectionViewLayout
        invalidateLayoutWithContext:[JSQMessagesCollectionViewFlowLayoutInvalidationContext context]];
    [self.collectionView reloadData];
}

- (void)popKeyBoard {
    [self.inputToolbar.contentView.textView becomeFirstResponder];
}

- (void)dismissKeyBoard {
    [self.inputToolbar.contentView.textView resignFirstResponder];
}

#pragma mark Drafts

- (void)loadDraftInCompose {
    __block NSString *placeholder;
    [self.editingDatabaseConnection asyncReadWithBlock:^(YapDatabaseReadTransaction *transaction) {
        placeholder = [self.thread currentDraftWithTransaction:transaction];
    }
                                       completionBlock:^{
                                           dispatch_async(dispatch_get_main_queue(), ^{
                                               self.inputToolbar.contentView.textView.text = placeholder;
                                               [self textViewDidChange:self.inputToolbar.contentView.textView];
                                           });
                                       }];
}

- (void)saveDraft {
    if (self.inputToolbar.hidden == NO) {
        __block TSThread *thread       = _thread;
        __block NSString *currentDraft = self.inputToolbar.contentView.textView.text;

        [self.editingDatabaseConnection asyncReadWriteWithBlock:^(YapDatabaseReadWriteTransaction *transaction) {
          [thread setDraft:currentDraft transaction:transaction];
        }];
    }
}

#pragma mark Unread Badge

- (void)setUnreadCount:(NSUInteger)unreadCount {
    if (_unreadCount != unreadCount) {
        dispatch_async(dispatch_get_main_queue(), ^{
            self->_unreadCount = unreadCount;
        
            if (self->_unreadCount > 0) {
                if (self->_unreadContainer == nil) {
                    static UIImage *backgroundImage = nil;
                    static dispatch_once_t onceToken;
                    dispatch_once(&onceToken, ^{
                        UIGraphicsBeginImageContextWithOptions(CGSizeMake(17.0f, 17.0f), false, 0.0f);
                        CGContextRef context = UIGraphicsGetCurrentContext();
                        CGContextSetFillColorWithColor(context, [UIColor redColor].CGColor);
                        CGContextFillEllipseInRect(context, CGRectMake(0.0f, 0.0f, 17.0f, 17.0f));
                        backgroundImage =
                        [UIGraphicsGetImageFromCurrentImageContext() stretchableImageWithLeftCapWidth:8 topCapHeight:8];
                        UIGraphicsEndImageContext();
                    });
                    
                    self->_unreadContainer = [[UIImageView alloc] initWithFrame:CGRectMake(0.0f, 0.0f, 10.0f, 10.0f)];
                    self->_unreadContainer.userInteractionEnabled = NO;
                    self->_unreadContainer.layer.zPosition        = 2000;
                    [self.navigationController.navigationBar addSubview:self->_unreadContainer];
                    
                    self->_unreadBackground = [[UIImageView alloc] initWithImage:backgroundImage];
                    [self->_unreadContainer addSubview:self->_unreadBackground];
                    
                    self->_unreadLabel                 = [[UILabel alloc] init];
                    self->_unreadLabel.backgroundColor = [UIColor clearColor];
                    self->_unreadLabel.textColor       = [UIColor whiteColor];
                    self->_unreadLabel.font            = [UIFont systemFontOfSize:12];
                    [self->_unreadContainer addSubview:self->_unreadLabel];
                }
                self->_unreadContainer.hidden = false;
                
                self->_unreadLabel.text = [NSString stringWithFormat:@"%lu", (unsigned long)unreadCount];
                [self->_unreadLabel sizeToFit];
                
                CGPoint offset = CGPointMake(17.0f, 2.0f);
                
                self->_unreadBackground.frame =
                CGRectMake(offset.x, offset.y, MAX(self->_unreadLabel.frame.size.width + 8.0f, 17.0f), 17.0f);
                self->_unreadLabel.frame = CGRectMake(offset.x
                                                + (CGFloat)floor(
                                                                 (2.0 * (self->_unreadBackground.frame.size.width - self->_unreadLabel.frame.size.width) / 2.0f) / 2.0f),
                                                offset.y + 1.0f,
                                                self->_unreadLabel.frame.size.width,
                                                self->_unreadLabel.frame.size.height);
            } else if (self->_unreadContainer != nil) {
                self->_unreadContainer.hidden = true;
            }
        });
    }
}

#pragma mark 3D Touch Preview Actions

- (NSArray<id<UIPreviewActionItem>> *)previewActionItems {
    return @[];
}

#pragma mark - Accessors
-(UIButton *)infoButton
{
    if (_infoButton == nil) {
        _infoButton = [UIButton buttonWithType:UIButtonTypeInfoLight];
        [_infoButton addTarget:self action:@selector(showConversationSettings) forControlEvents:UIControlEventTouchUpInside];
    }
    return _infoButton;
}

-(PropertyListPreferences *)prefs
{
    if (_prefs == nil) {
        _prefs = Environment.preferences;
    }
    return _prefs;
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
