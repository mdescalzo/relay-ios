//
//  InvitationService.m
//  Forsta
//
//  Created by Mark on 7/27/17.
//  Copyright © 2017 Forsta. All rights reserved.
//

#import "FLInvitationService.h"
#import "UIUtil.h"

@interface FLInvitationService()

@end

@implementation FLInvitationService

-(void)inviteUsers
{
    UIAlertController *invitationSheet = [UIAlertController alertControllerWithTitle:nil
                                                                             message:nil
                                                                      preferredStyle:UIAlertControllerStyleActionSheet];
    
    if ([MFMessageComposeViewController canSendText]) { // If SMS available
        UIAlertAction *smsButton = [UIAlertAction actionWithTitle:NSLocalizedString(@"SHARE_ACTION_MESSAGE", @"")
                                                            style:UIAlertActionStyleDefault
                                                          handler:^(UIAlertAction *_Nonnull action) { [self smsSelected]; }];
        [invitationSheet addAction:smsButton];
    }
    
    if ([MFMailComposeViewController canSendMail]) {     // If email available
        UIAlertAction *mailButton = [UIAlertAction actionWithTitle:NSLocalizedString(@"SHARE_ACTION_MAIL", @"")
                                                             style:UIAlertActionStyleDefault
                                                           handler:^(UIAlertAction *_Nonnull action) { [self mailSelected]; }];
        [invitationSheet addAction:mailButton];
    }
    
    if ([SLComposeViewController isAvailableForServiceType:SLServiceTypeTwitter]) {    // If twitter available
        UIAlertAction *twitterButton = [UIAlertAction actionWithTitle:NSLocalizedString(@"SHARE_ACTION_TWEET", @"")
                                                                style:UIAlertActionStyleDefault
                                                              handler:^(UIAlertAction *_Nonnull action) { [self tweetSelected]; }];
        [invitationSheet addAction:twitterButton];
    }
    
    // Cancel Button
    UIAlertAction *cancelButton = [UIAlertAction actionWithTitle:NSLocalizedString(@"TXT_CANCEL_TITLE", @"")
                                                           style:UIAlertActionStyleCancel
                                                         handler:^(UIAlertAction *_Nonnull action) { }];
    [invitationSheet addAction:cancelButton];
    
    [[self currentParentViewController] presentViewController:invitationSheet animated:YES completion:nil];
}

-(void)smsSelected
{
    MFMessageComposeViewController *picker = [[MFMessageComposeViewController alloc] init];
    picker.messageComposeDelegate = self;
    picker.body = [NSLocalizedString(@"SMS_INVITE_BODY", @"")
                   stringByAppendingString:[NSString stringWithFormat:@"\n%@", FLSMSInvitationURL]];
    [[self currentParentViewController] presentViewController:picker animated:YES completion:[UIUtil modalCompletionBlock]];
}

-(void)mailSelected
{
    
}

-(void)tweetSelected
{
    SLComposeViewController *tweetSheet =
    [SLComposeViewController composeViewControllerForServiceType:SLServiceTypeTwitter];
    
    NSString *tweetString = [NSString stringWithFormat:NSLocalizedString(@"SETTINGS_INVITE_TWITTER_TEXT", @"")];
    [tweetSheet setInitialText:tweetString];
    [tweetSheet addURL:[NSURL URLWithString:@"https://forsta.io/signal/install/"]];
    tweetSheet.completionHandler = ^(SLComposeViewControllerResult result) {
    };
    [[self currentParentViewController] presentViewController:tweetSheet animated:YES completion:[UIUtil modalCompletionBlock]];
}

-(UIViewController *)currentParentViewController
{
    UINavigationController *navController = (UINavigationController *)[[[[UIApplication sharedApplication] delegate] window] rootViewController];
    UIViewController *vc = [navController topViewController];
    // build method for discovering correct viewController to present sheets/alerts
    return vc;
}

@end
