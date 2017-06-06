//
//  ForstaDomainTableViewController.h
//  Forsta
//
//  Created by Mark on 6/5/17.
//  Copyright © 2017 Forsta. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface ForstaDomainTableViewController : UIViewController <UITableViewDelegate, UITableViewDataSource>

@property (weak, nonatomic) IBOutlet UITableView *tableView;
@property (weak, nonatomic) IBOutlet UILabel *titleLabel;

@end
