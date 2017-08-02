//
//  FLThreadViewController.h
//  Forsta
//
//  Created by Mark on 6/2/17.
//  Copyright © 2017 Forsta. All rights reserved.
//

#import "SLKTextViewController.h"
#include "InboxTableViewCell.h"
#import <AVFoundation/AVFoundation.h>
#import <MediaPlayer/MediaPlayer.h>

#import "CallState.h"
#import "Contact.h"
#import "TSGroupModel.h"

@interface FLThreadViewController : SLKTextViewController <UIGestureRecognizerDelegate,UIViewControllerPreviewingDelegate, UIPopoverPresentationControllerDelegate, UIImagePickerControllerDelegate>

@property (nonatomic) BOOL newlyRegisteredUser;
@property (nonatomic, strong) CallState * _Nullable latestCall;

@property (nonatomic, assign) BOOL newConversation;
@property (nonatomic, strong) NSDictionary * _Nullable targetUserInfo;

- (void)presentThread:(TSThread *_Nonnull)thread keyboardOnViewAppearing:(BOOL)keyboardOnViewAppearing;
- (void)configureForThread:(TSThread *_Nonnull)thread keyboardOnViewAppearing:(BOOL)keyboardAppearing;

- (NSNumber *_Nullable)updateInboxCountLabel;
- (void)composeNew:(nullable id)sender;
-(void)reloadTableView;

-(void)showDomainTableView;
-(void)hideDomainTableView;

@end