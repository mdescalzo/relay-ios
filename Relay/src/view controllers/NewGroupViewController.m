//
//  NewGroupViewController.m
//  Signal
//
//  Created by Dylan Bourgeois on 13/11/14.
//  Copyright (c) 2014 Open Whisper Systems. All rights reserved.
//

#import "NewGroupViewController.h"
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
#import "FLTagMathService.h"

@import MobileCoreServices;

static NSString *const kUnwindToMessagesViewSegue = @"UnwindToMessagesViewSegue";

@interface NewGroupViewController ()

@property TSThread *thread;
@property (nonatomic, readonly) OWSMessageSender *messageSender;
@property (strong) NSArray <SignalRecipient *> *contacts;

@end

@implementation NewGroupViewController

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
//                                                      contactsUpdater:[Environment getCurrent].contactsUpdater];
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
//                                                      contactsUpdater:[Environment getCurrent].contactsUpdater];
    return self;
}

- (void)configWithThread:(TSThread *)gThread {
    _thread = gThread;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    [self.navigationController.navigationBar setTranslucent:NO];

    self.tableView.tableHeaderView.frame = CGRectMake(0, 0, 400, 44);
    self.tableView.tableHeaderView       = self.tableView.tableHeaderView;

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
                                            action:@selector(updateGroup)];
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
            searchString =  [NSString stringWithFormat:@"@%@", recipient.tagSlug];
        } else {
            searchString = [searchString stringByAppendingString:[NSString stringWithFormat:@" @%@", recipient.tagSlug]];
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
   
//    [[TSStorageManager sharedManager]
//            .dbConnection readWriteWithBlock:^(YapDatabaseReadWriteTransaction *_Nonnull transaction) {
//      self.thread = [TSGroupThread getOrCreateThreadWithGroupModel:model transaction:transaction];
//                // Assign missing properties
//                self.thread.participants = [model.groupMemberIds copy];
//                NSMutableString *searchString = [NSMutableString new];
//                for (NSString *userid in self.thread.participants) {
//                    SignalRecipient *recipient = [SignalRecipient getOrCreateRecipientWithIndentifier:userid withTransaction:transaction];
//                    [searchString appendString:[NSString stringWithFormat:@" %@", recipient.tagSlug]];
//                }
//                [[FLTagMathService new] tagLookupWithString:searchString
//                                                    success:^(NSDictionary *results) {
//                                                        self.thread.universalExpression = [results objectForKey:@"universal"];
//                                                        [self.thread saveWithTransaction:transaction];
//                                                    }
//                                                    failure:^(NSError *error) {
//                                                        DDLogDebug(@"TagMathLookup failed.  Error: %@", error.localizedDescription);
//                                                        [self.thread saveWithTransaction:transaction];
//                                                    }];
//    }];

//    void (^popToThread)() = ^{
//        dispatch_async(dispatch_get_main_queue(), ^{
//            [self dismissViewControllerAnimated:YES
//                                     completion:^{
//                                         [Environment messageGroup:self.thread];
//                                     }];
//
//        });
//    };
//
//    void (^removeThreadWithError)(NSError *error) = ^(NSError *error) {
//        [self.thread remove];
//        dispatch_async(dispatch_get_main_queue(), ^{
//            [self dismissViewControllerAnimated:YES
//                                     completion:^{
//                                         SignalAlertView(NSLocalizedString(@"GROUP_CREATING_FAILED", nil),
//                                             error.localizedDescription);
//                                     }];
//        });
//    };
//
//    UIAlertController *alertController =
//        [UIAlertController alertControllerWithTitle:NSLocalizedString(@"GROUP_CREATING", nil)
//                                            message:nil
//                                     preferredStyle:UIAlertControllerStyleAlert];
//
//    [self presentViewController:alertController
//                       animated:YES
//                     completion:^{
//                         TSOutgoingMessage *message =
//                             [[TSOutgoingMessage alloc] initWithTimestamp:[NSDate ows_millisecondTimeStamp]
//                                                                 inThread:self.thread
//                                                              messageBody:@""
//                                                            attachmentIds:[NSMutableArray new]];
//
//                         message.groupMetaMessage = TSGroupMessageNew;
//                         message.customMessage = NSLocalizedString(@"GROUP_CREATED", nil);
//                         if (model.groupImage) {
//                             [self.messageSender sendAttachmentData:UIImagePNGRepresentation(model.groupImage)
//                                                        contentType:OWSMimeTypeImagePng
//                                                          inMessage:message
//                                                            success:popToThread
//                                                            failure:removeThreadWithError];
//                         } else {
//                             [self.messageSender sendMessage:message success:popToThread failure:removeThreadWithError];
//                         }
//                     }];
}


