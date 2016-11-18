//
//  UIFont+OWS.m
//  Signal
//
//  Created by Dylan Bourgeois on 25/11/14.
//  Copyright (c) 2014 Open Whisper Systems. All rights reserved.
//

#import "UIFont+OWS.h"
#import "iOSVersions.h"

@implementation UIFont (OWS)

+ (UIFont *)ows_thinFontWithSize:(CGFloat)size {
    return [UIFont systemFontOfSize:size weight:UIFontWeightThin];
}

+ (UIFont *)ows_lightFontWithSize:(CGFloat)size {
    return [UIFont systemFontOfSize:size weight:UIFontWeightLight];
}

+ (UIFont *)ows_regularFontWithSize:(CGFloat)size {
    return [UIFont systemFontOfSize:size weight:UIFontWeightRegular];
}

+ (UIFont *)ows_mediumFontWithSize:(CGFloat)size {
    return [UIFont systemFontOfSize:size weight:UIFontWeightMedium];
}

+ (UIFont *)ows_boldFontWithSize:(CGFloat)size {
    return [UIFont boldSystemFontOfSize:size];
}

#pragma mark Dynamic Type

+ (UIFont *)ows_dynamicTypeBodyFont {
    return [UIFont preferredFontForTextStyle:UIFontTextStyleBody];
}

+ (UIFont *)ows_infoMessageFont
{
    return [UIFont preferredFontForTextStyle:UIFontTextStyleSubheadline];
}

+ (UIFont *)ows_dynamicTypeTitle2Font {
    if (SYSTEM_VERSION_GREATER_THAN_OR_EQUAL_TO(_iOS_9)) {
        return [UIFont preferredFontForTextStyle:UIFontTextStyleTitle2];
    } else {
        // Dynamic title font for ios8 defaults to bold 12.0 pt, whereas ios9+ it's 22.0pt regular weight.
        // Here we chose to break dynamic font, in order to have uniform style across versions.
        // It's already huge, so it's unlikely to present a usability issue.
        // Handy font translations: http://swiftiostutorials.com/comparison-of-system-fonts-on-ios-8-and-ios-9/
        return [self ows_regularFontWithSize:22.0];
    }
}

@end
