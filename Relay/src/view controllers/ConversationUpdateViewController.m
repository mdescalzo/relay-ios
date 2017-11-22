//
//  ConversationUpdateViewController.m
//  Signal
//
//  Created by Dylan Bourgeois on 13/11/14.
//  Copyright (c) 2014 Open Whisper Systems. All rights reserved.
//

#import "ConversationUpdateViewController.h"
#import "DJWActionSheet+OWS.h"
#import "Environment.h"
#import "FunctionalUtil.h"
#import "OWSContactsManager.h"
#import "SecurityUtils.h"
#import "SignalKeyingStorage.h"
#import "SignalsViewController.h"
#import "TSOutgoingMessage.h"
#import "UIImage+normalizeImage.h"
#import "UIUtil.h"
#import "MimeTypeUtil.h"
#import "NSDate+millisecondTimeStamp.h"
#import "OWSMessageSender.h"
#import "TSAccountManager.h"
#import "FLDirectoryCell.h"
#import "FLControlMessage.h"
#import "FLTagMathService.h"
#import "TSInfoMessage.h"

@import MobileCoreServices;

static NSString *const kUnwindToMessagesViewSegue = @"UnwindToMessagesViewSegue";

@interface ConversationUpdateViewController ()

@property TSThread *thread;
@property (readonly) OWSMessageSender *messageSender;
@property NSArray <SignalRecipient *> *contacts;
@property (readonly) NSArray <SignalRecipient *> *selectedRecipients;
@property NSString *originalThreadName;
@property NSCountedSet *originalThreadParticipants;
@property UIImage *originalThreadAvatar;

@end

@implementation ConversationUpdateViewController

@synthesize contacts = _contacts;

- (instancetype)init
{
    self = [super init];
    if (!self) {
        return self;
    }

    _messageSender = [[OWSMessageSender alloc] initWithNetworkManager:[Environment getCurrent].networkManager
                                                       storageManager:[TSStorageManager sharedManager]
                                                      contactsManager:[Environment getCurrent].contactsManager];
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)aDecoder
{
    self = [super initWithCoder:aDecoder];
    if (!self) {
        return self;
    }

    _messageSender = [[OWSMessageSender alloc] initWithNetworkManager:[Environment getCurrent].networkManager
                                                       storageManager:[TSStorageManager sharedManager]
                                                      contactsManager:[Environment getCurrent].contactsManager];
    return self;
}

- (void)configWithThread:(TSThread *)gThread
{
    _thread = gThread;
    
    _originalThreadName = self.thread.name;
    _originalThreadParticipants = [NSCountedSet setWithArray:self.thread.participants];
    _originalThreadAvatar = self.thread.image;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    [self.navigationController.navigationBar setTranslucent:NO];

    self.tableView.tableHeaderView.frame = CGRectMake(0, 0, 400, 44);
    self.tableView.tableHeaderView       = self.tableView.tableHeaderView;
    self.tableView.tableFooterView = [[UIView alloc] initWithFrame:CGRectZero];

    [self initializeDelegates];
    [self initializeTableView];
    [self initializeKeyboardHandlers];

    if (_thread == nil) {
        self.navigationItem.rightBarButtonItem =
            [[UIBarButtonItem alloc] initWithImage:[[UIImage imageNamed:@"add-conversation"]
                                                       imageWithRenderingMode:UIImageRenderingModeAlwaysOriginal]
                                             style:UIBarButtonItemStylePlain
                                            target:self
                                            action:@selector(createGroup)];
        self.navigationItem.rightBarButtonItem.imageInsets = UIEdgeInsetsMake(0, -10, 0, 10);
        self.navigationItem.title                          = NSLocalizedString(@"NEW_GROUP_DEFAULT_TITLE", @"");
    } else {
        self.navigationItem.rightBarButtonItem =
            [[UIBarButtonItem alloc] initWithTitle:NSLocalizedString(@"UPDATE_BUTTON_TITLE", @"")
                                             style:UIBarButtonItemStylePlain
                                            target:self
                                            action:@selector(updateConversation)];
        self.navigationItem.title    = _thread.name;
        self.nameGroupTextField.text = _thread.name;
        if (_thread.image != nil) {
            _groupImage = _thread.image;
            [self setupGroupImageButton:_thread.image];
        }
    }
    _nameGroupTextField.placeholder = NSLocalizedString(@"NEW_GROUP_NAMEGROUP_REQUEST_DEFAULT", @"");
    _addPeopleLabel.text            = NSLocalizedString(@"NEW_GROUP_REQUEST_ADDPEOPLE", @"");
}

