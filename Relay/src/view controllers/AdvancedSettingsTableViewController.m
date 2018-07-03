//
//  AdvancedSettingsTableViewController.m
//  Signal
//
//  Created by Dylan Bourgeois on 05/01/15.
//  Copyright (c) 2015 Open Whisper Systems. All rights reserved.
//

#import "AdvancedSettingsTableViewController.h"
#import "DebugLogger.h"
#import "Environment.h"
#import "PropertyListPreferences.h"
#import "PushManager.h"
#import "Relay-Swift.h"
#import "TSAccountManager.h"
#import <PastelogKit/Pastelog.h>
#import <PromiseKit/AnyPromise.h>

NS_ASSUME_NONNULL_BEGIN

#define kLoggingSectionIndex 0
#define kNotificationSectionIndex 1
#define kDeleteAccountSectionIndex 2

@interface AdvancedSettingsTableViewController ()

@property NSArray *sectionsArray;

@property (strong, nonatomic) UITableViewCell *enableLogCell;
@property (strong, nonatomic) UITableViewCell *submitLogCell;
@property (strong, nonatomic) UITableViewCell *registerPushCell;
@property (strong, nonatomic) UITableViewCell *deleteAccountCell;

@property (strong, nonatomic) UISwitch *enableLogSwitch;

@end

@implementation AdvancedSettingsTableViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    [self.navigationController.navigationBar setTranslucent:NO];
    self.tableView.tableFooterView = [[UIView alloc] initWithFrame:CGRectZero];
}

- (instancetype)init {
    self.sectionsArray = @[
        NSLocalizedString(@"LOGGING_SECTION", nil),
        NSLocalizedString(@"PUSH_REGISTER_TITLE", @"Used in table section header and alert view title contexts"),
        NSLocalizedString(@"ACCOUNT_SECTION", nil),
    ];

    return [super initWithStyle:UITableViewStyleGrouped];
}

- (void)loadView {
    [super loadView];

    self.title = NSLocalizedString(@"SETTINGS_ADVANCED_TITLE", @"");

    // Enable Log
    self.enableLogCell                        = [[UITableViewCell alloc] init];
    self.enableLogCell.textLabel.text         = NSLocalizedString(@"SETTINGS_ADVANCED_DEBUGLOG", @"");
    self.enableLogCell.userInteractionEnabled = YES;

    self.enableLogSwitch = [[UISwitch alloc] initWithFrame:CGRectZero];
    [self.enableLogSwitch setOn:[Environment.preferences loggingIsEnabled]];
    [self.enableLogSwitch addTarget:self
                             action:@selector(didToggleSwitch:)
                   forControlEvents:UIControlEventTouchUpInside];

    self.enableLogCell.accessoryView = self.enableLogSwitch;

    // Send Log
    self.submitLogCell                = [[UITableViewCell alloc] init];
    self.submitLogCell.textLabel.text = NSLocalizedString(@"SETTINGS_ADVANCED_SUBMIT_DEBUGLOG", @"");

    self.registerPushCell                = [[UITableViewCell alloc] init];
    self.registerPushCell.textLabel.text = NSLocalizedString(@"REREGISTER_FOR_PUSH", nil);
}

#pragma mark - Table view data source
-(CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (indexPath.section == kDeleteAccountSectionIndex && indexPath.row == 0) {
        return 80.0f;
    } else {
        return [super tableView:tableView heightForRowAtIndexPath:indexPath];
    }
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return (NSInteger)[self.sectionsArray count];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    switch (section) {
        case kLoggingSectionIndex:
            return self.enableLogSwitch.isOn ? 2 : 1;
        case kNotificationSectionIndex:
            return 1;
        case kDeleteAccountSectionIndex:
            return 1;
        default:
            return 0;
    }
}

