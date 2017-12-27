//
//  PrivacySettingsTableViewController.m
//  Signal
//
//  Created by Dylan Bourgeois on 05/01/15.
//  Copyright (c) 2015 Open Whisper Systems. All rights reserved.
//

#import "PrivacySettingsTableViewController.h"

#import "Environment.h"
#import "PropertyListPreferences.h"
#import "UIUtil.h"
#import <25519/Curve25519.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, PrivacySettingsTableViewControllerSectionIndex) {
    PrivacySettingsTableViewControllerSectionIndexScreenSecurity,
    PrivacySettingsTableViewControllerSectionIndexHistoryLog,
//    PrivacySettingsTableViewControllerSectionIndexBlockOnIdentityChange
};

@interface PrivacySettingsTableViewController ()

@property (nonatomic, strong) UITableViewCell *enableScreenSecurityCell;
@property (nonatomic, strong) UISwitch *enableScreenSecuritySwitch;
//@property (nonatomic, strong) UITableViewCell *blockOnIdentityChangeCell;
//@property (nonatomic, strong) UISwitch *blockOnIdentityChangeSwitch;
@property (nonatomic, strong) UISwitch *onOffRecordChangeSwitch;
@property (nonatomic, strong) UITableViewCell *clearHistoryLogCell;
@property (nonatomic, strong) UISwitch *requirePINSwitch;
@property (nonatomic, strong) UITableViewCell *requirePINCell;

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
    [self.enableScreenSecuritySwitch setOn:Environment.preferences.screenSecurityIsEnabled];
    [self.enableScreenSecuritySwitch addTarget:self
                                        action:@selector(didToggleSettingsSwitch:)
                              forControlEvents:UIControlEventTouchUpInside];
    
    // Enable PIN Access
    self.requirePINCell                = [[UITableViewCell alloc] init];
    self.requirePINCell.textLabel.text = NSLocalizedString(@"SETTINGS_REQUIRE_PIN", @"");
    self.requirePINSwitch = [[UISwitch alloc] initWithFrame:CGRectZero];
    self.requirePINCell.accessoryView          = self.requirePINSwitch;
    self.requirePINCell.userInteractionEnabled = YES;
    [self.requirePINSwitch setOn:Environment.preferences.requirePINAccess];
    [self.requirePINSwitch addTarget:self
                                        action:@selector(didToggleSettingsSwitch:)
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
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 2;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    switch (section) {
        case PrivacySettingsTableViewControllerSectionIndexScreenSecurity:
            return 2;
        case PrivacySettingsTableViewControllerSectionIndexHistoryLog:
            return 1;
//        case PrivacySettingsTableViewControllerSectionIndexBlockOnIdentityChange:
//            return 1;
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
        default:
            return nil;
    }
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    switch (indexPath.section) {
        case PrivacySettingsTableViewControllerSectionIndexScreenSecurity:
        {
            switch (indexPath.row) {
                case 0:
                {
                    return self.enableScreenSecurityCell;
                }
                    break;
                case 1:
                {
                    return self.requirePINCell;
                }
                    break;
                default:
                {
                    DDLogError(@"%@ Requested unknown table view cell for row at indexPath: %@", self.tag, indexPath);
                    return [UITableViewCell new];
                }
                    break;
            }
        }
            break;
        case PrivacySettingsTableViewControllerSectionIndexHistoryLog:
        {
            return self.clearHistoryLogCell;
        }
            break;
//        case PrivacySettingsTableViewControllerSectionIndexBlockOnIdentityChange:
//            return self.blockOnIdentityChangeCell;
        default:
        {
            DDLogError(@"%@ Requested unknown table view cell for row at indexPath: %@", self.tag, indexPath);
            return [UITableViewCell new];
        }
            break;
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
        default:
            return nil;
    }
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    
    switch (indexPath.section) {
        case PrivacySettingsTableViewControllerSectionIndexHistoryLog: {
            
            UIAlertController *alertSheet = [UIAlertController alertControllerWithTitle:nil
                                                                                message:NSLocalizedString(@"SETTINGS_DELETE_HISTORYLOG_CONFIRMATION", @"")
                                                                         preferredStyle:UIAlertControllerStyleActionSheet];
            [alertSheet addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"SETTINGS_DELETE_HISTORYLOG_CONFIRMATION_BUTTON", @"")
                                                           style:UIAlertActionStyleDestructive
                                                         handler:^(UIAlertAction * _Nonnull action) {
                                                             [[TSStorageManager sharedManager] deleteThreadsAndMessages];
                                                         }]];
            [alertSheet addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"TXT_CANCEL_TITLE", @"")
                                                           style:UIAlertActionStyleCancel
                                                         handler:^(UIAlertAction * _Nonnull action) {
                                                             DDLogDebug(@"User Cancelled");
                                                         }]];
            [self.parentViewController presentViewController:alertSheet animated:YES completion:^{
                [self.tableView deselectRowAtIndexPath:indexPath animated:YES];
            }];
            
            break;
        }
        default:
            break;
    }
}

#pragma mark - Toggle

- (void)didToggleSettingsSwitch:(UISwitch *)sender
{
    if ([sender isEqual:self.requirePINSwitch]) {
        BOOL enabled = self.requirePINSwitch.isOn;
        DDLogInfo(@"%@ toggled require PIN security: %@", self.tag, enabled ? @"ON" : @"OFF");
        [Environment.preferences setRequirePINAccess:enabled];
    } else if ([sender isEqual:self.enableScreenSecuritySwitch]) {
        BOOL enabled = self.enableScreenSecuritySwitch.isOn;
        DDLogInfo(@"%@ toggled screen security: %@", self.tag, enabled ? @"ON" : @"OFF");
        [Environment.preferences setScreenSecurity:enabled];
    }
}

//- (void)didToggleBlockOnIdentityChangeSwitch:(UISwitch *)sender
//{
//    BOOL enabled = self.blockOnIdentityChangeSwitch.isOn;
//    DDLogInfo(@"%@ toggled blockOnIdentityChange: %@", self.tag, enabled ? @"ON" : @"OFF");
//    [Environment.preferences setShouldBlockOnIdentityChange:enabled];
//}

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