-(void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    self.contacts = nil;
}

#pragma mark - Initializers

- (void)initializeDelegates {
    self.nameGroupTextField.delegate = self;
}

- (void)initializeTableView {
    self.tableView.tableFooterView = [[UIView alloc] initWithFrame:CGRectZero];
}

#pragma mark - Keyboard notifications

- (void)initializeKeyboardHandlers {
    UITapGestureRecognizer *outsideTabRecognizer =
        [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(dismissKeyboardFromAppropriateSubView)];
    [self.tapToDismissView addGestureRecognizer:outsideTabRecognizer];
}

- (void)dismissKeyboardFromAppropriateSubView {
    [self.nameGroupTextField resignFirstResponder];
}


#pragma mark - Actions
- (void)createGroup
{
    __block TSGroupModel *model = [self makeGroup];

    // Get parts
    NSString *searchString = nil;
    for (NSString *userid in model.groupMemberIds) {
        SignalRecipient *recipient = [SignalRecipient recipientWithTextSecureIdentifier:userid];
        if (searchString.length == 0) {
            searchString =  [NSString stringWithFormat:@"@%@", recipient.flTag.slug];
        } else {
            searchString = [searchString stringByAppendingString:[NSString stringWithFormat:@" @%@", recipient.flTag.slug]];
        }
    }
    
    [FLTagMathService asyncTagLookupWithString:searchString
                                        success:^(NSDictionary *results) {
                                            self.thread = [TSThread getOrCreateThreadWithID:[[NSUUID UUID] UUIDString]];
                                            self.thread.name = model.groupName;
                                            self.thread.image = model.groupImage;
                                            self.thread.universalExpression = [results objectForKey:@"universal"];
                                            self.thread.participants = [results objectForKey:@"userids"];
                                            self.thread.prettyExpression = [results objectForKey:@"pretty"];
                                            [self.thread save];
                                            
                                            void (^popToThread)() = ^{
                                                dispatch_async(dispatch_get_main_queue(), ^{
                                                    [self dismissViewControllerAnimated:YES
                                                                             completion:^{
                                                                                 [Environment messageGroup:self.thread];
                                                                             }];
                                                    
                                                });
                                            };
                                            
                                            void (^removeThreadWithError)(NSError *error) = ^(NSError *error) {
                                                [self.thread remove];
                                                dispatch_async(dispatch_get_main_queue(), ^{
                                                    [self dismissViewControllerAnimated:YES
                                                                             completion:^{
                                                                                 SignalAlertView(NSLocalizedString(@"GROUP_CREATING_FAILED", nil),
                                                                                                 error.localizedDescription);
                                                                             }];
                                                });
                                            };
                                            dispatch_async(dispatch_get_main_queue(), ^{

                                            UIAlertController *alertController =
                                            [UIAlertController alertControllerWithTitle:NSLocalizedString(@"GROUP_CREATING", nil)
                                                                                message:nil
                                                                         preferredStyle:UIAlertControllerStyleAlert];
                                            
                                            [self presentViewController:alertController
                                                               animated:YES
                                                             completion:^{
                                                                 TSOutgoingMessage *message =
                                                                 [[TSOutgoingMessage alloc] initWithTimestamp:[NSDate ows_millisecondTimeStamp]
                                                                                                     inThread:self.thread
                                                                                                  messageBody:@""
                                                                                                attachmentIds:[NSMutableArray new]];
                                                                 
                                                                 message.groupMetaMessage = TSGroupMessageNew;
                                                                 message.customMessage = NSLocalizedString(@"GROUP_CREATED", nil);
                                                                 if (model.groupImage) {
                                                                     [self.messageSender sendAttachmentData:UIImagePNGRepresentation(model.groupImage)
                                                                                                   filename:@""
                                                                                                contentType:OWSMimeTypeImagePng
                                                                                                  inMessage:message
                                                                                                    success:popToThread
                                                                                                    failure:removeThreadWithError];
                                                                 } else {
                                                                     [self.messageSender sendMessage:message success:popToThread failure:removeThreadWithError];
                                                                 }
                                                             }];
                                            }); 
                                        }
                                        failure:^(NSError *error) {
                                            DDLogDebug(@"TagMathLookup failed.  Error: %@", error.localizedDescription);
#warning XXX insert warning here
                                        }];
   
}


