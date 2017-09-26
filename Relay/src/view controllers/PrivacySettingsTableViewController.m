//
//  PrivacySettingsTableViewController.m
//  Signal
//
//  Created by Dylan Bourgeois on 05/01/15.
//  Copyright (c) 2015 Open Whisper Systems. All rights reserved.
//

#import "PrivacySettingsTableViewController.h"

#import "DJWActionSheet+OWS.h"
#import "Environment.h"
#import "PropertyListPreferences.h"
#import "UIUtil.h"
#import <25519/Curve25519.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, PrivacySettingsTableViewControllerSectionIndex) {
    PrivacySettingsTableViewControllerSectionIndexScreenSecurity,
    PrivacySettingsTableViewControllerSectionIndexHistoryLog,
    PrivacySettingsTableViewControllerSectionIndexOnOffRecord
//    PrivacySettingsTableViewControllerSectionIndexBlockOnIdentityChange
};

@interface PrivacySettingsTableViewController ()

@property (nonatomic, strong) UITableViewCell *enableScreenSecurityCell;
@property (nonatomic, strong) UISwitch *enableScreenSecuritySwitch;
//@property (nonatomic, strong) UITableViewCell *blockOnIdentityChangeCell;
//@property (nonatomic, strong) UISwitch *blockOnIdentityChangeSwitch;
@property (nonatomic, strong) UITableViewCell *onOffRecordChangeCell;
@property (nonatomic, strong) UISwitch *onOffRecordChangeSwitch;
@property (nonatomic, strong) UITableViewCell *clearHistoryLogCell;

@end

@implementation PrivacySettingsTableViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    [self.navigationController.navigationBar setTranslucent:NO];

    self.tableView.tableFooterView = [[UIView alloc] initWithFrame:CGRectZero];
}

- (instancetype)init {
    return [super initWithStyle:UITableViewStyleGrouped];
}

- (void)loadView {
    [super loadView];

    self.title = NSLocalizedString(@"SETTINGS_PRIVACY_TITLE", @"");

    // Enable Screen Security Cell
    self.enableScreenSecurityCell                = [[UITableViewCell alloc] init];
    self.enableScreenSecurityCell.textLabel.text = NSLocalizedString(@"SETTINGS_SCREEN_SECURITY", @"");
    self.enableScreenSecuritySwitch = [[UISwitch alloc] initWithFrame:CGRectZero];
    self.enableScreenSecurityCell.accessoryView          = self.enableScreenSecuritySwitch;
    self.enableScreenSecurityCell.userInteractionEnabled = YES;
    [self.enableScreenSecuritySwitch setOn:[Environment.preferences screenSecurityIsEnabled]];
    [self.enableScreenSecuritySwitch addTarget:self
                                        action:@selector(didToggleScreenSecuritySwitch:)
                              forControlEvents:UIControlEventTouchUpInside];

    // Clear History Log Cell
    self.clearHistoryLogCell                = [[UITableViewCell alloc] init];
    self.clearHistoryLogCell.textLabel.text = NSLocalizedString(@"SETTINGS_CLEAR_HISTORY", @"");
    self.clearHistoryLogCell.accessoryType  = UITableViewCellAccessoryDisclosureIndicator;

//    // Block Identity on KeyChange
//    self.blockOnIdentityChangeCell = [UITableViewCell new];
//    self.blockOnIdentityChangeCell.textLabel.text
//        = NSLocalizedString(@"SETTINGS_BLOCK_ON_IDENTITY_CHANGE_TITLE", @"Table cell label");
//    self.blockOnIdentityChangeSwitch = [[UISwitch alloc] initWithFrame:CGRectZero];
//    self.blockOnIdentityChangeCell.accessoryView = self.blockOnIdentityChangeSwitch;
//    [self.blockOnIdentityChangeSwitch setOn:[Environment.preferences shouldBlockOnIdentityChange]];
//    [self.blockOnIdentityChangeSwitch addTarget:self
//                                         action:@selector(didToggleBlockOnIdentityChangeSwitch:)
//                               forControlEvents:UIControlEventTouchUpInside];
    // On-Off Record
    self.onOffRecordChangeCell = [UITableViewCell new];
    self.onOffRecordChangeCell.textLabel.text
    = NSLocalizedString(@"SETTINGS_ONTHERECORD_TITLE", @"Table cell label");
    self.onOffRecordChangeSwitch = [[UISwitch alloc] initWithFrame:CGRectZero];
    self.onOffRecordChangeCell.accessoryView = self.onOffRecordChangeSwitch;
    [self.onOffRecordChangeSwitch setOn:[Environment.preferences isOnTheRecord]];
    [self.onOffRecordChangeSwitch addTarget:self
                                         action:@selector(didToggleOnOffRecordSwitch:)
                               forControlEvents:UIControlEventTouchUpInside];
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 3;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    switch (section) {
        case PrivacySettingsTableViewControllerSectionIndexScreenSecurity:
            return 1;
        case PrivacySettingsTableViewControllerSectionIndexHistoryLog:
            return 1;
//        case PrivacySettingsTableViewControllerSectionIndexBlockOnIdentityChange:
//            return 1;
        case PrivacySettingsTableViewControllerSectionIndexOnOffRecord:
            return 1;
        default:
            return 0;
    }
}

