//  Created by Michael Kirk on 9/21/16.
//  Copyright © 2016 Open Whisper Systems. All rights reserved.

#import "ConversationSettingsViewController.h"
#import "Environment.h"
#import "FingerprintViewController.h"
#import "ConversationUpdateViewController.h"
#import "OWSAvatarBuilder.h"
#import "FLContactsManager.h"
#import "PhoneNumber.h"
#import "ShowGroupMembersViewController.h"
#import "UIFont+OWS.h"
#import "UIUtil.h"
#import <Curve25519Kit/Curve25519.h>
#import "NSDate+millisecondTimeStamp.h"
#import "OWSDisappearingConfigurationUpdateInfoMessage.h"
#import "OWSDisappearingMessagesConfiguration.h"
#import "OWSFingerprint.h"
#import "OWSFingerprintBuilder.h"
#import "FLMessageSender.h"
#import "OWSNotifyRemoteOfUpdatedDisappearingConfigurationJob.h"
#import "TSOutgoingMessage.h"
#import "TSStorageManager.h"
#import "TSAccountManager.h"
#import "TSThread.h"
#import "FLControlMessage.h"

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSUInteger, ConversationSettingsViewControllerSection) {
    ConversationSettingsViewControllerSectionContact,
    ConversationSettingsViewControllerSectionGroup
};

typedef NS_ENUM(NSUInteger, ConversationSettingsViewControllerContactCellIndex) {
    ConversationSettingsViewControllerCellIndexShowFingerprint,
    ConversationSettingsViewControllerCellIndexToggleDisappearingMessages,
    ConversationSettingsViewControllerCellIndexSetDisappearingMessagesDuration
};

typedef NS_ENUM(NSUInteger, ConversationSettingsViewControllerGroupCellIndex) {
    ConversationSettingsViewControllerCellIndexUpdateGroup,
    ConversationSettingsViewControllerCellIndexLeaveGroup,
    ConversationSettingsViewControllerCellIndexSeeGroupMembers
};

static NSString *const ConversationSettingsViewControllerSegueUpdateGroup =
@"ConversationSettingsViewControllerSegueUpdateGroup";
static NSString *const ConversationSettingsViewControllerSegueShowGroupMembers =
@"ConversationSettingsViewControllerSegueShowGroupMembers";

@interface ConversationSettingsViewController ()

@property (strong, nonatomic) IBOutlet UITableViewCell *verifyPrivacyCell;
@property (strong, nonatomic) IBOutlet UITableViewCell *toggleDisappearingMessagesCell;
@property (strong, nonatomic) IBOutlet UILabel *toggleDisappearingMessagesTitleLabel;
@property (strong, nonatomic) IBOutlet UILabel *toggleDisappearingMessagesDescriptionLabel;
@property (strong, nonatomic) IBOutlet UISwitch *disappearingMessagesSwitch;
@property (strong, nonatomic) IBOutlet UITableViewCell *disappearingMessagesDurationCell;
@property (strong, nonatomic) IBOutlet UILabel *disappearingMessagesDurationLabel;
@property (strong, nonatomic) IBOutlet UISlider *disappearingMessagesDurationSlider;

@property (strong, nonatomic) IBOutlet UITableViewCell *updateGroupCell;
@property (strong, nonatomic) IBOutlet UITableViewCell *leaveGroupCell;
@property (strong, nonatomic) IBOutlet UITableViewCell *listGroupMembersCell;
@property (strong, nonatomic) IBOutlet UIImageView *avatar;
@property (strong, nonatomic) IBOutlet UILabel *nameLabel;
@property (strong, nonatomic) IBOutlet UILabel *signalIdLabel;
@property (strong, nonatomic) IBOutletCollection(UIImageView) NSArray *cellIcons;

@property (nonatomic) TSThread *thread;
@property (nonatomic) NSString *contactName;
//@property (nonatomic) NSString *signalId;
@property (nonatomic) UIImage *avatarImage;
@property (nonatomic) BOOL isGroupThread;

@property (nonatomic) NSArray<NSNumber *> *disappearingMessagesDurations;
@property (nonatomic) OWSDisappearingMessagesConfiguration *disappearingMessagesConfiguration;

@property (nonatomic, readonly) TSStorageManager *storageManager;
@property (nonatomic, readonly) FLContactsManager *contactsManager;
@property (nonatomic, readonly) FLMessageSender *messageSender;