- (void)updateConversation
{
    // Make sure something changed
    if (![self.originalThreadAvatar isEqual:self.groupImage] ||
        ![self.originalThreadName isEqualToString:self.nameGroupTextField.text] ||
        self.selectedRecipients.count > 0) {
        
        // Handle title change
        if (![self.originalThreadName isEqualToString:self.nameGroupTextField.text]) {
            self.thread.name = self.nameGroupTextField.text;
            NSString *messageFormat = NSLocalizedString(@"THREAD_TITLE_UPDATE_MESSAGE", @"Thread title update message");
            NSString *customMessage = [NSString stringWithFormat:messageFormat, NSLocalizedString(@"YOU_STRING", nil)];
            
            TSInfoMessage *infoMessage = [[TSInfoMessage alloc] initWithTimestamp:[NSDate ows_millisecondTimeStamp]
                                                                         inThread:self.thread
                                                                      messageType:TSInfoMessageTypeConversationUpdate
                                                                    customMessage:customMessage];
            [infoMessage save];
        }
        
        // Handle participant change
        NSCountedSet *participants = [NSCountedSet setWithArray:self.thread.participants];
        NSCountedSet *newParticipants = nil;
        if (self.selectedRecipients.count > 0) {
            NSMutableString *lookupString = [self.thread.prettyExpression mutableCopy]; // [NSMutableString new];  <-- switch back to this to allow client to remove participants.
            for (SignalRecipient *recipient in self.selectedRecipients) {
                [lookupString appendString:[NSString stringWithFormat:@"@%@:%@ ", recipient.flTag.slug, recipient.orgSlug]];
            }
            if (lookupString.length > 0) {
                NSDictionary *lookupDict = [FLTagMathService syncTagLookupWithString:lookupString];
                if (lookupDict) {
                    newParticipants = [NSCountedSet setWithArray:[lookupDict objectForKey:@"userids"]];
                    self.thread.participants = [lookupDict objectForKey:@"userids"];
                    self.thread.prettyExpression = [lookupDict objectForKey:@"pretty"];
                    self.thread.universalExpression = [lookupDict objectForKey:@"universal"];
                    [self.thread save];
                    
                    [participants unionSet:newParticipants];
                    
                    // Post info message for membership changes
                    if (![self.originalThreadParticipants isEqual:newParticipants]) {
                        NSCountedSet *leaving = [self.originalThreadParticipants copy];
                        [leaving minusSet:newParticipants];
                        for (NSString *uid in leaving) {
                            NSString *messageFormat = NSLocalizedString(@"GROUP_MEMBER_LEFT", nil);
                            SignalRecipient *recipient = [SignalRecipient recipientWithTextSecureIdentifier:uid];
                            NSString *customMessage = [NSString stringWithFormat:messageFormat, recipient.fullName];
                            
                            TSInfoMessage *infoMessage = [[TSInfoMessage alloc] initWithTimestamp:[NSDate ows_millisecondTimeStamp]
                                                                                         inThread:self.thread
                                                                                      messageType:TSInfoMessageTypeConversationUpdate
                                                                                    customMessage:customMessage];
                            [infoMessage save];
                        }
                        
                        NSCountedSet *joining = [newParticipants copy];
                        [joining minusSet:self.originalThreadParticipants];
                        for (NSString *uid in joining) {
                            NSString *messageFormat = NSLocalizedString(@"GROUP_MEMBER_JOINED", nil);
                            SignalRecipient *recipient = [SignalRecipient recipientWithTextSecureIdentifier:uid];
                            NSString *customMessage = [NSString stringWithFormat:messageFormat, recipient.fullName];
                            
                            TSInfoMessage *infoMessage = [[TSInfoMessage alloc] initWithTimestamp:[NSDate ows_millisecondTimeStamp]
                                                                                         inThread:self.thread
                                                                                      messageType:TSInfoMessageTypeConversationUpdate
                                                                                    customMessage:customMessage];
                            [infoMessage save];
                        }
                    }
                }
            }
        }
        
        // Build control message
        FLControlMessage *message = [[FLControlMessage alloc] initThreadUpdateControlMessageForThread:self.thread
                                                                                               ofType:FLControlMessageThreadUpdateKey];
        
        // Thread image update handling
        if (![self.originalThreadAvatar isEqual:self.groupImage]) {
            self.thread.image = self.groupImage;
            [self.thread save];
            
            NSString *messageFormat = NSLocalizedString(@"THREAD_IMAGE_CHANGED_MESSAGE", nil);
            NSString *customMessage = [NSString stringWithFormat:messageFormat, NSLocalizedString(@"YOU_STRING", nil)];
            TSInfoMessage *infoMessage = [[TSInfoMessage alloc] initWithTimestamp:[NSDate ows_millisecondTimeStamp]
                                                                         inThread:self.thread
                                                                      messageType:TSInfoMessageTypeConversationUpdate
                                                                    customMessage:customMessage];
            [infoMessage save];
            
            NSData *imageData = UIImagePNGRepresentation(self.thread.image);
            [Environment.getCurrent.messageSender sendAttachmentData:imageData
                                                            filename:@""
                                                         contentType:OWSMimeTypeImagePng
                                                           inMessage:message
                                                             success:^{
                                                                 DDLogDebug(@"Successfully sent avatar update.");
                                                             }
                                                             failure:^(NSError *error) {
                                                                 DDLogError(@"Error sending avatar update control message: %@", error.localizedDescription);
                                                             }];
        } else {
            // Send the control message without attachment
            [Environment.getCurrent.messageSender sendControlMessage:message toRecipients:participants];
        }
    }
    [self.nameGroupTextField resignFirstResponder];
    [self performSegueWithIdentifier:kUnwindToMessagesViewSegue sender:self];
}


