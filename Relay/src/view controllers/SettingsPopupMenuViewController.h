//
//  SettingsPopupMenuViewController.h
//  Forsta
//
//  Created by Mark on 6/5/17.
//  Copyright © 2017 Forsta. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface SettingsPopupMenuViewController : UITableViewController

- (IBAction)unwindToSettings:(UIStoryboardSegue *)unwindSegue;

-(CGFloat)heightForTableView;

@end
