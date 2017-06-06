//
//  ForstaMessagesViewController.h
//  Forsta
//
//  Created by Mark on 6/2/17.
//  Copyright © 2017 Forsta. All rights reserved.
//

#import "SLKTextViewController.h"
#include "InboxTableViewCell.h"

#import "CallState.h"
#import "Contact.h"
#import "TSGroupModel.h"

@interface ForstaMessagesViewController : SLKTextViewController <UIGestureRecognizerDelegate,UIViewControllerPreviewingDelegate, UIPopoverControllerDelegate>

@property (nonatomic) BOOL newlyRegisteredUser;
@property (nonatomic, retain) CallState *latestCall;

- (void)presentThread:(TSThread *)thread keyboardOnViewAppearing:(BOOL)keyboardOnViewAppearing;
- (NSNumber *)updateInboxCountLabel;
- (void)composeNew;
-(void)reloadTableView;

@end
