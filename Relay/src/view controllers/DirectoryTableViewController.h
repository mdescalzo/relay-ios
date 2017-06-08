//
//  DirectoryTableViewController.h
//  Forsta
//
//  Created by Mark on 6/7/17.
//  Copyright © 2017 Forsta. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface DirectoryTableViewController : UITableViewController

@property (nonatomic, weak) IBOutlet UIBarButtonItem *doneBarButton;

@property (nonatomic, strong) NSDictionary *contentDictionary;

@end
