//
//  FLDirectoryCell.m
//  Forsta
//
//  Created by Mark on 7/31/17.
//  Copyright © 2017 Forsta. All rights reserved.
//

#import "FLDirectoryCell.h"
#import "UIFont+OWS.h"
#import "UIColor+OWS.h"
#import "OWSContactAvatarBuilder.h"
#import "Environment.h"
#import "SignalRecipient.h"
#import "UIImageView+Extension.h"

@implementation FLDirectoryCell

- (void)awakeFromNib {
    [super awakeFromNib];
    // Initialization code
//    self.avatarImageView.clipsToBounds = YES;
//    self.avatarImageView.layer.masksToBounds = YES;
    self.avatarImageView.circle = YES;
}

- (void)setSelected:(BOOL)selected animated:(BOOL)animated {
    [super setSelected:selected animated:animated];

    // Configure the view for the selected state
}

-(void)configureCellWithContact:(SignalRecipient *)recipient
{
    dispatch_async(dispatch_get_main_queue(), ^{
        
        self.nameLabel.attributedText = [self attributedStringForContact:recipient];
        self.detailLabel.text = recipient.orgSlug;
        
        UIImage *avatar = [Environment.getCurrent.contactsManager imageForRecipientId:recipient.uniqueId];
        
        if (avatar) {
            self.avatarImageView.image = avatar;
        } else {
            OWSContactAvatarBuilder *avatarBuilder = [[OWSContactAvatarBuilder alloc] initWithContactId:recipient.uniqueId
                                                                                                   name:recipient.fullName
                                                                                        contactsManager:[Environment getCurrent].contactsManager
                                                                                               diameter:self.avatarImageView.frame.size.height];
            self.avatarImageView.image = [avatarBuilder buildDefaultImage];
        }
    });
}

-(void)configureCellWithTag:(FLTag *)aTag
{
    NSString *description = nil;
    if ([aTag.uniqueId isEqualToString:SignalRecipient.selfRecipient.flTag.uniqueId]) {
        description = NSLocalizedString(@"ME_STRING", \@"");
    } else {
        description = aTag.tagDescription;
    }
    NSString *orgSlug = aTag.orgSlug;
    
    
    // Get an avatar
    dispatch_async(dispatch_get_main_queue(), ^{
        UIImage *avatar = nil;
        if (aTag.recipientIds.count == 1) {
            SignalRecipient *recipient = [Environment.getCurrent.contactsManager recipientWithUserID:[aTag.recipientIds anyObject]];
            avatar = [Environment.getCurrent.contactsManager imageForRecipientId:recipient.uniqueId];
            if (avatar == nil) {
                OWSContactAvatarBuilder *avatarBuilder = [[OWSContactAvatarBuilder alloc] initWithContactId:recipient.uniqueId
                                                                                                       name:recipient.fullName
                                                                                            contactsManager:Environment.getCurrent.contactsManager
                                                                                                   diameter:self.contentView.frame.size.height];
                avatar = [avatarBuilder buildDefaultImage];
                recipient.avatar = avatar;
                [Environment.getCurrent.contactsManager saveRecipient:recipient];
            }
        } else {
            OWSContactAvatarBuilder *avatarBuilder = [[OWSContactAvatarBuilder alloc] initWithContactId:aTag.uniqueId
                                                                                                   name:description
                                                                                        contactsManager:[Environment getCurrent].contactsManager
                                                                                               diameter:self.contentView.frame.size.height];
            avatar = [avatarBuilder buildDefaultImage];
        }
        self.nameLabel.text = description;
        self.detailLabel.text = orgSlug;
        self.avatarImageView.image = avatar;
    });
}

-(void)prepareForReuse
{
    
    [super prepareForReuse];
}

- (NSAttributedString *)attributedStringForContact:(SignalRecipient *)contact
{
    CGFloat fontSize = 17.0;
    UIFont *firstNameFont = [UIFont ows_regularFontWithSize:fontSize];
    UIFont *lastNameFont  = [UIFont ows_regularFontWithSize:fontSize];
    
    NSMutableAttributedString *fullNameAttributedString = nil;
//    NSString *displayString = nil;
    
    // If self...
    if ([contact.uniqueId isEqualToString:SignalRecipient.selfRecipient.uniqueId]) {
        fullNameAttributedString = [[NSMutableAttributedString alloc] initWithString:NSLocalizedString(@"ME_STRING", @"")];
        
        [fullNameAttributedString addAttribute:NSFontAttributeName
                                         value:lastNameFont
                                         range:NSMakeRange(0, fullNameAttributedString.length)];
        [fullNameAttributedString addAttribute:NSForegroundColorAttributeName
                                         value:[UIColor blackColor]
                                         range:NSMakeRange(0, fullNameAttributedString.length)];
    // Everyone else
    } else {
        fullNameAttributedString = [[NSMutableAttributedString alloc] initWithString:contact.fullName];
        
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
    }
    return fullNameAttributedString;
}

@end
