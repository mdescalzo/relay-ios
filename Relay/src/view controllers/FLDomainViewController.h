//
//  FLDomainViewController.h
//  Forsta
//
//  Created by Mark on 6/5/17.
//  Copyright © 2017 Forsta. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "AppDelegate.h"

@interface FLDomainViewController : UIViewController <UITableViewDelegate, UITableViewDataSource, UIViewControllerPreviewingDelegate>

@property (weak, nonatomic) IBOutlet UITableView *tableView;
@property (weak, nonatomic) IBOutlet UILabel *titleLabel;
@property (weak, nonatomic) FLThreadViewController *hostViewController;

@end