- (nullable NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
    return [self.sectionsArray objectAtIndex:(NSUInteger)section];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    switch (indexPath.section) {
        case kLoggingSectionIndex:
            switch (indexPath.row) {
                case 0:
                    return self.enableLogCell;
                case 1:
                    return self.enableLogSwitch.isOn ? self.submitLogCell : self.registerPushCell;
            }
            break;
        case 1:
        {
            return self.registerPushCell;
        }
            break;
        case 2:
        {
            return self.deleteAccountCell;
        }
            break;
        default:
        {
            NSAssert(false, @"No Cell configured");
        }
            break;
    }
    return nil;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];

    if ([tableView cellForRowAtIndexPath:indexPath] == self.submitLogCell) {
        [Pastelog submitLogs];
    } else if ([tableView cellForRowAtIndexPath:indexPath] == self.registerPushCell) {
        OWSAccountManager *accountManager =
            [[OWSAccountManager alloc] initWithTextSecureAccountManager:[TSAccountManager sharedInstance]];
        OWSSyncPushTokensJob *syncJob = [[OWSSyncPushTokensJob alloc] initWithPushManager:[PushManager sharedManager]
                                                                           accountManager:accountManager
                                                                              preferences:[Environment preferences]];
        syncJob.uploadOnlyIfStale = NO;
        [syncJob run]
            .then(^{
                SignalAlertView(NSLocalizedString(@"PUSH_REGISTER_SUCCESS", @"Alert title"), nil);
            })
            .catch(^(NSError *error) {
                SignalAlertView(NSLocalizedString(@"REGISTRATION_BODY", @"Alert title"), error.localizedDescription);
            });

    } else {
        DDLogDebug(@"%@ Ignoring cell selection at indexPath: %@", self.tag, indexPath);
    }
}

#pragma mark - Actions

- (void)didToggleSwitch:(UISwitch *)sender {
    if (!sender.isOn) {
        [[DebugLogger sharedLogger] wipeLogs];
        [[DebugLogger sharedLogger] disableFileLogging];
    } else {
        [[DebugLogger sharedLogger] enableFileLogging];
    }

    [Environment.preferences setLoggingEnabled:sender.isOn];
    [self.tableView reloadData];
}

- (IBAction)unregisterUser:(id)sender {
    UIAlertController *alertController =
    [UIAlertController alertControllerWithTitle:NSLocalizedString(@"CONFIRM_ACCOUNT_DESTRUCTION_TITLE", @"")
                                        message:NSLocalizedString(@"CONFIRM_ACCOUNT_DESTRUCTION_TEXT", @"")
                                 preferredStyle:UIAlertControllerStyleAlert];
    [alertController addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"PROCEED_BUTTON", @"")
                                                        style:UIAlertActionStyleDestructive
                                                      handler:^(UIAlertAction *action) {
                                                          [self proceedToUnregistration];
                                                      }]];
    [alertController addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"TXT_CANCEL_TITLE", @"")
                                                        style:UIAlertActionStyleCancel
                                                      handler:nil]];
    
    [self presentViewController:alertController animated:YES completion:nil];
}

- (void)proceedToUnregistration {
    [TSAccountManager unregisterTextSecureWithSuccess:^{
        [Environment resetAppData];
    }
                                              failure:^(NSError *error) {
                                                  SignalAlertView(NSLocalizedString(@"UNREGISTER_SIGNAL_FAIL", @""), @"");
                                              }];
}

#pragma mark - Accessors
-(UITableViewCell *)deleteAccountCell
{
    if (_deleteAccountCell == nil) {
        _deleteAccountCell = [UITableViewCell new];
        //        _deleteAccountCell.backgroundColor = [UIColor clearColor];
        
        UIButton *deleteAccoutButton = [UIButton buttonWithType:UIButtonTypeSystem];
        [deleteAccoutButton setTitle:NSLocalizedString(@"SETTINGS_DELETE_ACCOUNT_BUTTON", @"") forState:UIControlStateNormal];
        [deleteAccoutButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        deleteAccoutButton.titleLabel.font = [UIFont systemFontOfSize:17.0 weight:UIFontWeightBold];
        deleteAccoutButton.backgroundColor = [ForstaColors mediumDarkRed];
        CGRect screenRect = UIScreen.mainScreen.bounds;
        deleteAccoutButton.frame = CGRectMake(screenRect.origin.x + 20,
                                              ([self tableView:self.tableView heightForRowAtIndexPath:[NSIndexPath indexPathForRow:0 inSection:2]]- _deleteAccountCell.frame.size.height)/2,
                                              screenRect.size.width - 40,
                                              _deleteAccountCell.frame.size.height);
        [deleteAccoutButton addTarget:self action:@selector(unregisterUser:) forControlEvents:UIControlEventTouchUpInside];
        [_deleteAccountCell.contentView addSubview:deleteAccoutButton];
    }
    return _deleteAccountCell;
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
