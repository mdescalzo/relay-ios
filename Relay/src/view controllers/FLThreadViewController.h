//
//  FLThreadViewController.h
//  Forsta
//
//  Created by Mark on 6/2/17.
//  Copyright © 2017 Forsta. All rights reserved.
//

@import UIKit;
@import AVFoundation;
@import MediaPlayer;

@class RelayCall;

@interface FLThreadViewController : UIViewController <UIGestureRecognizerDelegate, UITableViewDelegate, UITableViewDataSource,
                                                            UIViewControllerPreviewingDelegate,
                                                            UIPopoverPresentationControllerDelegate>

@property (nonatomic) BOOL newlyRegisteredUser;
//@property (nonatomic, strong) CallState * _Nullable latestCall;
@property (nonatomic, weak) IBOutlet UITableView *_Nullable tableView;
@property (nonatomic, assign) BOOL newConversation;
@property (nonatomic, strong) NSDictionary * _Nullable targetUserInfo;

- (void)presentThread:(TSThread *_Nonnull)thread keyboardOnViewAppearing:(BOOL)keyboardOnViewAppearing;
- (void)presentCall:(nonnull RelayCall *)call;

- (NSNumber *_Nullable)updateInboxCountLabel;
- (void)composeNew:(nullable id)sender;
-(void)reloadTableView;

-(void)showDomainTableView;
-(void)hideDomainTableView;

@end