- (nullable NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section
{
    switch (section) {
        case PrivacySettingsTableViewControllerSectionIndexScreenSecurity:
            return NSLocalizedString(@"SETTINGS_SCREEN_SECURITY_DETAIL", nil);
//        case PrivacySettingsTableViewControllerSectionIndexBlockOnIdentityChange:
//            return NSLocalizedString(
//                @"SETTINGS_BLOCK_ON_IDENITY_CHANGE_DETAIL", @"User settings section footer, a detailed explanation");
        case PrivacySettingsTableViewControllerSectionIndexOnOffRecord:
            return NSLocalizedString(@"SETTINGS_SCREEN_ONOFF_RECORD_DETAIL", nil);
        default:
            return nil;
    }
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    switch (indexPath.section) {
        case PrivacySettingsTableViewControllerSectionIndexScreenSecurity:
            return self.enableScreenSecurityCell;
        case PrivacySettingsTableViewControllerSectionIndexHistoryLog:
            return self.clearHistoryLogCell;
//        case PrivacySettingsTableViewControllerSectionIndexBlockOnIdentityChange:
//            return self.blockOnIdentityChangeCell;
        case PrivacySettingsTableViewControllerSectionIndexOnOffRecord:
            return self.onOffRecordChangeCell;
        default: {
            DDLogError(@"%@ Requested unknown table view cell for row at indexPath: %@", self.tag, indexPath);
            return [UITableViewCell new];
        }
    }
}

- (nullable NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
    switch (section) {
        case PrivacySettingsTableViewControllerSectionIndexScreenSecurity:
            return NSLocalizedString(@"SETTINGS_SECURITY_TITLE", @"Section header");
        case PrivacySettingsTableViewControllerSectionIndexHistoryLog:
            return NSLocalizedString(@"SETTINGS_HISTORYLOG_TITLE", @"Section header");
//        case PrivacySettingsTableViewControllerSectionIndexBlockOnIdentityChange:
//            return NSLocalizedString(@"SETTINGS_PRIVACY_VERIFICATION_TITLE", @"Section header");
        case PrivacySettingsTableViewControllerSectionIndexOnOffRecord:
            return NSLocalizedString(@"SETTINGS_PRIVACY_ONTHERECORD_TITLE", @"Section hearer");
        default:
            return nil;
    }
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];

    switch (indexPath.section) {
        case PrivacySettingsTableViewControllerSectionIndexHistoryLog: {
            [DJWActionSheet showInView:self.parentViewController.view
                             withTitle:NSLocalizedString(@"SETTINGS_DELETE_HISTORYLOG_CONFIRMATION", @"")
                     cancelButtonTitle:NSLocalizedString(@"TXT_CANCEL_TITLE", @"")
                destructiveButtonTitle:NSLocalizedString(@"SETTINGS_DELETE_HISTORYLOG_CONFIRMATION_BUTTON", @"")
                     otherButtonTitles:@[]
                              tapBlock:^(DJWActionSheet *actionSheet, NSInteger tappedButtonIndex) {
                                [self.tableView deselectRowAtIndexPath:indexPath animated:YES];
                                if (tappedButtonIndex == actionSheet.cancelButtonIndex) {
                                    DDLogDebug(@"User Cancelled");
                                } else if (tappedButtonIndex == actionSheet.destructiveButtonIndex) {
                                    [[TSStorageManager sharedManager] deleteThreadsAndMessages];
                                } else {
                                    DDLogDebug(@"The user tapped button at index: %li", (long)tappedButtonIndex);
                                }
                              }];

            break;
        }
        default:
            break;
    }
}

#pragma mark - Toggle

- (void)didToggleScreenSecuritySwitch:(UISwitch *)sender
{
    BOOL enabled = self.enableScreenSecuritySwitch.isOn;
    DDLogInfo(@"%@ toggled screen security: %@", self.tag, enabled ? @"ON" : @"OFF");
    [Environment.preferences setScreenSecurity:enabled];
}

//- (void)didToggleBlockOnIdentityChangeSwitch:(UISwitch *)sender
//{
//    BOOL enabled = self.blockOnIdentityChangeSwitch.isOn;
//    DDLogInfo(@"%@ toggled blockOnIdentityChange: %@", self.tag, enabled ? @"ON" : @"OFF");
//    [Environment.preferences setShouldBlockOnIdentityChange:enabled];
//}

- (void)didToggleOnOffRecordSwitch:(UISwitch *)sender
{
    BOOL enabled = self.onOffRecordChangeSwitch.isOn;
    DDLogInfo(@"%@ toggled onOffRecordChange: %@", self.tag, enabled ? @"ON" : @"OFF");
    [Environment.preferences setIsOnTheRecord:enabled];
}

#pragma mark - Log util

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
