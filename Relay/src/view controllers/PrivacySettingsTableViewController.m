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
#import "SmileAuthenticator.h"

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, PrivacySettingsTableViewControllerSectionIndex) {
    PrivacySettingsTableViewControllerSectionIndexScreenSecurity,
    PrivacySettingsTableViewControllerSectionIndexRequirePIN,
    PrivacySettingsTableViewControllerSectionIndexHistoryLog,
//    PrivacySettingsTableViewControllerSectionIndexBlockOnIdentityChange
};

typedef NS_ENUM(NSInteger, PrivacySettingsPINSectionIndex) {
    PrivacySettingsPINSectionIndexRequirePIN,
    PrivacySettingsPINSectionIndexPINLength,
    PrivacySettingsPINSectionIndexPINLengthPicker,
    PrivacySettingsPINSectionIndexChangePIN,
};

@interface PrivacySettingsTableViewController () <UIPickerViewDelegate, UIPickerViewDataSource>
{
    BOOL editingPINLength;
}

@property (nonatomic, strong) UITableViewCell *enableScreenSecurityCell;
@property (nonatomic, strong) UISwitch *enableScreenSecuritySwitch;
//@property (nonatomic, strong) UITableViewCell *blockOnIdentityChangeCell;
//@property (nonatomic, strong) UISwitch *blockOnIdentityChangeSwitch;
@property (nonatomic, strong) UISwitch *onOffRecordChangeSwitch;
@property (nonatomic, strong) UITableViewCell *clearHistoryLogCell;
@property (nonatomic, strong) UISwitch *requirePINSwitch;
@property (nonatomic, strong) UITableViewCell *requirePINCell;
@property (nonatomic, strong) UITableViewCell *changePINCell;
@property (nonatomic, strong) UITableViewCell *pinLengthCell;
@property (nonatomic, strong) UITableViewCell *pinLengthPickerCell;
@property (nonatomic, strong) UIPickerView *pinLengthPickerView;
@property (nonatomic, strong) NSArray<NSNumber *> *allowedPINLengths;

@end

@implementation PrivacySettingsTableViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    [self.navigationController.navigationBar setTranslucent:NO];

    // Allowed PIN setup
    self.allowedPINLengths = @[ @(4), @(6), @(8) ];

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
    self.enableScreenSecuritySwitch.enabled = !self.enableScreenSecuritySwitch.isOn;
    [self.enableScreenSecuritySwitch setOn:Environment.preferences.screenSecurityIsEnabled];
    [self.enableScreenSecuritySwitch addTarget:self
                                        action:@selector(didToggleSettingsSwitch:)
                              forControlEvents:UIControlEventTouchUpInside];
    
    // Enable PIN Access
    self.requirePINCell                = [[UITableViewCell alloc] init];
    self.requirePINSwitch = [[UISwitch alloc] initWithFrame:CGRectZero];
    self.requirePINCell.accessoryView          = self.requirePINSwitch;
    self.requirePINCell.userInteractionEnabled = YES;
    [self.requirePINSwitch addTarget:self
                                        action:@selector(didToggleSettingsSwitch:)
                              forControlEvents:UIControlEventTouchUpInside];
    
    // Configure PIN Access Cell
    self.changePINCell                = [[UITableViewCell alloc] init];
    self.changePINCell.textLabel.text = NSLocalizedString(@"SETTINGS_CONFIGURE_PIN", @"");
    self.changePINCell.accessoryType  = UITableViewCellAccessoryDisclosureIndicator;



    // Clear History Log Cell
    self.clearHistoryLogCell                = [[UITableViewCell alloc] init];
    self.clearHistoryLogCell.textLabel.text = NSLocalizedString(@"SETTINGS_CLEAR_HISTORY", @"");
    self.clearHistoryLogCell.accessoryType  = UITableViewCellAccessoryNone;
    
    // PIN Length Cell
    self.pinLengthCell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:@"pinLength"];
    self.pinLengthCell.accessoryType = UITableViewCellAccessoryNone;
    
    // PIN Length Picker Cell
    self.pinLengthPickerCell = [UITableViewCell new];
    self.pinLengthPickerView = [UIPickerView new];
    self.pinLengthPickerView.delegate = self;
    self.pinLengthPickerView.dataSource = self;
    self.pinLengthPickerView.showsSelectionIndicator = YES;
    [self.pinLengthPickerCell.contentView addSubview:self.pinLengthPickerView];
    self.pinLengthPickerCell.contentView.hidden = !editingPINLength;

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
    return 3;
}

