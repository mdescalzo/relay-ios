//
//  FLContactSelectionTableViewController.m
//  Forsta
//
//  Created by Mark on 8/1/17.
//  Copyright © 2017 Forsta. All rights reserved.
//

#import "FLContactSelectionTableViewController.h"
#import "SignalRecipient.h"
#import "FLDirectoryCell.h"
#import "Environment.h"

@interface FLContactSelectionTableViewController () <UISearchBarDelegate>

@property (nonatomic, strong) NSArray<SignalRecipient *> *content;
@property (nonatomic, strong) NSArray<SignalRecipient *> *searchResults;
@property (nonatomic, strong) NSMutableArray<SignalRecipient *> *selectedContacts;
@property (nonatomic, strong) UISearchBar *searchBar;

-(IBAction)doneTapped:(id)sender;
-(IBAction)cancelTapped:(id)sender;

@end

@implementation FLContactSelectionTableViewController

@synthesize contactDelegate;

- (void)viewDidLoad {
    [super viewDidLoad];
    
    // Uncomment the following line to preserve selection between presentations.
    // self.clearsSelectionOnViewWillAppear = NO;
    
    // Uncomment the following line to display an Edit button in the navigation bar for this view controller.
    // self.navigationItem.rightBarButtonItem = self.editButtonItem;
    
    self.navigationItem.titleView = self.searchBar;
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
//#warning Incomplete implementation, return the number of sections
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
//#warning Incomplete implementation, return the number of rows
    if (self.searchBar.text.length > 0) {
        return (NSInteger)self.searchResults.count;
    } else {
        return (NSInteger)self.content.count;
    }
}


- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    FLDirectoryCell *cell = (FLDirectoryCell *)[tableView dequeueReusableCellWithIdentifier:@"ContactCell" forIndexPath:indexPath];
    
    // Configure the cell...
    SignalRecipient *recipient = nil;
    
    if (self.searchBar.text.length > 0) {
        recipient = [self.searchResults objectAtIndex:(NSUInteger)indexPath.row];
    } else {
        recipient = [self.content objectAtIndex:(NSUInteger)indexPath.row];
    }
    [cell configureCellWithContact:recipient];
    
    return cell;
}

-(void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    
    FLDirectoryCell *selectedCell = [tableView cellForRowAtIndexPath:indexPath];
    
    SignalRecipient *selectedRecipient = nil;
    if (self.searchBar.text.length > 0) {
        selectedRecipient = [self.searchResults objectAtIndex:(NSUInteger)indexPath.row];
    } else {
        selectedRecipient = [self.content objectAtIndex:(NSUInteger)indexPath.row];
    }
    
    // toggle selection and add/remove from selectedContacts
    if ([selectedCell isSelected]) {
//        [tableView deselectRowAtIndexPath:indexPath animated:YES];
        if ([self.selectedContacts containsObject:selectedRecipient]) {
            [self.selectedContacts removeObject:selectedRecipient];
        }
    } else {
//        [tableView selectRowAtIndexPath:indexPath animated:YES scrollPosition:UITableViewScrollPositionNone];
        if (![self.selectedContacts containsObject:selectedRecipient]) {
            [self.selectedContacts addObject:selectedRecipient];
        }
    }
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

#pragma mark - button methods
-(IBAction)doneTapped:(id)sender
{
//    [self dismissViewControllerAnimated:YES completion:^{
        [self.contactDelegate contactPicker:self didCompleteSelectionWithContacts:[self.selectedContacts copy]];
        
//        // deselect things
//        for (NSIndexPath *indexPath in [self.tableView indexPathsForSelectedRows]) {
//            [self.tableView deselectRowAtIndexPath:indexPath animated:NO];
//        }
//        [self.selectedContacts removeAllObjects];
//    }];
}

-(IBAction)cancelTapped:(id)sender
{
//    [self dismissViewControllerAnimated:YES completion:^{
        [self.contactDelegate contactPickerDidCancelSelection:self];
        // deselect things
//        for (NSIndexPath *indexPath in [self.tableView indexPathsForSelectedRows]) {
//            [self.tableView deselectRowAtIndexPath:indexPath animated:NO];
//        }
//        [self.selectedContacts removeAllObjects];
//    }];
}

#pragma mark - search bar delegate methods
-(void)searchBar:(UISearchBar *)searchBar textDidChange:(NSString *)searchText
{
    if (searchBar.text.length > 0) {
        NSPredicate *namePredicate = [NSPredicate predicateWithFormat:@"fullName CONTAINS[c] %@", searchText];
        self.searchResults = [self.content filteredArrayUsingPredicate:namePredicate];
    }
    [self.tableView reloadData];
    
}


#pragma mark - lazy instantiation
-(NSArray<SignalRecipient *> *)content
{
    if (_content == nil) {
        NSArray *allContacts = Environment.shared.contactsManager.activeRecipients;
        // Sort by last name
        NSSortDescriptor *sortDescriptor = [[NSSortDescriptor alloc] initWithKey:@"lastName" ascending:YES];
        _content = [allContacts sortedArrayUsingDescriptors:@[ sortDescriptor ]];
    }
    return _content;
}

-(NSMutableArray<SignalRecipient *> *)selectedContacts
{
    if (_selectedContacts == nil) {
        _selectedContacts = [NSMutableArray new];
    }
    return _selectedContacts;
}

-(UISearchBar *)searchBar
{
    if (_searchBar == nil) {
        _searchBar = [UISearchBar new];
        _searchBar.delegate = self;
    }
    return _searchBar;
}

@end
