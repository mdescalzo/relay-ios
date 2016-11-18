//  Created by Michael Kirk on 9/27/16.
//  Copyright © 2016 Open Whisper Systems. All rights reserved.

#import "OWSScrubbingLogFormatter.h"

NS_ASSUME_NONNULL_BEGIN

@implementation OWSScrubbingLogFormatter

- (NSString *)formatLogMessage:(DDLogMessage *)logMessage
{
    NSString *string = [super formatLogMessage:logMessage];
    NSRegularExpression *phoneRegex =
        [NSRegularExpression regularExpressionWithPattern:@"\\+\\d{7,12}(\\d{3})"
                                                  options:NSRegularExpressionCaseInsensitive
                                                    error:nil];
    NSString *filteredString = [phoneRegex stringByReplacingMatchesInString:string
                                                                    options:0
                                                                      range:NSMakeRange(0, [string length])
                                                               withTemplate:@"[ REDACTED_PHONE_NUMBER ]"];

    return filteredString;
}

@end

NS_ASSUME_NONNULL_END
