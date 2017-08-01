//
//  InvitationService.h
//  Forsta
//
//  Created by Mark on 7/27/17.
//  Copyright © 2017 Forsta. All rights reserved.
//

#import "FLContactSelectionTableViewController.h"

@import Foundation;
@import MessageUI;
@import Social;

@interface FLInvitationService : NSObject <FLContactSelectionTableViewControllerDelegate, MFMessageComposeViewControllerDelegate, MFMailComposeViewControllerDelegate>

-(void)inviteUsersFrom:(nonnull UIViewController *)viewController;

-(void)inviteViaSMSFrom:(nonnull UIViewController *)viewController to:(nullable NSArray *)recipients;
-(void)inviteViaMailFrom:(nonnull UIViewController *)viewController to:(nullable NSArray *)recipients;
-(void)inviteViaTwitterFrom:(nonnull UIViewController *)viewController to:(nullable NSArray *)recipients;

@end
