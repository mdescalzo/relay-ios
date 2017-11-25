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

@implementation FLDirectoryCell

- (void)awakeFromNib {
    [super awakeFromNib];
    // Initialization code
}

- (void)setSelected:(BOOL)selected animated:(BOOL)animated {
    [super setSelected:selected animated:animated];

    // Configure the view for the selected state
}

-(void)configureCellWithContact:(SignalRecipient *)recipient
{
    self.nameLabel.attributedText = [self attributedStringForContact:recipient];
    self.detailLabel.text = recipient.orgSlug;
    
    if (recipient.avatar) {
        self.avatarImageView.image = recipient.avatar;
    } else {
        OWSContactAvatarBuilder *avatarBuilder = [[OWSContactAvatarBuilder alloc] initWithContactId:recipient.uniqueId
                                                                                               name:recipient.fullName
                                                                                    contactsManager:[Environment getCurrent].contactsManager
                                                                                           diameter:self.contentView.frame.size.height];
        self.avatarImageView.image = [avatarBuilder buildDefaultImage];
    }
}

-(void)configureCellWithTag:(FLTag *)aTag
{
    NSString *description = nil;
    if ([aTag.uniqueId isEqualToString:SignalRecipient.selfRecipient.flTag.uniqueId]) {
        description = NSLocalizedString(@"ME_STRING", \@"");
    } else {
        description = aTag.tagDescription;
    }
    NSString *tagId = aTag.uniqueId;
    NSString *orgSlug = aTag.orgSlug;
    
    self.nameLabel.text = description;
    self.detailLabel.text = orgSlug;
    
    OWSContactAvatarBuilder *avatarBuilder = [[OWSContactAvatarBuilder alloc] initWithContactId:tagId
                                                                                           name:description
                                                                                contactsManager:[Environment getCurrent].contactsManager
                                                                                       diameter:self.contentView.frame.size.height];
    self.avatarImageView.image = [avatarBuilder buildDefaultImage];
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
