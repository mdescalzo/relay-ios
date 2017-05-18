//  Created by Dylan Bourgeois on 25/11/14.
//  Copyright (c) 2014 Open Whisper Systems. All rights reserved.

#import "Cryptography.h"
#import "UIColor+OWS.h"

@implementation UIColor (OWS)

+ (UIColor *)ows_materialBlueColor
{
    // blue: 2bace2 -- this is Nav bar color
    // return [UIColor colorWithRed:43.f / 255.f green:172.f / 255.f blue:226.f / 255.f alpha:1.f];
    return [UIColor colorWithRed:0.f / 255.f green:0.f / 255.f blue:0. / 255.f alpha:1.f];
}

+ (UIColor *)ows_blackColor
{
    // black: #000000
    return [UIColor colorWithRed:0.f / 255.f green:0.f / 255.f blue:0. / 255.f alpha:1.f];
}

+ (UIColor *)ows_darkGrayColor
{
  // #606161
    return [UIColor colorWithRed:96.f / 255.f green:97.f / 255.f blue:97.f / 255.f alpha:1.f];
}

+ (UIColor *)ows_darkBackgroundColor
{
  // #2bace2
    return [UIColor colorWithRed:43.f / 255.f green:172.f / 255.f blue:226.f / 255.f alpha:1.f];
}

+ (UIColor *)ows_fadedBlueColor
{
    // blue: #80ceff
    return [UIColor colorWithRed:43.f / 255.f green:172.f / 255.f blue:226.f / 255.f alpha:1.f];
}

+ (UIColor *)ows_yellowColor
{
    // gold: #f47d20
    return [UIColor colorWithRed:244.f / 255.f green:125.f / 255.f blue:98.f / 32.f alpha:1.f];
}

+ (UIColor *)ows_greenColor
{
    // green: #b0d23f
    return [UIColor colorWithRed:175.f / 255.f green:210.f / 255.f blue:63.f / 255.f alpha:1.f];
}

+ (UIColor *)ows_redColor
{
    // red: #f47d20
    return [UIColor colorWithRed:244.f / 255.f green:125.f / 255.f blue:32.f / 255.f alpha:1.f];
}

+ (UIColor *)ows_errorMessageBorderColor
{
    return [UIColor colorWithRed:244.f / 254.f green:125 / 255.f blue:63.f / 255.f alpha:1.0f];
}

+ (UIColor *)ows_infoMessageBorderColor
{
    return [UIColor colorWithRed:244.f / 255.f green:125.f / 255.f blue:63.f / 255.f alpha:1.0f];
}

+ (UIColor *)ows_lightBackgroundColor
{
    return [UIColor colorWithRed:202.f / 255.f green:202.f / 255.f blue:202.f / 255.f alpha:1.f];
}

+ (UIColor *)backgroundColorForContact:(NSString *)contactIdentifier
{
    NSArray *colors = @[
        [UIColor colorWithRed:43.f / 255.f  green:172.f / 255.f blue:226.f / 255.f alpha:1.f],
        [UIColor colorWithRed:128.f / 255.f green:206.f / 255.f blue:255.f / 255.f alpha:1.f],
        [UIColor colorWithRed:244.f / 255.f green:125.f / 255.f blue:32.f / 255.f  alpha:1.f],
        [UIColor colorWithRed:175.f / 255.f green:210.f / 255.f blue:63.f / 255.f  alpha:1.f],
        [UIColor colorWithRed:159.f / 255.f green:159.f / 255.f blue:159.f / 255.f alpha:1.f],
        [UIColor colorWithRed:202.f / 255.f green:202.f / 255.f blue:202.f / 255.f alpha:1.f]
    ];
    NSData *contactData = [contactIdentifier dataUsingEncoding:NSUTF8StringEncoding];

    NSUInteger hashingLength = 4;
    unsigned long long choose;
    NSData *hashData = [Cryptography computeSHA256:contactData truncatedToBytes:hashingLength];
    [hashData getBytes:&choose length:hashingLength];
    return [colors objectAtIndex:(choose % [colors count])];
}

@end