-(CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (indexPath.section == PrivacySettingsTableViewControllerSectionIndexRequirePIN) {
        if (indexPath.row == PrivacySettingsPINSectionIndexChangePIN) {
            if (self.requirePINSwitch.on) {
                return self.tableView.rowHeight;
            } else {
                return 0.0f;
            }
        } else if (indexPath.row == PrivacySettingsPINSectionIndexPINLengthPicker) {
            if (editingPINLength) {
                return 216.0f;
            } else {
                return 0.0f;
            }
        }
    }
    return self.tableView.rowHeight;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    switch (section) {
        case PrivacySettingsTableViewControllerSectionIndexScreenSecurity:
            return 1;
        case PrivacySettingsTableViewControllerSectionIndexRequirePIN:
            if (Environment.preferences.requirePINAccess) {
                return 4;
            } else {
                return 3;
            }
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
        case PrivacySettingsTableViewControllerSectionIndexRequirePIN:
            return NSLocalizedString(@"SETTINGS_REQUIRE_PIN_DETAIL", @"Privacy setting section foorter.  Explain PIN/TouchID access");
        default:
            return nil;
    }
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    switch (indexPath.section) {
        case PrivacySettingsTableViewControllerSectionIndexScreenSecurity:
        {
            switch (indexPath.row) {
                case 0:
                {
                    return self.enableScreenSecurityCell;
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
        case PrivacySettingsTableViewControllerSectionIndexRequirePIN:
        {
            switch (indexPath.row) {
                case PrivacySettingsPINSectionIndexPINLength:
                {
                    self.pinLengthCell.textLabel.text = NSLocalizedString(@"SETTINGS_PIN_LENGTH", nil);
                    self.pinLengthCell.detailTextLabel.text = [NSString stringWithFormat:@"%ld", Environment.preferences.PINLength];
                    if (Environment.preferences.requirePINAccess) {
                        self.pinLengthCell.userInteractionEnabled = NO;
                        self.pinLengthCell.contentView.backgroundColor = [ForstaColors lightGray];
                    } else {
                        self.pinLengthCell.userInteractionEnabled = YES;
                        self.pinLengthCell.contentView.backgroundColor = [ForstaColors whiteColor];
                    }
                    return self.pinLengthCell;
                }
                    break;
                case PrivacySettingsPINSectionIndexRequirePIN:
                {
                    self.requirePINCell.textLabel.text = NSLocalizedString(@"SETTINGS_REQUIRE_PIN", @"");
                    [self.requirePINSwitch setOn:Environment.preferences.requirePINAccess];
                    return self.requirePINCell;
                }
                    break;
                case PrivacySettingsPINSectionIndexChangePIN:
                {
                    return self.changePINCell;
                }
                    break;
                case PrivacySettingsPINSectionIndexPINLengthPicker:
                {
                    NSUInteger idx;
                    for (NSUInteger i = 0; i < self.allowedPINLengths.count ; i++) {
                        if ([(NSNumber*)[self.allowedPINLengths objectAtIndex:i] integerValue] == Environment.preferences.PINLength) {
                            idx = i;
                        }
                    }
                    [self.pinLengthPickerView selectRow:(NSInteger)idx inComponent:0 animated:YES];
                    return self.pinLengthPickerCell;
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
        case PrivacySettingsTableViewControllerSectionIndexRequirePIN:
            return NSLocalizedString(@"SETTINGS_PIN_TOUCHID_TITLE", @"Section header");
//        case PrivacySettingsTableViewControllerSectionIndexBlockOnIdentityChange:
//            return NSLocalizedString(@"SETTINGS_PRIVACY_VERIFICATION_TITLE", @"Section header");
        default:
            return nil;
    }
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    switch (indexPath.section) {
        case PrivacySettingsTableViewControllerSectionIndexRequirePIN:
        {
            switch (indexPath.row) {
                case PrivacySettingsPINSectionIndexChangePIN:
                {
                    [self dismissViewControllerAnimated:YES completion:^{
                        SmileAuthenticator.sharedInstance.securityType = INPUT_THREE;
                        [SmileAuthenticator.sharedInstance presentAuthViewControllerAnimated:YES];
                    }];
                }
                    break;
                default:
                    break;
            }
        }
            break;
        case PrivacySettingsTableViewControllerSectionIndexHistoryLog: {
            switch (indexPath.row) {
                case 0:
                {
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
                }
                    break;
                default:
                    break;
            }
        }
        default:
            break;
    }
    
    [tableView beginUpdates];
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    if (indexPath.section == PrivacySettingsTableViewControllerSectionIndexRequirePIN &&
        indexPath.row == PrivacySettingsPINSectionIndexPINLength) {
        editingPINLength = !editingPINLength;
    } else {
        editingPINLength = NO;
    }
    self.pinLengthPickerCell.contentView.hidden = !editingPINLength;
    [tableView endUpdates];
}

#pragma mark - Toggle

- (void)didToggleSettingsSwitch:(UISwitch *)sender
{
    if (self.requirePINSwitch.isOn) {
        SmileAuthenticator.sharedInstance.securityType = INPUT_TWICE;
        self.enableScreenSecuritySwitch.on = YES;
        self.enableScreenSecuritySwitch.enabled = NO;
        
    } else {
        SmileAuthenticator.sharedInstance.securityType = INPUT_ONCE;
        self.enableScreenSecuritySwitch.enabled = YES;
    }
    
//    [Environment.preferences setScreenSecurity:self.enableScreenSecuritySwitch.isOn];
//    [Environment.preferences setRequirePINAccess:self.requirePINSwitch.isOn];

    if ([sender isEqual:self.requirePINSwitch]) {
        DDLogInfo(@"%@ toggled require PIN security: %@", self.tag, self.requirePINSwitch.isOn ? @"ON" : @"OFF");
        [self dismissViewControllerAnimated:YES completion:^{
            [SmileAuthenticator.sharedInstance presentAuthViewControllerAnimated:YES];
        }];
        
    } else if ([sender isEqual:self.enableScreenSecuritySwitch]) {
        DDLogInfo(@"%@ toggled screen security: %@", self.tag, self.enableScreenSecuritySwitch.isOn ? @"ON" : @"OFF");
    }
}

//- (void)didToggleBlockOnIdentityChangeSwitch:(UISwitch *)sender
//{
//    BOOL enabled = self.blockOnIdentityChangeSwitch.isOn;
//    DDLogInfo(@"%@ toggled blockOnIdentityChange: %@", self.tag, enabled ? @"ON" : @"OFF");
//    [Environment.preferences setShouldBlockOnIdentityChange:enabled];
//}

#pragma mark - picker delegate/datasouce methods
-(NSInteger)numberOfComponentsInPickerView:(UIPickerView *)pickerView {
    return 1;
}

-(NSString *_Nullable)pickerView:(UIPickerView *)pickerView titleForRow:(NSInteger)row forComponent:(NSInteger)component
{
    return [NSString stringWithFormat:@"%ld", [(NSNumber *)[self.allowedPINLengths objectAtIndex:(NSUInteger)row] integerValue]];
}

-(NSInteger)pickerView:(UIPickerView *)pickerView numberOfRowsInComponent:(NSInteger)component
{
    return (NSInteger)[self.allowedPINLengths count];
}

-(void)pickerView:(UIPickerView *)pickerView didSelectRow:(NSInteger)row inComponent:(NSInteger)component
{
    NSInteger selectedLength = [[self.allowedPINLengths objectAtIndex:(NSUInteger)row] integerValue];
    Environment.preferences.PINLength = selectedLength;
    SmileAuthenticator.sharedInstance.passcodeDigit = selectedLength;
    [self.tableView reloadData];
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