@end

@implementation ConversationSettingsViewController

- (instancetype)init
{
    self = [super init];
    if (!self) {
        return self;
    }
    
    _storageManager = [TSStorageManager sharedManager];
    _contactsManager = [Environment getCurrent].contactsManager;
    _messageSender = [[FLMessageSender alloc] initWithNetworkManager:[Environment getCurrent].networkManager
                                                       storageManager:_storageManager
                                                      contactsManager:_contactsManager];
    return self;
}

- (nullable instancetype)initWithCoder:(NSCoder *)aDecoder
{
    self = [super initWithCoder:aDecoder];
    if (!self) {
        return self;
    }
    
    _storageManager = [TSStorageManager sharedManager];
    _contactsManager = [Environment getCurrent].contactsManager;
    _messageSender = [[FLMessageSender alloc] initWithNetworkManager:[Environment getCurrent].networkManager
                                                       storageManager:_storageManager
                                                      contactsManager:_contactsManager];
    return self;
}

- (void)configureWithThread:(TSThread *)thread
{
    self.thread = thread;
    self.contactName = thread.displayName;
    
    self.isGroupThread = YES;
    if (self.contactName.length == 0) {
        self.contactName = NSLocalizedString(@"NEW_GROUP_DEFAULT_TITLE", @"");
    }
}

#pragma mark - View Lifecycle

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    self.nameLabel.text = self.contactName;
    self.signalIdLabel.text = nil;
    
    if (self.thread.image) {
        self.avatar.image = self.thread.image;
    } else {
        self.avatar.image = [OWSAvatarBuilder buildImageForThread:self.thread contactsManager:self.contactsManager diameter:self.avatar.frame.size.height];
    }
    
    self.nameLabel.font = [UIFont ows_dynamicTypeTitle2Font];
    
    // Translations
    self.title = NSLocalizedString(@"CONVERSATION_SETTINGS", @"title for conversation settings screen");
    self.verifyPrivacyCell.textLabel.text
    = NSLocalizedString(@"VERIFY_PRIVACY", @"table cell label in conversation settings");
    self.toggleDisappearingMessagesTitleLabel.text
    = NSLocalizedString(@"DISAPPEARING_MESSAGES", @"table cell label in conversation settings");
    self.toggleDisappearingMessagesDescriptionLabel.text
    = NSLocalizedString(@"DISAPPEARING_MESSAGES_DESCRIPTION", @"subheading in conversation settings");
    self.updateGroupCell.textLabel.text
    = NSLocalizedString(@"EDIT_GROUP_ACTION", @"table cell label in conversation settings");
    self.leaveGroupCell.textLabel.text
    = NSLocalizedString(@"LEAVE_GROUP_ACTION", @"table cell label in conversation settings");
    self.listGroupMembersCell.textLabel.text
    = NSLocalizedString(@"LIST_GROUP_MEMBERS_ACTION", @"table cell label in conversation settings");
    
    self.toggleDisappearingMessagesCell.selectionStyle = UITableViewCellSelectionStyleNone;
    self.disappearingMessagesDurationCell.selectionStyle = UITableViewCellSelectionStyleNone;
    
    self.disappearingMessagesDurations = [OWSDisappearingMessagesConfiguration validDurationsSeconds];
    self.disappearingMessagesDurationSlider.maximumValue = (float)(self.disappearingMessagesDurations.count - 1);
    self.disappearingMessagesDurationSlider.minimumValue = 0;
    self.disappearingMessagesDurationSlider.continuous = YES; // NO fires change event only once you let go
    
    self.disappearingMessagesConfiguration =
    [OWSDisappearingMessagesConfiguration fetchObjectWithUniqueID:self.thread.uniqueId];
    
    if (!self.disappearingMessagesConfiguration) {
        self.disappearingMessagesConfiguration =
        [[OWSDisappearingMessagesConfiguration alloc] initDefaultWithThreadId:self.thread.uniqueId];
    }
    
    self.disappearingMessagesDurationSlider.value = self.disappearingMessagesConfiguration.durationIndex;
    [self toggleDisappearingMessages:self.disappearingMessagesConfiguration.isEnabled];
    
    // RADAR http://www.openradar.me/23759908
    // Finding that occasionally the tabel icons are not being tinted
    // i.e. rendered as white making them invisible.
    for (UIImageView *cellIcon in self.cellIcons) {
        [cellIcon tintColorDidChange];
    }
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    // HACK to unselect rows when swiping back
    // http://stackoverflow.com/questions/19379510/uitableviewcell-doesnt-get-deselected-when-swiping-back-quickly
    [self.tableView deselectRowAtIndexPath:[self.tableView indexPathForSelectedRow] animated:animated];
}

- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
    
    if (self.disappearingMessagesConfiguration.isNewRecord && !self.disappearingMessagesConfiguration.isEnabled) {
        // don't save defaults, else we'll unintentionally save the configuration and notify the contact.
        return;
    }
    
    if (self.disappearingMessagesConfiguration.dictionaryValueDidChange) {
        [self.disappearingMessagesConfiguration save];
        OWSDisappearingConfigurationUpdateInfoMessage *infoMessage =
        [[OWSDisappearingConfigurationUpdateInfoMessage alloc]
         initWithTimestamp:[NSDate ows_millisecondTimeStamp]
         thread:self.thread
         configuration:self.disappearingMessagesConfiguration];
        [infoMessage save];
        
        [OWSNotifyRemoteOfUpdatedDisappearingConfigurationJob
         runWithConfiguration:self.disappearingMessagesConfiguration
         thread:self.thread
         messageSender:self.messageSender];
    }
}

- (void)viewDidLayoutSubviews
{
    // Round avatar corners.
    self.avatar.layer.borderColor = UIColor.clearColor.CGColor;
    self.avatar.layer.masksToBounds = YES;
    self.avatar.layer.cornerRadius = self.avatar.frame.size.height / 2.0f;
}

#pragma mark - UITableViewDelegate

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    NSInteger baseCount = [super tableView:tableView numberOfRowsInSection:section];
    
    if (section == ConversationSettingsViewControllerSectionGroup) {
        if (self.isGroupThread) {
            return baseCount;
        } else {
            return 0;
        }
    }
    
    if (section == ConversationSettingsViewControllerSectionContact) {
        if (!self.thread.hasSafetyNumbers) {
            baseCount -= 1;
        }
        
        if (!self.disappearingMessagesSwitch.isOn) {
            // hide duration slider when disappearing messages is off.
            baseCount -= 1;
        }
    }
    return baseCount;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(nonnull NSIndexPath *)indexPath
{
    if (indexPath.section == ConversationSettingsViewControllerSectionContact
        && !self.thread.hasSafetyNumbers) {
        
        // Since fingerprint cell is hidden for some threads we offset our index path
        NSIndexPath *offsetIndexPath = [NSIndexPath indexPathForRow:indexPath.row + 1 inSection:indexPath.section];
        return [super tableView:tableView cellForRowAtIndexPath:offsetIndexPath];
    }
    
    return [super tableView:tableView cellForRowAtIndexPath:indexPath];
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    UITableViewCell *cell = [self tableView:tableView cellForRowAtIndexPath:indexPath];
    
    // group vs. contact thread have some cells slider at different index.
    if (cell == self.disappearingMessagesDurationCell) {
        NSIndexPath *originalIndexPath = [NSIndexPath
                                          indexPathForRow:ConversationSettingsViewControllerCellIndexSetDisappearingMessagesDuration
                                          inSection:ConversationSettingsViewControllerSectionContact];
        
        return [super tableView:tableView heightForRowAtIndexPath:originalIndexPath];
    }
    if (cell == self.toggleDisappearingMessagesCell) {
        NSIndexPath *originalIndexPath =
        [NSIndexPath indexPathForRow:ConversationSettingsViewControllerCellIndexToggleDisappearingMessages
                           inSection:ConversationSettingsViewControllerSectionContact];
        
        return [super tableView:tableView heightForRowAtIndexPath:originalIndexPath];
    } else {
        return [super tableView:tableView heightForRowAtIndexPath:indexPath];
    }
}

// Called before the user changes the selection. Return a new indexPath, or nil, to change the proposed selection.
- (nullable NSIndexPath *)tableView:(UITableView *)tableView willSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    UITableViewCell *cell = [tableView cellForRowAtIndexPath:indexPath];
    
    // Don't highlight rows that have no selection style.
    if (cell.selectionStyle == UITableViewCellSelectionStyleNone) {
        return nil;
    }
    return indexPath;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (indexPath.section == ConversationSettingsViewControllerSectionGroup
        && indexPath.row == ConversationSettingsViewControllerCellIndexLeaveGroup) {
        
        [self didTapLeaveConversation];
    }
}

