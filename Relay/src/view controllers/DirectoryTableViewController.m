//
//  DirectoryTableViewController.m
//  Forsta
//
//  Created by Mark on 6/7/17.
//  Copyright © 2017 Forsta. All rights reserved.
//

#import "DirectoryTableViewController.h"
#import "CCSMStorage.h"
#import "DirectoryDetailTableViewController.h"
#import "ForstaMessagesViewController.h"
#import "TSContactThread.h"
#import "TSGroupThread.h"

@interface DirectoryTableViewController ()

@property (nonatomic, strong) CCSMStorage *ccsmStorage;

@end

@implementation DirectoryTableViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    // Uncomment the following line to preserve selection between presentations.
    // self.clearsSelectionOnViewWillAppear = NO;
    
    // Uncomment the following line to display an Edit button in the navigation bar for this view controller.
    // self.navigationItem.rightBarButtonItem = self.editButtonItem;
    
    [self contentDictionary];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
#warning Incomplete implementation, return the number of sections
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
#warning Incomplete implementation, return the number of rows
    return (NSInteger)[[self.contentDictionary allKeys] count];
}


- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"DirectoryElementCell" forIndexPath:indexPath];
    
    // Configure the cell...
    cell.detailTextLabel.text = [[self.contentDictionary allKeys] objectAtIndex:(NSUInteger)[indexPath row]];
    NSDictionary *tmpDict = [self detailObjectForIndexPath:indexPath];
    
    NSString *fullName = [NSString stringWithFormat:@"%@ %@", [tmpDict objectForKey:@"first_name" ], [tmpDict objectForKey:@"last_name"]];
    cell.textLabel.text = fullName;
    
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

//-(void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
//{
//    // Build a new message thread from selected user in table
//    NSDictionary *tmpDict = [self detailObjectForIndexPath:indexPath];
//    NSString *contactID = [tmpDict objectForKey:@"phone"];
//    TSContactThread *newThread = [TSContactThread getOrCreateThreadWithContactId:contactID];
//    
//}

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
    NSIndexPath *path = [self.tableView indexPathForSelectedRow];
    
    NSDictionary *payload = [self detailObjectForIndexPath:path];
    if ([segue.identifier isEqualToString:@"DirectoryDetailSegue"]) {
        ((DirectoryDetailTableViewController *)[segue destinationViewController]).contentDictionary = payload;
    } else {
        ForstaMessagesViewController *targetVC = (ForstaMessagesViewController *)[segue destinationViewController];
        NSDictionary *tmpDict = [self detailObjectForIndexPath:path];
        targetVC.newConversation = YES;
        targetVC.targetUserInfo = tmpDict;
        targetVC.selectedThread = nil;
        [targetVC reloadTableView];
    }
}

-(NSDictionary *)detailObjectForIndexPath:(NSIndexPath *)indexPath
{
    NSString *aKey = [[self.contentDictionary allKeys] objectAtIndex:(NSUInteger)[indexPath row]];

    NSDictionary *tmpDict = [self.contentDictionary objectForKey:aKey];
    return [tmpDict objectForKey:[tmpDict allKeys].lastObject];
}

-(IBAction)onDoneTap:(id)sender
{
    [self dismissViewControllerAnimated:YES completion:nil];
}

#pragma mark - Lazy instantiation
-(NSDictionary *)contentDictionary
{
    if (_contentDictionary == nil) {
        _contentDictionary = [self.ccsmStorage getTags];
    }
    return _contentDictionary;
}

-(CCSMStorage *)ccsmStorage
{
    if (_ccsmStorage == nil) {
        _ccsmStorage = [CCSMStorage new];
    }
    return _ccsmStorage;
}

@end
