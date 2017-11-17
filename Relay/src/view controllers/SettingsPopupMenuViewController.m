//
//  SettingsPopupMenuViewController.m
//  Forsta
//
//  Created by Mark on 6/5/17.
//  Copyright © 2017 Forsta. All rights reserved.
//

#import "SettingsPopupMenuViewController.h"
#import "DirectoryTableViewController.h"
#import "FLInvitationService.h"
#import "Environment.h"
#import "TSAccountManager.h"

#ifdef DEVELOPMENT
#define kNumberOfSettings 6
#else
#define kNumberOfSettings 5
#endif

#define kLoginInfoIndex 997
#define kInvitationIndex 0
#define kLinkedDevicesIndex 1
#define kSettingsIndex 2
#define kMarkAllReadIndex 3
#define kHelpIndex 4
#define kDeveloperConsoleIndex 5

#define kImportExportIndex 998
#define kDirectoryIndex 999

CGFloat const kRowHeight = 40;

@interface SettingsPopupMenuViewController ()

@end

@implementation SettingsPopupMenuViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    // Uncomment the following line to preserve selection between presentations.
    // self.clearsSelectionOnViewWillAppear = NO;
    
    // Uncomment the following line to display an Edit button in the navigation bar for this view controller.
    // self.navigationItem.rightBarButtonItem = self.editButtonItem;
    

}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return kNumberOfSettings;
}


- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"Cell" forIndexPath:indexPath];
    
    // Configure the cell...
    switch (indexPath.row) {
        case kInvitationIndex:
        {
            cell.textLabel.text = NSLocalizedString(@"SHARE_INVITE_USERS", @"");
        }
            break;
        case kDirectoryIndex:
        {
            cell.textLabel.text = NSLocalizedString(@"Directory", @"");
        }
            break;
        case kLinkedDevicesIndex:
        {
            cell.textLabel.text = NSLocalizedString(@"LINKED_DEVICES_TITLE", @"Menu item and navbar title for the device manager");
        }
            break;
        case kSettingsIndex:
        {
            cell.textLabel.text = NSLocalizedString(@"SETTINGS_NAV_BAR_TITLE", @"Title for settings activity");
        }
            break;
        case kMarkAllReadIndex:
        {
            cell.textLabel.text = NSLocalizedString(@"Mark all read", @"");
        }
            break;
        case kImportExportIndex:
        {
            cell.textLabel.text = NSLocalizedString(@"Import / export", @"");
        }
            break;
        case kHelpIndex:
        {
            cell.textLabel.text = NSLocalizedString(@"Help", @"");
        }
            break;
        case kDeveloperConsoleIndex:
        {
            cell.textLabel.text = NSLocalizedString(@"Debug Dashboard", @"");
        }
            break;
        case kLoginInfoIndex:
        {
            SignalRecipient *myself = TSAccountManager.sharedInstance.myself;
            cell.textLabel.textColor = [ForstaColors mediumDarkBlue2];
            cell.textLabel.adjustsFontSizeToFitWidth= YES;
            cell.textLabel.text = [NSString stringWithFormat:@"%@@%@:%@", NSLocalizedString(@"Logged In As: ", @""), myself.flTag.slug, myself.orgSlug];
        }
            break;
        default:
        {
            cell.textLabel.text = @"Undefine Row";
        }
            break;
    }
    
    return cell;
}


/*
// Override to support conditional editing of the table view.
- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
    // Return NO if you do not want the specified item to be editable.
    return YES;
}
*/

/*
// Override to support editing the table view.
- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath {
    if (editingStyle == UITableViewCellEditingStyleDelete) {
        // Delete the row from the data source
        [tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationFade];
    } else if (editingStyle == UITableViewCellEditingStyleInsert) {
        // Create a new instance of the appropriate class, insert it into the array, and add a new row to the table view
    }   
}
*/

/*
// Override to support rearranging the table view.
- (void)tableView:(UITableView *)tableView moveRowAtIndexPath:(NSIndexPath *)fromIndexPath toIndexPath:(NSIndexPath *)toIndexPath {
}
*/

/*
// Override to support conditional rearranging of the table view.
- (BOOL)tableView:(UITableView *)tableView canMoveRowAtIndexPath:(NSIndexPath *)indexPath {
    // Return NO if you do not want the item to be re-orderable.
    return YES;
}
*/



#pragma mark - Navigation
-(void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    switch (indexPath.row) {
        case kInvitationIndex :  //  Invite people
        {
            // dismiss self
            [self dismissViewControllerAnimated:YES completion:nil];
            
            // get top controller
            UINavigationController *navController = (UINavigationController *)[[[[UIApplication sharedApplication] delegate] window] rootViewController];
            UIViewController *vc = [navController topViewController];

            // Call service to make the invitation
            [[[Environment getCurrent] invitationService] inviteUsersFrom:vc];
        }
            break;
        case kDirectoryIndex:  //         Directory selected
        {
            [self performSegueWithIdentifier:@"directorySegue" sender:[tableView cellForRowAtIndexPath:indexPath] ];
        }
            break;
        case kSettingsIndex:  //  Settings selected
        {
            [self performSegueWithIdentifier:@"SettingsSegue" sender:[tableView cellForRowAtIndexPath:indexPath]];
        }
            break;
        case kDeveloperConsoleIndex:  //  Developer console
        {
            [self performSegueWithIdentifier:@"DeveloperPanelSegue" sender:[tableView cellForRowAtIndexPath:indexPath]];
        }
            break;
        case kLinkedDevicesIndex:
        {
            [self performSegueWithIdentifier:@"LinkedDevicesSegue" sender:[tableView cellForRowAtIndexPath:indexPath]];
        }
            break;
        case kHelpIndex:
        {
            [[UIApplication sharedApplication] openURL:[NSURL URLWithString:FLForstaSupportURL]];
            [self dismissViewControllerAnimated:YES completion:nil];
        }
            break;
        case kMarkAllReadIndex:
        {
            [[NSNotificationCenter defaultCenter] postNotificationName:FLMarkAllReadNotification object:nil userInfo:nil];
            [self dismissViewControllerAnimated:YES completion:nil];
        }
            break;
        default:
            break;
    }
    
    [self.tableView deselectRowAtIndexPath:indexPath animated:YES];
}
/*
// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/

-(CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    return kRowHeight;
}

#pragma mark - Unwind action
- (IBAction)unwindToSettings:(UIStoryboardSegue *)unwindSegue
{
}


#pragma mark - convenience method for getting overall table heigh
-(CGFloat)heightForTableView;
{
    CGFloat numRows = [self tableView:self.tableView numberOfRowsInSection:1];
    return numRows * kRowHeight;
}

#pragma mark - Lazy instantiation

@end
