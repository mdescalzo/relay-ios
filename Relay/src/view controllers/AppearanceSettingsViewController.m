//
//  AppearanceSettingsViewController.m
//  Forsta
//
//  Created by Mark Descalzo on 12/18/17.
//  Copyright © 2017 Forsta. All rights reserved.
//

#import "AppearanceSettingsViewController.h"

@interface AppearanceSettingsViewController ()

@property (nonatomic, strong) NSArray *sectionsHeadings;

@end

@implementation AppearanceSettingsViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.title = NSLocalizedString(@"SETTINGS_APPEARANCE", nil);


}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - Table view data source
- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    return [self.sectionsHeadings objectAtIndex:(NSUInteger)section];
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return (NSInteger)self.sectionsHeadings.count;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    switch (section) {
        case 0:  // Gravatar section
            return 1;
            break;
        case 1: // Messages section
            return 2;
            break;
        default:
            return 0;
            break;
    }
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    NSString *cellIdentifier = @"SignalTableViewCellIdentifier";
    UITableViewCell *cell    = [tableView dequeueReusableCellWithIdentifier:cellIdentifier];
    
    if (cell == nil) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:cellIdentifier];
    }

    // Configure the cell...
    PropertyListPreferences *prefs = Environment.preferences;
    switch (indexPath.section) {
        case 0:  // Gravatars
        {
            switch (indexPath.row) {
                case 0:
                {
                    BOOL gravatarEnabled = prefs.useGravatars;
                    
                    cell.textLabel.text = NSLocalizedString(@"APPEARANCE_USE_GRAVATARS", nil);
                    cell.detailTextLabel.text = nil;
                    UISwitch *switchv = [[UISwitch alloc] initWithFrame:CGRectZero];
                    switchv.on = gravatarEnabled;
                    [switchv addTarget:self
                                action:@selector(didToggleSoundGravatarSwitch:)
                      forControlEvents:UIControlEventValueChanged];
                    cell.accessoryView = switchv;
                }
                    break;
                default:
                    break;
            }
        }
            break;
        case 1:  // Message bubbles
        {
            switch (indexPath.row) {
                case 0:
                {
                    cell.textLabel.text = NSLocalizedString(@"APPEARANCE_MESSAGE_BUBBLE_COLOR", nil);
                    cell.detailTextLabel.text = nil;
                    UIView *colorPreview = [[UIView alloc] initWithFrame:CGRectMake(0.0f, 0.0f, 72.0f, 24.0f)];
                    colorPreview.layer.cornerRadius = colorPreview.frame.size.height/2.0f;
                    colorPreview.backgroundColor = [UIColor blackColor];
                    colorPreview.clipsToBounds = YES;
                    cell.accessoryView = colorPreview;
                }
                    break;
                case 1:
                {}
                    break;
                default:
                    break;
            }
        }
            break;
        default:
            break;
    }
    
    return cell;
}

-(void)didToggleSoundGravatarSwitch:(UISwitch *)sender
{
    [Environment.preferences setUseGravatars:sender.on];
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

/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/

#pragma mark - Accessors
-(NSArray *)sectionsHeadings
{
    if (_sectionsHeadings == nil) {
        _sectionsHeadings = @[ NSLocalizedString(@"APPEARANCE_GRAVATAR_SECTION", nil),
                               NSLocalizedString(@"APPEARANCE_MESSAGES_SECTION", nil) ];
    }
    return _sectionsHeadings;
}

@end
