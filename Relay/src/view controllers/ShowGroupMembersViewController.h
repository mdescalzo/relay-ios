//
//  ShowGroupMembersViewController.h
//  Signal
//
//  Created by Christine Corbett on 12/19/14
//  Copyright (c) 2014 Open Whisper Systems. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "TSGroupModel.h"
#import "TSThread.h"

#import <UIKit/UIKit.h>

@interface ShowGroupMembersViewController : UITableViewController <UITableViewDelegate,
                                                                   UITabBarDelegate,
                                                                   UIImagePickerControllerDelegate,
                                                                   UINavigationControllerDelegate,
                                                                   UITextFieldDelegate>

- (void)configWithThread:(TSThread *)thread;

@end
