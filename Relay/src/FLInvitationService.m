//
//  InvitationService.m
//  Forsta
//
//  Created by Mark on 7/27/17.
//  Copyright © 2017 Forsta. All rights reserved.
//

#import "FLInvitationService.h"
#import "UIUtil.h"
#import "Contact.h"
#import "FLContactsManager.h"

@interface FLInvitationService() <FLContactSelectionTableViewControllerDelegate, MFMessageComposeViewControllerDelegate, MFMailComposeViewControllerDelegate>

@property (nonatomic, strong) UIViewController *sourceController;
@property (nonatomic, assign) BOOL sendingMail;
@property (nonatomic, assign) BOOL sendingSMS;
//@property (nonatomic, strong) FLContactSelectionTableViewController *pickerController;

@end

@implementation FLInvitationService

-(void)inviteUsersFrom:(nonnull UIViewController *)viewController;
{
    self.sourceController = viewController;
    
    UIAlertController *invitationSheet = [UIAlertController alertControllerWithTitle:nil
                                                                             message:nil
                                                                      preferredStyle:UIAlertControllerStyleActionSheet];
    
    if ([MFMessageComposeViewController canSendText]) { // If SMS available
        UIAlertAction *smsButton = [UIAlertAction actionWithTitle:NSLocalizedString(@"SHARE_ACTION_MESSAGE", @"")
                                                            style:UIAlertActionStyleDefault
                                                          handler:^(UIAlertAction *_Nonnull action) {
                                                              [self smsTapped];
                                                          }];
        [invitationSheet addAction:smsButton];
    }
    
    if ([MFMailComposeViewController canSendMail]) {     // If email available
        UIAlertAction *mailButton = [UIAlertAction actionWithTitle:NSLocalizedString(@"SHARE_ACTION_MAIL", @"")
                                                             style:UIAlertActionStyleDefault
                                                           handler:^(UIAlertAction *_Nonnull action) {
                                                               [self mailTapped];
                                                           }];
        [invitationSheet addAction:mailButton];
    }
    
    if ([SLComposeViewController isAvailableForServiceType:SLServiceTypeTwitter]) {    // If twitter available
        UIAlertAction *twitterButton = [UIAlertAction actionWithTitle:NSLocalizedString(@"SHARE_ACTION_TWEET", @"")
                                                                style:UIAlertActionStyleDefault
                                                              handler:^(UIAlertAction *_Nonnull action) {
                                                                  [self twitterTapped];
                                                              }];
        [invitationSheet addAction:twitterButton];
    }
    
    // Cancel Button
    UIAlertAction *cancelButton = [UIAlertAction actionWithTitle:NSLocalizedString(@"TXT_CANCEL_TITLE", @"")
                                                           style:UIAlertActionStyleCancel
                                                         handler:^(UIAlertAction *_Nonnull action) { /* do nothing */ }];
    [invitationSheet addAction:cancelButton];
    
    [viewController presentViewController:invitationSheet animated:YES completion:[UIUtil modalCompletionBlock]];
}

#pragma mark - action button methods
-(void)mailTapped
{
#warning uncomment after contacts database issue is resolved
    [self inviteViaMailFrom:self.sourceController to:nil];
//    self.sendingMail = YES;
//    self.sendingSMS = NO;
//
//    UIStoryboard *storyboard = [UIStoryboard storyboardWithName:@"Main_v2" bundle:[NSBundle mainBundle]];
//    UINavigationController *navController = (UINavigationController *)[storyboard instantiateViewControllerWithIdentifier:@"ContactsPicker"];
//    FLContactSelectionTableViewController *pickerController = (FLContactSelectionTableViewController *)[navController topViewController];
//    pickerController.contactDelegate = self;
//
//    [self.sourceController presentViewController:pickerController.parentViewController animated:YES completion:nil];
}

-(void)smsTapped
{
#warning uncomment after contacts database issue is resolved
    [self inviteViaSMSFrom:self.sourceController to:nil];
//    self.sendingSMS = YES;
//    self.sendingMail = NO;
//    
//    UIStoryboard *storyboard = [UIStoryboard storyboardWithName:@"Main_v2" bundle:[NSBundle mainBundle]];
//    UINavigationController *navController = (UINavigationController *)[storyboard instantiateViewControllerWithIdentifier:@"ContactsPicker"];
//    FLContactSelectionTableViewController *pickerController = (FLContactSelectionTableViewController *)[navController topViewController];
//    pickerController.contactDelegate = self;
//    
//    [self.sourceController presentViewController:pickerController.parentViewController animated:YES completion:nil];
}

-(void)twitterTapped
{
    // just go to Twitter
    [self inviteViaTwitterFrom:self.sourceController to:nil];
}

#pragma mark - invitation methods
-(void)inviteViaSMSFrom:(nonnull UIViewController *)viewController to:(nullable NSArray *)recipients;
{
    if ([MFMessageComposeViewController canSendText]) {
        MFMessageComposeViewController *picker = [[MFMessageComposeViewController alloc] init];
        if (recipients.count > 0) {
            picker.recipients = recipients;
        }
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
    if (recipients.count > 0) {
        [mailController setToRecipients:recipients];
    }
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

#pragma mark - contact picker delegate methods
-(void)contactPickerDidCancelSelection:(id)sender
{
    UIViewController *vc = (UIViewController *)sender;
    [vc dismissViewControllerAnimated:YES completion:^{
        self.sendingMail = NO;
        self.sendingSMS = NO;
    }];
}

-(void)contactPicker:(id)sender didCompleteSelectionWithContacts:(NSArray *)selectedContacts
{
    UIViewController *vc = (UIViewController *)sender;
    [vc dismissViewControllerAnimated:YES completion:^{
        if (self.sendingSMS) {
            [self inviteViaSMSFrom:self.sourceController to:[self smsNumbersFromContacts:selectedContacts]];
        } else if (self.sendingMail) {
            [self inviteViaMailFrom:self.sourceController to:[self addressesFromContacts:selectedContacts]];
        }
        
        self.sendingMail = NO;
        self.sendingSMS = NO;
    }];
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

#warning Build out to interace with Address Book for invitations.
#pragma mark - convenience methods
-(NSArray *)smsNumbersFromContacts:(NSArray <Contact *> *)contacts
{
    NSMutableArray *holdingPen = [NSMutableArray new];
    
//    for (Contact *contact in contacts) {
//        if ([contact.userTextPhoneNumbers firstObject]) {
//            [holdingPen addObject:[contact.userTextPhoneNumbers firstObject]];
//        }
//    }
    return [NSArray arrayWithArray:holdingPen];
}

-(NSArray *)addressesFromContacts:(NSArray <Contact *> *)contacts
{
    NSMutableArray *holdingPen = [NSMutableArray new];
    
//    for (Contact *contact in contacts) {
//        if ([contact.emails firstObject]) {
//            [holdingPen addObject:[contact.emails firstObject]];
//        }
//    }
    return [NSArray arrayWithArray:holdingPen];
}

#pragma mark - lazy instantiation
//-(FLContactSelectionTableViewController *)pickerController
//{
//    if (_pickerController == nil) {
//        UIStoryboard *storyboard = [UIStoryboard storyboardWithName:@"Main_v2" bundle:[NSBundle mainBundle]];
//        UINavigationController *navController = (UINavigationController *)[storyboard instantiateViewControllerWithIdentifier:@"ContactsPicker"];
//        _pickerController = (FLContactSelectionTableViewController *)[navController topViewController];
//        _pickerController.contactDelegate = self;
//    }
//    return _pickerController;
//}

@end