- (TSGroupModel *)makeGroup
{
    NSString *title     = _nameGroupTextField.text;
    NSMutableArray *mut = [[NSMutableArray alloc] init];

    for (NSIndexPath *idx in _tableView.indexPathsForSelectedRows) {
        [mut addObject:[[self.contacts objectAtIndex:(NSUInteger)idx.row] uniqueId]];
    }
    [mut addObject:[TSAccountManager localNumber]];
    NSData *groupId = [SecurityUtils generateRandomBytes:16];

    return [[TSGroupModel alloc] initWithTitle:title memberIds:mut image:_groupImage groupId:groupId];
}

- (IBAction)addGroupPhoto:(id)sender {
    [self.nameGroupTextField resignFirstResponder];
    [DJWActionSheet showInView:self.parentViewController.view
                     withTitle:nil
             cancelButtonTitle:NSLocalizedString(@"TXT_CANCEL_TITLE", @"")
        destructiveButtonTitle:nil
             otherButtonTitles:@[
                 NSLocalizedString(@"TAKE_PICTURE_BUTTON", @""),
                 NSLocalizedString(@"CHOOSE_MEDIA_BUTTON", @"")
             ]
                      tapBlock:^(DJWActionSheet *actionSheet, NSInteger tappedButtonIndex) {

                        if (tappedButtonIndex == actionSheet.cancelButtonIndex) {
                            DDLogDebug(@"User Cancelled");
                        } else if (tappedButtonIndex == actionSheet.destructiveButtonIndex) {
                            DDLogDebug(@"Destructive button tapped");
                        } else {
                            switch (tappedButtonIndex) {
                                case 0:
                                    [self takePicture];
                                    break;
                                case 1:
                                    [self chooseFromLibrary];
                                    break;
                                default:
                                    break;
                            }
                        }
                      }];
}

