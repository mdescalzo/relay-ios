//
//  InvitationService.h
//  Forsta
//
//  Created by Mark on 7/27/17.
//  Copyright © 2017 Forsta. All rights reserved.
//

@import Foundation;
@import MessageUI;
@import Social;

@interface FLInvitationService : NSObject <MFMessageComposeViewControllerDelegate, MFMailComposeViewControllerDelegate>

-(void)inviteUsers;

@end