- (nullable NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
    if (section == ConversationSettingsViewControllerSectionGroup) {
        if (self.isGroupThread) {
            return NSLocalizedString(@"GROUP_MANAGEMENT_SECTION", @"Conversation settings table section title");
        } else {
            return nil;
        }
    } else {
        return [super tableView:tableView titleForHeaderInSection:section];
    }
}

#pragma mark - Actions

- (void)didTapLeaveConversation
{
    UIAlertController *alertController =
    [UIAlertController alertControllerWithTitle:NSLocalizedString(@"CONFIRM_LEAVE_GROUP_TITLE", @"Alert title")
                                        message:NSLocalizedString(@"CONFIRM_LEAVE_GROUP_DESCRIPTION", @"Alert body")
                                 preferredStyle:UIAlertControllerStyleAlert];
    
    UIAlertAction *leaveAction = [UIAlertAction
                                  actionWithTitle:NSLocalizedString(@"LEAVE_BUTTON_TITLE", @"Confirmation button within contextual alert")
                                  style:UIAlertActionStyleDestructive
                                  handler:^(UIAlertAction *_Nonnull action) {
                                      [self leaveConversation];
                                  }];
    [alertController addAction:leaveAction];
    
    UIAlertAction *cancelAction = [UIAlertAction
                                   actionWithTitle:NSLocalizedString(@"TXT_CANCEL_TITLE", nil)
                                   style:UIAlertActionStyleCancel
                                   handler:^(UIAlertAction *_Nonnull action) {
                                       [self.tableView deselectRowAtIndexPath:[self.tableView indexPathForSelectedRow] animated:YES];
                                   }];
    [alertController addAction:cancelAction];
    
    [self presentViewController:alertController animated:YES completion:nil];
}

- (void)leaveConversation
{
    // Throw a threadDelete control message and remove self
    [self.thread.writeDbConnection asyncReadWriteWithBlock:^(YapDatabaseReadWriteTransaction * _Nonnull transaction) {
        [self.thread removeParticipants:[NSSet setWithObject:TSAccountManager.sharedInstance.myself.flTag.uniqueId] transaction:transaction];
    } completionBlock:^{
        FLControlMessage *message = [[FLControlMessage alloc] initControlMessageForThread:self.thread
                                                                                   ofType:FLControlMessageThreadUpdateKey];
        [Environment.getCurrent.messageSender sendMessage:message
                                                  success:^{
                                                      DDLogInfo(@"%@ Successfully left group.", self.tag);
                                                      [self.thread.writeDbConnection asyncReadWriteWithBlock:^(YapDatabaseReadWriteTransaction * _Nonnull transaction) {
                                                          TSInfoMessage *leavingMessage = [[TSInfoMessage alloc] initWithTimestamp:[NSDate ows_millisecondTimeStamp]
                                                                                                                          inThread:self.thread
                                                                                                                       messageType:TSInfoMessageTypeConversationQuit];
                                                          [leavingMessage saveWithTransaction:transaction];
                                                      } completionBlock:^{
                                                          [self.thread removeParticipants:[NSSet setWithObject:TSAccountManager.sharedInstance.myself.flTag.uniqueId]];
                                                      }];
                                                  }
                                                  failure:^(NSError *error) {
                                                      DDLogWarn(@"%@ Failed to leave group with error: %@", self.tag, error);
                                                      NSString *alertString = [NSString stringWithFormat:@"%@\n\n%@", NSLocalizedString(@"GROUP_REMOVING_FAILED", @""), error.localizedDescription];
                                                      UIAlertController *alert = [UIAlertController alertControllerWithTitle:nil
                                                                                                                     message:alertString
                                                                                                              preferredStyle:UIAlertControllerStyleAlert];
                                                      UIAlertAction *okAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"OK", @"")
                                                                                                         style:UIAlertActionStyleDefault
                                                                                                       handler:^(UIAlertAction *action) {}];
                                                      [alert addAction:okAction];
                                                      [self.navigationController presentViewController:alert animated:YES completion:nil];
                                                  }];
    }];
    
    [self.navigationController popViewControllerAnimated:YES];
}

- (void)presentedModalWasDismissed
{
    // Else row stays selected after dismissing modal.
    [self.tableView deselectRowAtIndexPath:[self.tableView indexPathForSelectedRow] animated:YES];
}

