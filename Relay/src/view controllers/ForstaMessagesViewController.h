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

@interface ForstaMessagesViewController : SLKTextViewController <UIGestureRecognizerDelegate,UIViewControllerPreviewingDelegate, UIPopoverPresentationControllerDelegate>

@property (nonatomic) BOOL newlyRegisteredUser;
@property (nonatomic, retain) CallState *latestCall;

@property (nonatomic, strong) TSThread *selectedThread;
@property (nonatomic, assign) BOOL newConversation;
@property (nonatomic, strong) NSDictionary *targetUserInfo;

- (void)presentThread:(TSThread *)thread keyboardOnViewAppearing:(BOOL)keyboardOnViewAppearing;
- (void)configureForThread:(TSThread *)thread keyboardOnViewAppearing:(BOOL)keyboardAppearing;

- (NSNumber *)updateInboxCountLabel;
- (void)composeNew;
-(void)reloadTableView;

-(void)showDomainTableView;
-(void)hideDomainTableView;

@end