#pragma mark - Group Image

- (void)takePicture {
    UIImagePickerController *picker = [[UIImagePickerController alloc] init];
    picker.delegate                 = self;
    picker.allowsEditing            = NO;
    picker.sourceType               = UIImagePickerControllerSourceTypeCamera;

    if ([UIImagePickerController isSourceTypeAvailable:UIImagePickerControllerSourceTypeCamera]) {
        picker.mediaTypes = [[NSArray alloc] initWithObjects:(NSString *)kUTTypeImage, nil];
        [self presentViewController:picker animated:YES completion:[UIUtil modalCompletionBlock]];
    }
}

- (void)chooseFromLibrary {
    UIImagePickerController *picker = [[UIImagePickerController alloc] init];
    picker.delegate                 = self;
    picker.sourceType               = UIImagePickerControllerSourceTypeSavedPhotosAlbum;

    if ([UIImagePickerController isSourceTypeAvailable:UIImagePickerControllerSourceTypeSavedPhotosAlbum]) {
        picker.mediaTypes = [[NSArray alloc] initWithObjects:(NSString *)kUTTypeImage, nil];
        [self presentViewController:picker animated:YES completion:[UIUtil modalCompletionBlock]];
    }
}

/*
 *  Dismissing UIImagePickerController
 */

- (void)imagePickerControllerDidCancel:(UIImagePickerController *)picker {
    [self dismissViewControllerAnimated:YES completion:nil];
}

/*
 *  Fetch data from UIImagePickerController
 */
- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary *)info {
    UIImage *picture_camera = [info objectForKey:UIImagePickerControllerOriginalImage];

    if (picture_camera) {
        UIImage *small = [picture_camera resizedImageToFitInSize:CGSizeMake(100.00, 100.00) scaleIfSmaller:NO];
        _thread.image                 = small;
        _groupImage                   = small;
        [self setupGroupImageButton:small];
    }
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)setupGroupImageButton:(UIImage *)image {
    [_groupImageButton setImage:image forState:UIControlStateNormal];
    _groupImageButton.imageView.layer.cornerRadius  = CGRectGetWidth([_groupImageButton.imageView frame]) / 2.0f;
    _groupImageButton.imageView.layer.masksToBounds = YES;
    _groupImageButton.imageView.layer.borderColor   = [[UIColor lightGrayColor] CGColor];
    _groupImageButton.imageView.layer.borderWidth   = 0.5f;
    _groupImageButton.imageView.contentMode = UIViewContentModeScaleAspectFill;
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return (NSInteger)[self.contacts count];
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    return 60.0f;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    FLDirectoryCell *cell = (FLDirectoryCell *)[tableView dequeueReusableCellWithIdentifier:@"GroupSearchCell" forIndexPath:indexPath];

    SignalRecipient *recipient = [self.contacts objectAtIndex:(NSUInteger)indexPath.row];

    [cell configureCellWithContact:recipient];
    cell.accessoryType    = UITableViewCellAccessoryNone;

    // TODO: Re-enable this to allow clien to remove participants.
//    if ([self.thread.participants containsObject:recipient.uniqueId]) {
//        [tableView selectRowAtIndexPath:indexPath animated:NO scrollPosition:UITableViewScrollPositionNone];
//    }
    
    if ([[tableView indexPathsForSelectedRows] containsObject:indexPath]) {
        [self adjustSelected:cell];
    }

    return cell;
}

