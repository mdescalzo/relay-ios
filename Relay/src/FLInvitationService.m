//
//  InvitationService.m
//  Forsta
//
//  Created by Mark on 7/27/17.
//  Copyright © 2017 Forsta. All rights reserved.
//

#import "FLInvitationService.h"
#import "UIUtil.h"

@interface FLInvitationService() <MFMessageComposeViewControllerDelegate, MFMailComposeViewControllerDelegate>

@end

@implementation FLInvitationService

-(void)inviteUsersFrom:(nonnull UIViewController *)viewController;
{
    UIAlertController *invitationSheet = [UIAlertController alertControllerWithTitle:nil
                                                                             message:nil
                                                                      preferredStyle:UIAlertControllerStyleActionSheet];
    
    if ([MFMessageComposeViewController canSendText]) { // If SMS available
        UIAlertAction *smsButton = [UIAlertAction actionWithTitle:NSLocalizedString(@"SHARE_ACTION_MESSAGE", @"")
                                                            style:UIAlertActionStyleDefault
                                                          handler:^(UIAlertAction *_Nonnull action) {
                                                              [self inviteViaSMSFrom:viewController to:nil];
                                                          }];
        [invitationSheet addAction:smsButton];
    }
    
    if ([MFMailComposeViewController canSendMail]) {     // If email available
        UIAlertAction *mailButton = [UIAlertAction actionWithTitle:NSLocalizedString(@"SHARE_ACTION_MAIL", @"")
                                                             style:UIAlertActionStyleDefault
                                                           handler:^(UIAlertAction *_Nonnull action) {
                                                               [self inviteViaMailFrom:viewController to:nil];
                                                           }];
        [invitationSheet addAction:mailButton];
    }
    
    if ([SLComposeViewController isAvailableForServiceType:SLServiceTypeTwitter]) {    // If twitter available
        UIAlertAction *twitterButton = [UIAlertAction actionWithTitle:NSLocalizedString(@"SHARE_ACTION_TWEET", @"")
                                                                style:UIAlertActionStyleDefault
                                                              handler:^(UIAlertAction *_Nonnull action) {
                                                                  [self inviteViaTwitterFrom:viewController to:nil];
                                                              }];
        [invitationSheet addAction:twitterButton];
    }
    
    // Cancel Button
    UIAlertAction *cancelButton = [UIAlertAction actionWithTitle:NSLocalizedString(@"TXT_CANCEL_TITLE", @"")
                                                           style:UIAlertActionStyleCancel
                                                         handler:^(UIAlertAction *_Nonnull action) { }];
    [invitationSheet addAction:cancelButton];
    
    [viewController presentViewController:invitationSheet animated:YES completion:[UIUtil modalCompletionBlock]];
}

-(void)inviteViaSMSFrom:(nonnull UIViewController *)viewController to:(nullable NSArray *)recipients;
{
    if ([MFMessageComposeViewController canSendText]) {
        MFMessageComposeViewController *picker = [[MFMessageComposeViewController alloc] init];
        picker.recipients = recipients;
        picker.messageComposeDelegate = self;
        picker.body = [NSLocalizedString(@"SMS_INVITE_BODY", @"")
                       stringByAppendingString:[NSString stringWithFormat:@"\n%@", FLSMSInvitationURL]];
        [viewController presentViewController:picker animated:YES completion:[UIUtil modalCompletionBlock]];
    }
    else {
        // No SMS sends for you
        UIAlertController *notPermitted = [UIAlertController alertControllerWithTitle:@""
                                                                              message:NSLocalizedString(@"UNSUPPORTED_FEATURE_ERROR", @"")
                                                                       preferredStyle:UIAlertControllerStyleActionSheet];
        UIAlertAction *okButton = [UIAlertAction actionWithTitle:NSLocalizedString(@"OK", @"")
                                                           style:UIAlertActionStyleCancel
                                                         handler:^(UIAlertAction *_Nonnull action) { }];
        [notPermitted addAction:okButton];
        [viewController presentViewController:notPermitted
                                                         animated:YES
                                                       completion:[UIUtil modalCompletionBlock]];
    }
}

