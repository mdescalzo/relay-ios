//
//  ForstaDomainTableViewController.m
//  Forsta
//
//  Created by Mark on 6/5/17.
//  Copyright © 2017 Forsta. All rights reserved.
//

#import "ForstaDomainTableViewController.h"
#import "InboxTableViewCell.h"
#import "Environment.h"
#import <RelayServiceKit/OWSMessageSender.h>
#import <RelayServiceKit/TSMessagesManager.h>
#import <RelayServiceKit/TSOutgoingMessage.h>
#import <YapDatabase/YapDatabaseViewChange.h>
#import <YapDatabase/YapDatabaseViewConnection.h>

NSInteger const kConversationsIndex = 0;
NSInteger const kPinnedIndex = 1;
NSInteger const kAnnouncementsIndex = 2;
NSInteger const kTopicsIndex = 4;


@interface ForstaDomainTableViewController ()

@property (nonatomic, strong) NSArray *sectionTitles;
@property (nonatomic, strong) NSArray *sectionImages;

@property (strong, nonatomic, readonly) OWSContactsManager *contactsManager;
@property (nonatomic, strong) YapDatabaseViewMappings *threadMappings;
@property (nonatomic, strong) YapDatabaseConnection *uiDatabaseConnection;

@end

@implementation ForstaDomainTableViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    // Uncomment the following line to preserve selection between presentations.
    // self.clearsSelectionOnViewWillAppear = NO;
    
    // Uncomment the following line to display an Edit button in the navigation bar for this view controller.
    // self.navigationItem.rightBarButtonItem = self.editButtonItem;
    self.title = @"Domain";
    
    // Section header name and image in NSDictionary
    self.sectionTitles = @[NSLocalizedString(@"Conversation", @""),
                           NSLocalizedString(@"Pinned", @""),
                           NSLocalizedString(@"Announcements", @""),
                           NSLocalizedString(@"Topics", @"") ];
     self.sectionImages = @[[UIImage imageNamed:@"Chat_2"],
                            [UIImage imageNamed:@"Pin_2"],
                            [UIImage imageNamed:@"Announcements_2"],
                            [UIImage imageNamed:@"Topics_2"]];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 4;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return 0;
}

-(UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section
{
    // UIView to hold the things
    UIView *headerView = [[UIView alloc] initWithFrame:CGRectMake(0,
                                                                  0,
                                                                  self.view.frame.size.width,
                                                                  [self tableView:tableView heightForHeaderInSection:section]
                                                                  )];
    
    UIImageView *imageView = [[UIImageView alloc] initWithFrame:CGRectMake(0,
                                                                           0,
                                                                           [self tableView:tableView heightForHeaderInSection:section],
                                                                           [self tableView:tableView heightForHeaderInSection:section])];
    
    switch (section) {
        case kConversationsIndex:
        {
            imageView.backgroundColor = [UIColor colorWithRed:43 green:172 blue:226 alpha:1.0];
        }
            break;
        case kPinnedIndex:
        {
            imageView.backgroundColor = [UIColor colorWithRed:175 green:210 blue:63 alpha:1.0];
        }
            break;
        case kAnnouncementsIndex:
        {
            imageView.backgroundColor = [UIColor colorWithRed:244 green:125 blue:32 alpha:1.0];
        }
            break;
        case kTopicsIndex:
        {
            imageView.backgroundColor = [UIColor colorWithRed:128 green:206 blue:255 alpha:1.0];
        }
            break;
            
        default:
            break;
    }
    
    imageView.image = [self.sectionImages objectAtIndex:(NSUInteger)section];
    
    UILabel *label = [[UILabel alloc] initWithFrame:CGRectMake([self tableView:tableView heightForHeaderInSection:section],
                                                              0,
                                                              self.view.frame.size.width - imageView.frame.size.width,
                                                              [self tableView:tableView heightForHeaderInSection:section])];
    label.backgroundColor = [UIColor colorWithRed:202 green:202 blue:202 alpha:1.0];
    label.textAlignment = NSTextAlignmentCenter;
    label.text = [self.sectionTitles objectAtIndex:(NSUInteger)section];
    
    headerView.backgroundColor = [UIColor clearColor];
    
    
    [headerView addSubview:imageView];
    [headerView addSubview:label];  
    
    return headerView;
}

-(CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section
{
    return 33.0;
}



- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
//    static NSString *cellID = @"cell";
//    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellID forIndexPath:indexPath];
    
    // Configure the cell...
    InboxTableViewCell *cell =  [self.tableView dequeueReusableCellWithIdentifier:NSStringFromClass([InboxTableViewCell class])];
    TSThread *thread = [self threadForIndexPath:indexPath];
    
    if (!cell) {
        cell = [InboxTableViewCell inboxTableViewCell];
    }
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        [cell configureWithThread:thread contactsManager:self.contactsManager];
    });
    
    if ((unsigned long)indexPath.row == [self.threadMappings numberOfItemsInSection:0] - 1) {
        cell.separatorInset = UIEdgeInsetsMake(0.f, cell.bounds.size.width, 0.f, 0.f);
    }
    
    return cell;
}

- (TSThread *)threadForIndexPath:(NSIndexPath *)indexPath {
    __block TSThread *thread = nil;
    [self.uiDatabaseConnection readWithBlock:^(YapDatabaseReadTransaction *transaction) {
        thread = [[transaction extension:TSThreadDatabaseViewExtensionName] objectAtIndexPath:indexPath
                                                                                 withMappings:self.threadMappings];
    }];
    
    return thread;
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

#pragma mark - Lazy instantiation

@end