- (void)updateGroup
{
    // TODO: throw a threadUpdate control message here.
    NSMutableArray *mut = [[NSMutableArray alloc] init];
    for (NSIndexPath *idx in _tableView.indexPathsForSelectedRows) {
        [mut addObject:[[self.contacts objectAtIndex:(NSUInteger)idx.row] uniqueId]];
    }
    [mut addObjectsFromArray:self.thread.participants];

    _groupModel = [[TSGroupModel alloc] initWithTitle:self.nameGroupTextField.text
                                            memberIds:[[[NSSet setWithArray:mut] allObjects] mutableCopy]
                                                image:self.thread.image
                                              groupId:nil];

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

    NSUInteger row   = (NSUInteger)indexPath.row;
    SignalRecipient *contact = self.contacts[row];

    [cell configureCellWithContact:contact];
//    cell.nameLabel.attributedText = [self attributedStringForContact:contact inCell:cell];
    cell.accessoryType    = UITableViewCellAccessoryNone;

    tableView.tableFooterView = [[UIView alloc] initWithFrame:CGRectZero];

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

//    if (ABPersonGetSortOrdering() == kABPersonCompositeNameFormatFirstNameFirst) {
//        firstNameFont = [UIFont ows_mediumFontWithSize:cell.textLabel.font.pointSize];
//        lastNameFont  = [UIFont ows_regularFontWithSize:cell.textLabel.font.pointSize];
//    } else {
        firstNameFont = [UIFont ows_regularFontWithSize:cell.textLabel.font.pointSize];
        lastNameFont  = [UIFont ows_mediumFontWithSize:cell.textLabel.font.pointSize];
//    }
    [fullNameAttributedString addAttribute:NSFontAttributeName
                                     value:firstNameFont
                                     range:NSMakeRange(0, contact.firstName.length)];
    [fullNameAttributedString addAttribute:NSFontAttributeName
                                     value:lastNameFont
                                     range:NSMakeRange(contact.firstName.length + 1, contact.lastName.length)];

    [fullNameAttributedString addAttribute:NSForegroundColorAttributeName
                                     value:[UIColor blackColor]
                                     range:NSMakeRange(0, contact.fullName.length)];

//    if (ABPersonGetSortOrdering() == kABPersonCompositeNameFormatFirstNameFirst) {
//        [fullNameAttributedString addAttribute:NSForegroundColorAttributeName
//                                         value:[UIColor ows_darkGrayColor]
//                                         range:NSMakeRange(contact.firstName.length + 1, contact.lastName.length)];
//    } else {
        [fullNameAttributedString addAttribute:NSForegroundColorAttributeName
                                         value:[UIColor ows_darkGrayColor]
                                         range:NSMakeRange(0, contact.firstName.length)];
//    }

    return fullNameAttributedString;
}

#pragma mark - accessors
-(void)setContacts:(NSArray<SignalRecipient *> *)value
{
    if (![value isEqual:_contacts]) {
        _contacts = value;
    }
}

-(NSArray <SignalRecipient *> *)contacts
{
    if (_contacts == nil) {
        
        NSMutableArray *mArray = [Environment.getCurrent.contactsManager.ccsmRecipients mutableCopy];
        [mArray removeObject:TSAccountManager.sharedInstance.myself];
        
        NSSortDescriptor *lastNameSD = [[NSSortDescriptor alloc] initWithKey:@"lastName"
                                                                   ascending:YES
                                                                    selector:@selector(localizedCaseInsensitiveCompare:)];
        NSSortDescriptor *firstNameSD = [[NSSortDescriptor alloc] initWithKey:@"firstName"
                                                                    ascending:YES
                                                                     selector:@selector(localizedCaseInsensitiveCompare:)];
        NSSortDescriptor *orgSD = [[NSSortDescriptor alloc] initWithKey:@"orgSlug"
                                                              ascending:YES
                                                               selector:@selector(localizedCaseInsensitiveCompare:)];
        
        
        
        _contacts = [[NSArray arrayWithArray:mArray] sortedArrayUsingDescriptors:@[ lastNameSD, firstNameSD, orgSD ]];
        
    }
    return _contacts;
}


@end