- (IBAction)disappearingMessagesSwitchValueDidChange:(id)sender
{
    if (![sender isKindOfClass:[UISwitch class]]) {
        DDLogError(@"%@ Unexpected sender for disappearing messages switch: %@", self.tag, sender);
    }
    UISwitch *disappearingMessagesSwitch = (UISwitch *)sender;
    [self toggleDisappearingMessages:disappearingMessagesSwitch.isOn];
}

- (void)toggleDisappearingMessages:(BOOL)flag
{
    self.disappearingMessagesConfiguration.enabled = flag;
    
    // When this message is called as a result of the switch being flipped, this will be a no-op
    // but it allows us to resuse the method to set the switch programmatically in view setup.
    self.disappearingMessagesSwitch.on = flag;
    [self durationSliderDidChange:self.disappearingMessagesDurationSlider];
    
    // Animate show/hide of duration settings.
    if (flag) {
        [self.tableView insertRowsAtIndexPaths:@[ self.indexPathForDurationSlider ]
                              withRowAnimation:UITableViewRowAnimationFade];
    } else {
        [self.tableView deleteRowsAtIndexPaths:@[ self.indexPathForDurationSlider ]
                              withRowAnimation:UITableViewRowAnimationFade];
    }
}

- (NSIndexPath *)indexPathForDurationSlider
{
    if (!self.thread.hasSafetyNumbers) {
        return [NSIndexPath
                indexPathForRow:ConversationSettingsViewControllerCellIndexSetDisappearingMessagesDuration - 1
                inSection:ConversationSettingsViewControllerSectionContact];
    } else {
        return [NSIndexPath
                indexPathForRow:ConversationSettingsViewControllerCellIndexSetDisappearingMessagesDuration
                inSection:ConversationSettingsViewControllerSectionContact];
    }
}

- (IBAction)durationSliderDidChange:(UISlider *)slider
{
    // snap the slider to a valid value
    NSUInteger index = (NSUInteger)(slider.value + 0.5);
    [slider setValue:index animated:YES];
    NSNumber *numberOfSeconds = self.disappearingMessagesDurations[index];
    self.disappearingMessagesConfiguration.durationSeconds = [numberOfSeconds unsignedIntValue];
    
    if (self.disappearingMessagesConfiguration.isEnabled) {
        NSString *keepForFormat = NSLocalizedString(@"KEEP_MESSAGES_DURATION",
                                                    @"Slider label embeds {{TIME_AMOUNT}}, e.g. '2 hours'. See *_TIME_AMOUNT strings for examples.");
        self.disappearingMessagesDurationLabel.text =
        [NSString stringWithFormat:keepForFormat, self.disappearingMessagesConfiguration.durationString];
    } else {
        self.disappearingMessagesDurationLabel.text
        = NSLocalizedString(@"KEEP_MESSAGES_FOREVER", @"Slider label when disappearing messages is off");
    }
}

#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(nullable id)sender
{
    if ([segue.destinationViewController isKindOfClass:[FingerprintViewController class]]) {
        FingerprintViewController *controller = (FingerprintViewController *)segue.destinationViewController;
        
        OWSFingerprintBuilder *fingerprintBuilder =
        [[OWSFingerprintBuilder alloc] initWithStorageManager:self.storageManager
                                              contactsManager:self.contactsManager];
        NSString *otherId = nil;
        for (NSString *uid in self.thread.participants) {
            if (![uid isEqualToString:TSAccountManager.sharedInstance.myself.uniqueId]) {
                otherId = uid;
                break;
            }
        }
        OWSFingerprint *fingerprint = [fingerprintBuilder fingerprintWithTheirSignalId:otherId];
        
        [controller configureWithThread:self.thread fingerprint:fingerprint contactName:self.contactName];
        controller.dismissDelegate = self;
    } else if ([segue.identifier isEqualToString:ConversationSettingsViewControllerSegueUpdateGroup]) {
        ConversationUpdateViewController *vc = [segue destinationViewController];
        [vc configWithThread:(TSThread *)self.thread];
    } else if ([segue.identifier isEqualToString:ConversationSettingsViewControllerSegueShowGroupMembers]) {
        ShowGroupMembersViewController *vc = [segue destinationViewController];
        [vc configWithThread:(TSThread *)self.thread];
    }
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

NS_ASSUME_NONNULL_END
