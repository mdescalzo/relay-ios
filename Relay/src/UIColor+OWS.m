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
//    #define UIColorFromRGB(rgbValue) [UIColor colorWithRed:((float)((rgbValue & 0xFF0000) >> 16))/255.0    \
//                green:((float)((rgbValue & 0x00FF00) >>  8))/255.0 \
//                 blue:((float)((rgbValue & 0x0000FF) >>  0))/255.0 \
//                alpha:1.0]
    NSArray *colors = [ForstaColors popColors];
//    NSArray *colors = @[
//            UIColorFromRGB(0x124b63),
//            UIColorFromRGB(0x0a76af),
//            UIColorFromRGB(0x9a4422),
//            UIColorFromRGB(0x719904),
//            UIColorFromRGB(0x0a76af),
//            UIColorFromRGB(0x6abde9),
//            UIColorFromRGB(0xbe5d28),
//            UIColorFromRGB(0x90b718),
//            UIColorFromRGB(0x2bace2),
//            UIColorFromRGB(0x80ceff),
//            UIColorFromRGB(0xf47d20),
//            UIColorFromRGB(0xafd23f),
//            UIColorFromRGB(0x6abde9),
//            UIColorFromRGB(0xc5e0ef),
//            UIColorFromRGB(0xf69348)
//            //UIColorFromRGB(0xbed868),
//            //UIColorFromRGB(0x9ccce0),
//            //UIColorFromRGB(0xd7e6f5),
//            //UIColorFromRGB(0xfdc79e),
//            //UIColorFromRGB(0xdeef95)
//
//    ];
    NSData *contactData = [contactIdentifier dataUsingEncoding:NSUTF8StringEncoding];

    NSUInteger hashingLength = 4;
    unsigned long long choose;
    NSData *hashData = [Cryptography computeSHA256:contactData truncatedToBytes:hashingLength];
    [hashData getBytes:&choose length:hashingLength];
    return [colors objectAtIndex:(choose % [colors count])];
}

@end