-(void)inviteViaMailFrom:(nonnull UIViewController *)viewController to:(nullable NSArray *)recipients
{
    MFMailComposeViewController *mailController = [[MFMailComposeViewController alloc] init];
    mailController.mailComposeDelegate = self;
//    [mailController setToRecipients:<#(nullable NSArray<NSString *> *)#>];
    [mailController setSubject:NSLocalizedString(@"SHARE_INVITE_SUBJECT", @"")];
    NSString *body = [NSString stringWithFormat:@"%@\n\n%@", NSLocalizedString(@"SMS_INVITE_BODY", @""), FLSMSInvitationURL];
    [mailController setMessageBody:body isHTML:NO];
    [viewController presentViewController:mailController animated:YES completion:[UIUtil modalCompletionBlock]];
}

-(void)inviteViaTwitterFrom:(nonnull UIViewController *)viewController to:(nullable NSArray *)recipients
{
    SLComposeViewController *tweetSheet =
    [SLComposeViewController composeViewControllerForServiceType:SLServiceTypeTwitter];
    
    NSString *tweetString = [NSString stringWithFormat:NSLocalizedString(@"SETTINGS_INVITE_TWITTER_TEXT", @"")];
    [tweetSheet setInitialText:tweetString];
    [tweetSheet addURL:[NSURL URLWithString:NSLocalizedString(@"FLSMSInvitationURL", @"")]];
    tweetSheet.completionHandler = ^(SLComposeViewControllerResult result) {
    };
    [viewController presentViewController:tweetSheet animated:YES completion:[UIUtil modalCompletionBlock]];
}

#pragma mark - message controller delegate method
-(void)messageComposeViewController:(MFMessageComposeViewController *)controller didFinishWithResult:(MessageComposeResult)result
{
    switch (result) {
        case MessageComposeResultFailed:
        {
            UIAlertController *warningAlert = [UIAlertController alertControllerWithTitle:@""
                                                                                  message:NSLocalizedString(@"SEND_SMS_INVITE_FAILURE", @"")
                                                                           preferredStyle:UIAlertControllerStyleAlert];
            UIAlertAction *okButton = [UIAlertAction actionWithTitle:NSLocalizedString(@"OK", @"")
                                                               style:UIAlertActionStyleCancel
                                                             handler:^(UIAlertAction *_Nonnull action) { }];
            [warningAlert addAction:okButton];
            [controller.presentingViewController presentViewController:warningAlert animated:YES completion:nil];
        }
            break;
        case MessageComposeResultCancelled:
//            break;
        case MessageComposeResultSent:
//            break;
        default:
        {
            [controller dismissViewControllerAnimated:YES completion:[UIUtil modalCompletionBlock]];
        }
            break;
    }
}

#pragma mark - mail controller delegate method
-(void)mailComposeController:(MFMailComposeViewController *)controller didFinishWithResult:(MFMailComposeResult)result error:(NSError *)error
{
    switch (result) {
        case MFMailComposeResultFailed:
        {
            UIAlertController *warningAlert = [UIAlertController alertControllerWithTitle:@""
                                                                                  message:NSLocalizedString(@"ERROR_DESCRIPTION_CLIENT_SENDING_FAILURE", @"")
                                                                           preferredStyle:UIAlertControllerStyleAlert];
            UIAlertAction *okButton = [UIAlertAction actionWithTitle:NSLocalizedString(@"OK", @"")
                                                               style:UIAlertActionStyleCancel
                                                             handler:^(UIAlertAction *_Nonnull action) { }];
            [warningAlert addAction:okButton];
            [controller.presentingViewController presentViewController:warningAlert animated:YES completion:nil];
        }
            break;
        case MFMailComposeResultCancelled:
//            break;
        case MFMailComposeResultSaved:
//            break;
        case MFMailComposeResultSent:
//            break;
        default:
        {
            [controller dismissViewControllerAnimated:YES completion:[UIUtil modalCompletionBlock]];
        }
            break;
    }
}

@end
