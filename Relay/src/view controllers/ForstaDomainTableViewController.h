//
//  ForstaDomainTableViewController.h
//  Forsta
//
//  Created by Mark on 6/5/17.
//  Copyright © 2017 Forsta. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "AppDelegate.h"

@interface ForstaDomainTableViewController : UIViewController <UITableViewDelegate, UITableViewDataSource>

@property (weak, nonatomic) IBOutlet UITableView *tableView;
@property (weak, nonatomic) IBOutlet UILabel *titleLabel;
@property (weak, nonatomic) ForstaMessagesViewController *hostViewController;

@end
