//
//  SettingsTableViewController.h
//  Signal
//
//  Created by Dylan Bourgeois on 03/11/14.
//  Copyright (c) 2014 Open Whisper Systems. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface SettingsTableViewController : UITableViewController

@property (weak, nonatomic) IBOutlet UILabel *registeredName;
@property (weak, nonatomic) IBOutlet UILabel *registeredNumber;
@property (weak, nonatomic) IBOutlet UILabel *networkStatusLabel;
@property (weak, nonatomic) IBOutlet UILabel *networkStatusHeader;
@property (weak, nonatomic) IBOutlet UILabel *privacyLabel;
@property (weak, nonatomic) IBOutlet UILabel *notificationsLabel;
@property (weak, nonatomic) IBOutlet UILabel *linkedDevicesLabel;
@property (weak, nonatomic) IBOutlet UILabel *advancedLabel;
@property (weak, nonatomic) IBOutlet UILabel *aboutLabel;
@property (weak, nonatomic) IBOutlet UIButton *destroyAccountButton;
@property (weak, nonatomic) IBOutlet UILabel *appearanceLabel;

- (IBAction)unregisterUser:(id)sender;

@end
