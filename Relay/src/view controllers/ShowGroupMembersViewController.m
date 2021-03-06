//
//  ShowGroupMembersViewController.m
//  Signal
//
//  Created by Dylan Bourgeois on 13/11/14.
//  Copyright (c) 2014 Open Whisper Systems. All rights reserved.
//

#import "ShowGroupMembersViewController.h"


#import "SignalsViewController.h"

#import "FLContactsManager.h"
#import "Environment.h"
#import "GroupContactsResult.h"
#import "FLDirectoryCell.h"
#import "UIUtil.h"

#import <AddressBookUI/AddressBookUI.h>

static NSString *const kUnwindToMessagesViewSegue = @"UnwindToMessagesViewSegue";

@interface ShowGroupMembersViewController ()

//@property GroupContactsResult *groupContacts;
@property (nonatomic, strong) NSArray<SignalRecipient *> *participants;
@property (nonatomic, strong) TSThread *thread;

@end

@implementation ShowGroupMembersViewController

- (void)configWithThread:(TSThread *)gThread {
    _thread = gThread;
    [self participants];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    [self.navigationController.navigationBar setTranslucent:NO];

    self.title = _thread.name;

    [self initializeTableView];

//    self.groupContacts =
//        [[GroupContactsResult alloc] initWithMembersId:self.thread.participants without:nil];
//
//    [[Environment.getCurrent contactsManager]
//            .getObservableContacts watchLatestValue:^(id latestValue) {
//      self.groupContacts =
//          [[GroupContactsResult alloc] initWithMembersId:self.thread.participants without:nil];
//      [self.tableView reloadData];
//    }
//                                           onThread:[NSThread mainThread]
//                                     untilCancelled:nil];
}

#pragma mark - Initializers


- (void)initializeTableView {
    self.tableView.tableFooterView = [[UIView alloc] initWithFrame:CGRectZero];
}

#pragma mark - Actions

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
//    return (NSInteger)[self.groupContacts numberOfMembers] + 1;
    return (NSInteger)self.participants.count + 1;
}

-(CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    return 65.0;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell;// = [tableView dequeueReusableCellWithIdentifier:@"SearchCell"];
//
//    if (cell == nil) {
//        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault
//                                      reuseIdentifier:indexPath.row == 0 ? @"HeaderCell" : @"GroupSearchCell"];
//    }
    if (indexPath.row > 0) {  //  Not the header.
        FLDirectoryCell *tmpCell = (FLDirectoryCell *)[tableView dequeueReusableCellWithIdentifier:@"GroupSearchCell" forIndexPath:indexPath];
        
        NSIndexPath *relativeIndexPath = [NSIndexPath indexPathForRow:indexPath.row - 1 inSection:indexPath.section];
//        if ([self.groupContacts isContactAtIndexPath:relativeIndexPath]) {
//            SignalRecipient *contact = [self contactForIndexPath:relativeIndexPath];
//            [tmpCell configureCellWithContact:contact];
////            cell.textLabel.attributedText = [self attributedStringForContact:contact inCell:cell];
//
//        } else {
//            tmpCell.nameLabel.text = [self.groupContacts identifierForIndexPath:relativeIndexPath];
//        }
        [tmpCell configureCellWithContact:[self.participants objectAtIndex:(NSUInteger)relativeIndexPath.row]];
        cell = tmpCell;
    } else {     //  Configure the header
        cell = [tableView dequeueReusableCellWithIdentifier:@"HeaderCell" forIndexPath:indexPath];
        cell.textLabel.text      = NSLocalizedString(@"GROUP_MEMBERS_HEADER", @"header for table which lists the members of this group thread");
        cell.textLabel.textColor = [UIColor lightGrayColor];
        cell.selectionStyle      = UITableViewCellSelectionStyleNone;
        cell.userInteractionEnabled = NO;
    }

    tableView.tableFooterView = [[UIView alloc] initWithFrame:CGRectZero];

    return cell;
}


- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
#warning Replace with method in the ContactsManager
    ABUnknownPersonViewController *view = [[ABUnknownPersonViewController alloc] init];

    NSIndexPath *relativeIndexPath = [NSIndexPath indexPathForRow:indexPath.row - 1 inSection:indexPath.section];
    SignalRecipient *recipient = [self.participants objectAtIndex:(NSUInteger)relativeIndexPath.row];
    
    ABRecordRef aContact = ABPersonCreate();
    
    CFErrorRef anError   = NULL;
    
    if (recipient.lastName) {
        ABRecordSetValue(aContact, kABPersonLastNameProperty, (__bridge CFTypeRef)(recipient.lastName), &anError);
    }
    if (recipient.firstName) {
        ABRecordSetValue(aContact, kABPersonFirstNameProperty, (__bridge CFTypeRef)(recipient.firstName), &anError);
    }
    if (recipient.email) {
        ABMultiValueRef email = ABMultiValueCreateMutable(kABMultiStringPropertyType);
        ABMultiValueAddValueAndLabel(email, (__bridge CFTypeRef)recipient.email, kABOtherLabel, NULL);
        ABRecordSetValue(aContact, kABPersonEmailProperty, email, nil);
        CFRelease(email);
    }
    
    if (recipient.phoneNumber) {
        ABMultiValueRef phone = ABMultiValueCreateMutable(kABMultiStringPropertyType);
        ABMultiValueAddValueAndLabel(
                                     phone,
                                     (__bridge CFTypeRef)recipient.phoneNumber,
                                     kABPersonPhoneMainLabel,
                                     NULL);
        
        ABRecordSetValue(aContact, kABPersonPhoneProperty, phone, &anError);
        CFRelease(phone);
    }
    
    if (recipient.avatar) {
        NSData *imageData = UIImagePNGRepresentation(recipient.avatar);
        ABPersonSetImageData (aContact, (__bridge CFDataRef)imageData, &anError);
    }
    
    if (!anError /* && aContact */) {
        view.displayedPerson           = aContact; // Assume person is already defined.
        view.allowsAddingToAddressBook = YES;
        [self.navigationController pushViewController:view animated:YES];
    }
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
}

//- (SignalRecipient *)contactForIndexPath:(NSIndexPath *)indexPath {
//    SignalRecipient *contact = [self.groupContacts contactForIndexPath:indexPath];
//    return contact;
//}

#pragma mark - Cell Utility

- (NSAttributedString *)attributedStringForContact:(SignalRecipient *)contact inCell:(UITableViewCell *)cell {
    NSMutableAttributedString *fullNameAttributedString =
        [[NSMutableAttributedString alloc] initWithString:contact.fullName];

    UIFont *firstNameFont;
    UIFont *lastNameFont;

    if (ABPersonGetSortOrdering() == kABPersonCompositeNameFormatFirstNameFirst) {
        firstNameFont = [UIFont ows_mediumFontWithSize:cell.textLabel.font.pointSize];
        lastNameFont  = [UIFont ows_regularFontWithSize:cell.textLabel.font.pointSize];
    } else {
        firstNameFont = [UIFont ows_regularFontWithSize:cell.textLabel.font.pointSize];
        lastNameFont  = [UIFont ows_mediumFontWithSize:cell.textLabel.font.pointSize];
    }
    [fullNameAttributedString addAttribute:NSFontAttributeName
                                     value:firstNameFont
                                     range:NSMakeRange(0, contact.firstName.length)];
    [fullNameAttributedString addAttribute:NSFontAttributeName
                                     value:lastNameFont
                                     range:NSMakeRange(contact.firstName.length + 1, contact.lastName.length)];

    [fullNameAttributedString addAttribute:NSForegroundColorAttributeName
                                     value:[UIColor blackColor]
                                     range:NSMakeRange(0, contact.fullName.length)];

    if (ABPersonGetSortOrdering() == kABPersonCompositeNameFormatFirstNameFirst) {
        [fullNameAttributedString addAttribute:NSForegroundColorAttributeName
                                         value:[UIColor ows_darkGrayColor]
                                         range:NSMakeRange(contact.firstName.length + 1, contact.lastName.length)];
    } else {
        [fullNameAttributedString addAttribute:NSForegroundColorAttributeName
                                         value:[UIColor ows_darkGrayColor]
                                         range:NSMakeRange(0, contact.firstName.length)];
    }
    return fullNameAttributedString;
}

#pragma mark - Accessors
-(NSArray<SignalRecipient *> *)participants
{
    if (_participants == nil) {
        NSMutableArray *holdingArray = [NSMutableArray new];
        for (NSString *uid in self.thread.participants) {
            SignalRecipient *recipient = [Environment.getCurrent.contactsManager recipientWithUserId:uid];
            if (recipient) {
                [holdingArray addObject:recipient];
            }
        }
        _participants = [NSArray arrayWithArray:holdingArray];
    }
    return _participants;
}

@end