#pragma mark - Table View delegate
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView cellForRowAtIndexPath:indexPath];
    [self adjustSelected:cell];
}

- (void)adjustSelected:(UITableViewCell *)cell {
    cell.accessoryType = UITableViewCellAccessoryCheckmark;
}

- (void)tableView:(UITableView *)tableView didDeselectRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView cellForRowAtIndexPath:indexPath];
    cell.accessoryType    = UITableViewCellAccessoryNone;
}

#pragma mark - Text Field Delegate

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    [self.nameGroupTextField resignFirstResponder];
    return NO;
}

#pragma mark - Cell Utility
- (NSAttributedString *)attributedStringForContact:(SignalRecipient *)contact inCell:(UITableViewCell *)cell {
    NSMutableAttributedString *fullNameAttributedString =
    [[NSMutableAttributedString alloc] initWithString:contact.fullName];
    
    UIFont *firstNameFont;
    UIFont *lastNameFont;
    
    firstNameFont = [UIFont ows_mediumFontWithSize:cell.textLabel.font.pointSize];
    lastNameFont  = [UIFont ows_mediumFontWithSize:cell.textLabel.font.pointSize];
    
    [fullNameAttributedString addAttribute:NSFontAttributeName
                                     value:firstNameFont
                                     range:NSMakeRange(0, contact.firstName.length)];
    [fullNameAttributedString addAttribute:NSFontAttributeName
                                     value:lastNameFont
                                     range:NSMakeRange(contact.firstName.length + 1, contact.lastName.length)];
    [fullNameAttributedString addAttribute:NSForegroundColorAttributeName
                                     value:[UIColor blackColor]
                                     range:NSMakeRange(0, contact.fullName.length)];
    [fullNameAttributedString addAttribute:NSForegroundColorAttributeName
                                     value:[UIColor blackColor]
                                     range:NSMakeRange(0, contact.firstName.length)];
    return fullNameAttributedString;
}

#pragma mark - accessors
-(NSArray <SignalRecipient *> *)contacts
{
    if (_contacts == nil) {
        NSMutableArray *mArray = [[SignalRecipient allObjectsInCollection] mutableCopy];
        
        // Remove self from the array.
        [mArray removeObject:TSAccountManager.sharedInstance.myself.flTag];
        
        NSSortDescriptor *lastNameSD = [[NSSortDescriptor alloc] initWithKey:@"lastName"
                                                                   ascending:YES
                                                                    selector:@selector(localizedCaseInsensitiveCompare:)];
        NSSortDescriptor *firstNameSD = [[NSSortDescriptor alloc] initWithKey:@"firstName"
                                                                    ascending:YES
                                                                     selector:@selector(localizedCaseInsensitiveCompare:)];
//        NSSortDescriptor *descriptionSD = [[NSSortDescriptor alloc] initWithKey:@"tagDescription"
//                                                                   ascending:YES
//                                                                    selector:@selector(localizedCaseInsensitiveCompare:)];
        NSSortDescriptor *orgSD = [[NSSortDescriptor alloc] initWithKey:@"orgSlug"
                                                              ascending:YES
                                                               selector:@selector(localizedCaseInsensitiveCompare:)];
        
        _contacts = [[NSArray arrayWithArray:mArray] sortedArrayUsingDescriptors:@[ lastNameSD, firstNameSD, orgSD ]];
    }
    return _contacts;
}

-(NSArray <SignalRecipient *> *)selectedRecipients
{
    NSMutableArray *holdingArray = [NSMutableArray new];
    for (NSIndexPath *indexPath in [self.tableView indexPathsForSelectedRows]) {
        [holdingArray addObject:[self.contacts objectAtIndex:(NSUInteger)indexPath.row]];
    }
    return [NSArray arrayWithArray:holdingArray];
}

@end
