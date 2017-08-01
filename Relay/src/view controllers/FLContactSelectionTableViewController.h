//
//  FLContactSelectionTableViewController.h
//  Forsta
//
//  Created by Mark on 8/1/17.
//  Copyright © 2017 Forsta. All rights reserved.
//

@import UIKit;

@protocol FLContactSelectionTableViewControllerDelegate;

@interface FLContactSelectionTableViewController : UITableViewController

@property (nullable, nonatomic, weak) id <FLContactSelectionTableViewControllerDelegate> delegate;

@end

@protocol FLContactSelectionTableViewControllerDelegate <NSObject>

@required
-(void)contactPickerDidCancelSelection:(id _Nullable )sender;
-(void)contactPicker:(id _Nullable )sender didCompleteSelectionWithContacts:(NSArray *_Nonnull)selectedContacts;

@end
