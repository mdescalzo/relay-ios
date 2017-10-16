//
//  InvitationService.h
//  Forsta
//
//  Created by Mark on 7/27/17.
//  Copyright © 2017 Forsta. All rights reserved.
//

#import "FLContactSelectionTableViewController.h"

#import <Foundation/Foundation.h>
#import <MessageUI/MessageUI.h>
#import <Social/Social.h>

@interface FLInvitationService : NSObject 

-(void)inviteUsersFrom:(nonnull UIViewController *)viewController;

-(void)inviteViaSMSFrom:(nonnull UIViewController *)viewController to:(nullable NSArray *)recipients;
-(void)inviteViaMailFrom:(nonnull UIViewController *)viewController to:(nullable NSArray *)recipients;
-(void)inviteViaTwitterFrom:(nonnull UIViewController *)viewController to:(nullable NSArray *)recipients;

@end
