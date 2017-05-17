//  Created by Dylan Bourgeois on 25/11/14.
//  Copyright (c) 2014 Open Whisper Systems. All rights reserved.

#import "Cryptography.h"
#import "UIColor+OWS.h"

@implementation UIColor (OWS)

+ (UIColor *)ows_materialBlueColor
{
    // blue: 2bace2
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
    return [UIColor colorWithRed:128.f / 255.f green:206.f / 255.f blue:255.f / 255.f alpha:1.f];
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
        [UIColor colorWithRed:204.f / 255.f green:148.f / 255.f blue:102.f / 255.f alpha:1.f],
        [UIColor colorWithRed:187.f / 255.f green:104.f / 255.f blue:62.f / 255.f alpha:1.f],
        [UIColor colorWithRed:145.f / 255.f green:78.f / 255.f blue:48.f / 255.f alpha:1.f],
        [UIColor colorWithRed:122.f / 255.f green:63.f / 255.f blue:41.f / 255.f alpha:1.f],
        [UIColor colorWithRed:80.f / 255.f green:46.f / 255.f blue:27.f / 255.f alpha:1.f],
        [UIColor colorWithRed:57.f / 255.f green:45.f / 255.f blue:19.f / 255.f alpha:1.f],
        [UIColor colorWithRed:37.f / 255.f green:38.f / 255.f blue:13.f / 255.f alpha:1.f],
        [UIColor colorWithRed:23.f / 255.f green:31.f / 255.f blue:10.f / 255.f alpha:1.f],
        [UIColor colorWithRed:6.f / 255.f green:19.f / 255.f blue:10.f / 255.f alpha:1.f],
        [UIColor colorWithRed:13.f / 255.f green:4.f / 255.f blue:16.f / 255.f alpha:1.f],
        [UIColor colorWithRed:27.f / 255.f green:12.f / 255.f blue:44.f / 255.f alpha:1.f],
        [UIColor colorWithRed:18.f / 255.f green:17.f / 255.f blue:64.f / 255.f alpha:1.f],
        [UIColor colorWithRed:20.f / 255.f green:42.f / 255.f blue:77.f / 255.f alpha:1.f],
        [UIColor colorWithRed:18.f / 255.f green:55.f / 255.f blue:68.f / 255.f alpha:1.f],
        [UIColor colorWithRed:18.f / 255.f green:68.f / 255.f blue:61.f / 255.f alpha:1.f],
        [UIColor colorWithRed:19.f / 255.f green:73.f / 255.f blue:26.f / 255.f alpha:1.f],
        [UIColor colorWithRed:13.f / 255.f green:48.f / 255.f blue:15.f / 255.f alpha:1.f],
        [UIColor colorWithRed:44.f / 255.f green:165.f / 255.f blue:137.f / 255.f alpha:1.f],
        [UIColor colorWithRed:137.f / 255.f green:181.f / 255.f blue:48.f / 255.f alpha:1.f],
        [UIColor colorWithRed:208.f / 255.f green:204.f / 255.f blue:78.f / 255.f alpha:1.f],
        [UIColor colorWithRed:227.f / 255.f green:162.f / 255.f blue:150.f / 255.f alpha:1.f]
    ];
    NSData *contactData = [contactIdentifier dataUsingEncoding:NSUTF8StringEncoding];

    NSUInteger hashingLength = 8;
    unsigned long long choose;
    NSData *hashData = [Cryptography computeSHA256:contactData truncatedToBytes:hashingLength];
    [hashData getBytes:&choose length:hashingLength];
    return [colors objectAtIndex:(choose % [colors count])];
}

@end
