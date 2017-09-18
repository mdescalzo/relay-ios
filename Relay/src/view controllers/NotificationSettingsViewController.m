//
//  NotificationPreviewViewController.m
//  Signal
//
//  Created by Frederic Jacobs on 09/12/14.
//  Copyright (c) 2014 Open Whisper Systems. All rights reserved.
//

#import "NotificationSettingsViewController.h"

#import "Environment.h"
#import "NotificationSettingsOptionsViewController.h"
#import "PropertyListPreferences.h"

@interface NotificationSettingsViewController ()

@property NSArray *notificationsSections;

@end

@implementation NotificationSettingsViewController

- (instancetype)init {
    return [super initWithStyle:UITableViewStyleGrouped];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    [self setTitle:NSLocalizedString(@"SETTINGS_NOTIFICATIONS", nil)];


    self.notificationsSections = @[
        NSLocalizedString(@"NOTIFICATIONS_SECTION_BACKGROUND", nil),
        NSLocalizedString(@"NOTIFICATIONS_SECTION_INAPP", nil)
    ];
}

- (void)viewDidAppear:(BOOL)animated {
    [self.tableView reloadData];
}

#pragma mark - Table view data source

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    return [self.notificationsSections objectAtIndex:(NSUInteger)section];
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return (NSInteger)self.notificationsSections.count;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    switch (section) {
        case 0:
            return 2;
            break;
        case 1:
            return 1;
            break;
        default:
            return 0;
            break;
    }
//    return 1;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    NSString *cellIdentifier = @"SignalTableViewCellIdentifier";
    UITableViewCell *cell    = [tableView dequeueReusableCellWithIdentifier:cellIdentifier];

    if (cell == nil) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:cellIdentifier];
    }

    PropertyListPreferences *prefs = Environment.preferences;
    if (indexPath.section == 0) {
        switch (indexPath.row) {
            case 0:
            {
                NotificationType notifType = [prefs notificationPreviewType];
                NSString *detailString     = [prefs nameForNotificationPreviewType:notifType];
                
                [[cell textLabel] setText:NSLocalizedString(@"NOTIFICATIONS_SHOW", nil)];
                [[cell detailTextLabel] setText:detailString];
                [cell setAccessoryType:UITableViewCellAccessoryDisclosureIndicator];
            }
                break;
            case 1:
            {
                BOOL soundEnabled = [prefs soundInBackground];
                
                [[cell textLabel] setText:NSLocalizedString(@"NOTIFICATIONS_SOUND", nil)];
                [[cell detailTextLabel] setText:nil];
                UISwitch *switchv = [[UISwitch alloc] initWithFrame:CGRectZero];
                switchv.on        = soundEnabled;
                [switchv addTarget:self
                            action:@selector(didToggleSoundNotificationsSwitch:)
                  forControlEvents:UIControlEventValueChanged];
                
                cell.accessoryView = switchv;
            }
                break;
            default:
            {
                DDLogDebug(@"Undefined notification cell.");
            }
                break;
        }
    } else {
        BOOL soundEnabled = [prefs soundInForeground];

        [[cell textLabel] setText:NSLocalizedString(@"IN-APP_SOUND", nil)];
        [[cell detailTextLabel] setText:nil];
        UISwitch *switchv = [[UISwitch alloc] initWithFrame:CGRectZero];
        switchv.on        = soundEnabled;
        [switchv addTarget:self
                      action:@selector(didToggleSoundInAppSoundSwitch:)
            forControlEvents:UIControlEventValueChanged];

        cell.accessoryView = switchv;
    }

    return cell;
}

- (void)didToggleSoundInAppSoundSwitch:(UISwitch *)sender {
    [Environment.preferences setSoundInForeground:sender.on];
}
- (void)didToggleSoundNotificationsSwitch:(UISwitch *)sender {
    [Environment.preferences setSoundInBackground:sender.on];
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    switch (indexPath.section) {
        case 0:
        {
            switch (indexPath.row) {
                case 0:
                {
                    NotificationSettingsOptionsViewController *vc =
                    [[NotificationSettingsOptionsViewController alloc] initWithStyle:UITableViewStyleGrouped];
                    [self.navigationController pushViewController:vc animated:YES];
                }
                    break;
                case 1:
                {
                    UITableViewCell *cell = [tableView cellForRowAtIndexPath:indexPath];
                    UISwitch *soundSwitch = (UISwitch *)cell.accessoryView;
                    soundSwitch.on = !soundSwitch.on;
                    [self didToggleSoundNotificationsSwitch:soundSwitch];
                }
                    break;
                default:
                {
                    DDLogDebug(@"Undefined notification setting selected.");
                }
                    break;
            }
        }
            break;
        case 1:
        {
            UITableViewCell *cell = [tableView cellForRowAtIndexPath:indexPath];
            UISwitch *soundSwitch = (UISwitch *)cell.accessoryView;
            soundSwitch.on = !soundSwitch.on;
            [self didToggleSoundInAppSoundSwitch:soundSwitch];
        }
            break;
        default:
        {
            DDLogDebug(@"Undefined notification setting selected.");
        }
    }
}

- (void)tableView:(UITableView *)tableView didDeselectRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [self.tableView cellForRowAtIndexPath:indexPath];
    cell.accessoryType    = UITableViewCellAccessoryNone;
}

@end
