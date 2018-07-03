#import "ContactTableViewCell.h"
#import "UIUtil.h"

#import "Environment.h"

@interface ContactTableViewCell ()

@property (strong, nonatomic) SignalRecipient *associatedRecipient;

@end

@implementation ContactTableViewCell

- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    return self;
}

- (NSString *)reuseIdentifier {
    return NSStringFromClass(self.class);
}

- (void)configureWithContact:(SignalRecipient *)recipient {
    self.associatedRecipient = recipient;
    self.nameLabel.attributedText = [self attributedStringForContact:recipient];
}

- (NSAttributedString *)attributedStringForContact:(SignalRecipient *)recipient {
    NSMutableAttributedString *fullNameAttributedString =
        [[NSMutableAttributedString alloc] initWithString:recipient.fullName];

    UIFont *firstNameFont;
    UIFont *lastNameFont;

//    if (ABPersonGetSortOrdering() == kABPersonCompositeNameFormatFirstNameFirst) {
//        firstNameFont = [UIFont ows_mediumFontWithSize:_nameLabel.font.pointSize];
//        lastNameFont  = [UIFont ows_regularFontWithSize:_nameLabel.font.pointSize];
//    } else {
        firstNameFont = [UIFont ows_regularFontWithSize:_nameLabel.font.pointSize];
        lastNameFont  = [UIFont ows_mediumFontWithSize:_nameLabel.font.pointSize];
//    }
    [fullNameAttributedString addAttribute:NSFontAttributeName
                                     value:firstNameFont
                                     range:NSMakeRange(0, recipient.firstName.length)];
    [fullNameAttributedString addAttribute:NSFontAttributeName
                                     value:lastNameFont
                                     range:NSMakeRange(recipient.firstName.length + 1, recipient.lastName.length)];
    [fullNameAttributedString addAttribute:NSForegroundColorAttributeName
                                     value:[UIColor blackColor]
                                     range:NSMakeRange(0, recipient.fullName.length)];

//    if (ABPersonGetSortOrdering() == kABPersonCompositeNameFormatFirstNameFirst) {
//        [fullNameAttributedString addAttribute:NSForegroundColorAttributeName
//                                         value:[UIColor ows_darkGrayColor]
//                                         range:NSMakeRange(contact.firstName.length + 1, contact.lastName.length)];
//    } else {
        [fullNameAttributedString addAttribute:NSForegroundColorAttributeName
                                         value:[UIColor ows_darkGrayColor]
                                         range:NSMakeRange(0, recipient.firstName.length)];
//    }
    return fullNameAttributedString;
}

@end
