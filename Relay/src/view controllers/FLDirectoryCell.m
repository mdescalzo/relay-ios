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
    NSString *description = aTag.tagDescription;
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

- (NSAttributedString *)attributedStringForContact:(SignalRecipient *)contact {
    NSMutableAttributedString *fullNameAttributedString =
    [[NSMutableAttributedString alloc] initWithString:contact.fullName];
    
    UIFont *firstNameFont;
    UIFont *lastNameFont;
    
    CGFloat fontSize = 17.0;
    
    firstNameFont = [UIFont ows_regularFontWithSize:fontSize];
    lastNameFont  = [UIFont ows_regularFontWithSize:fontSize];
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

@end
