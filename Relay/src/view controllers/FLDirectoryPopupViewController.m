//
//  FLDirectoryPopupViewController.m
//  Forsta
//
//  Created by Mark on 6/14/17.
//  Copyright © 2017 Forsta. All rights reserved.
//

#import "CCSMStorage.h"
#import "FLDirectoryPopupViewController.h"
#import "FLContactsManager.h"

#import "Environment.h"


@interface FLDirectoryPopupViewController ()

@property (nonatomic, strong) CCSMStorage *ccsmStorage;
@property (nonatomic, strong) NSDictionary *contentDictionary;
@property (nonatomic, strong) NSArray *content;
@property (nonatomic, strong) FLContactsManager *contactsManager;

@end

@implementation FLDirectoryPopupViewController

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

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return (NSInteger)[self.content count];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"DirectoryElementCell" forIndexPath:indexPath];
    
    // Configure the cell...
//    cell.detailTextLabel.text = [[self.contentDictionary allKeys] objectAtIndex:(NSUInteger)[indexPath row]];
//    NSDictionary *tmpDict = [self detailObjectForIndexPath:indexPath];
//    
//    NSString *fullName = [NSString stringWithFormat:@"%@ %@", [tmpDict objectForKey:@"first_name" ], [tmpDict objectForKey:@"last_name"]];
//    cell.textLabel.text = fullName;
    
    FLContact *contact = [self.content objectAtIndex:(NSUInteger)indexPath.row];
    cell.textLabel.text = [contact fullName];
    cell.detailTextLabel.text = contact.tag;
    
    return cell;
}

// Convenience method to break into the dictory to get the user tag
-(NSDictionary *)detailObjectForIndexPath:(NSIndexPath *)indexPath
{
    NSString *aKey = [[self.contentDictionary allKeys] objectAtIndex:(NSUInteger)[indexPath row]];
    
    NSDictionary *tmpDict = [self.contentDictionary objectForKey:aKey];
    return [tmpDict objectForKey:[tmpDict allKeys].lastObject];
}


/*
// Override to support conditional editing of the table view.
- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
    // Return NO if you do not want the specified item to be editable.
    return YES;
}
*/

-(void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    // Tell Everyone a user was selected
    NSString *FLUserSelectedFromDirectory = @"FLUserSelectedFromDirectory";

//    NSString *sendString = [[self.contentDictionary allKeys] objectAtIndex:(NSUInteger)[indexPath row]];
    FLContact *contact = [self.content objectAtIndex:(NSUInteger)indexPath.row];

    [[NSNotificationCenter defaultCenter] postNotificationName:FLUserSelectedFromDirectory object:nil userInfo:@{@"tag":contact.tag}];
    [self dismissViewControllerAnimated:YES completion:nil];
}

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

-(FLContactsManager *)contactsManager
{
    if (_contactsManager == nil) {
        _contactsManager = [Environment getCurrent].contactsManager;
    }
    return _contactsManager;
}

-(NSArray *)content
{
    if (_content == nil) {
        
        // Sort the content by last name
        _content = [[self.contactsManager allContacts] sortedArrayUsingComparator: ^(FLContact *a1, FLContact *a2) {
            return [a1.lastName compare:a2.lastName];
        }];
    }
    return _content;
}
@end
