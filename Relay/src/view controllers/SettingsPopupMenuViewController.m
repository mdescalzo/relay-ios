//
//  SettingsPopupMenuViewController.m
//  Forsta
//
//  Created by Mark on 6/5/17.
//  Copyright © 2017 Forsta. All rights reserved.
//

#import "SettingsPopupMenuViewController.h"
#import "DirectoryTableViewController.h"

CGFloat const kRowHeight = 40;

@interface SettingsPopupMenuViewController ()

@property (nonatomic, strong) NSArray *settingsTitles;

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
    return (NSInteger)[self.settingsTitles count];
}


- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"Cell" forIndexPath:indexPath];
    
    // Configure the cell...
    cell.textLabel.text = [self.settingsTitles objectAtIndex:(NSUInteger)[indexPath row]];
    
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
        case 0:  //         Directory selected
        {
            [self performSegueWithIdentifier:@"directorySegue" sender:[tableView cellForRowAtIndexPath:indexPath] ];
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
    UIViewController* sourceViewController = unwindSegue.sourceViewController;
    
    if ([sourceViewController isKindOfClass:[DirectoryTableViewController class]])
    {
        [self dismissViewControllerAnimated:YES completion:nil];
    }
}


#pragma mark - convenience method for getting overall table heigh
-(CGFloat)heightForTableView;
{
    CGFloat numRows = [self tableView:self.tableView numberOfRowsInSection:1];
    return numRows * kRowHeight;
}

#pragma mark - Lazy instantiation
-(NSArray *)settingsTitles
{
    if (_settingsTitles == nil) {
        _settingsTitles = @[NSLocalizedString(@"Directory", @""),
                            NSLocalizedString(@"Settings", @""),
                            NSLocalizedString(@"Mark all read", @""),
                            NSLocalizedString(@"Import / export", @""),
                            NSLocalizedString(@"Help", @"")
#ifdef DEBUG
                            ,NSLocalizedString(@"Debug Dashboard", @"")
#endif
                            ];
    }
    return _settingsTitles;
}

@end
