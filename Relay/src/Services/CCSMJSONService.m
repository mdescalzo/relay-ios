//
//  CCSMJSONService.m
//  Forsta
//
//  Created by Mark on 6/15/17.
//  Copyright © 2017 Forsta. All rights reserved.
//

#import "CCSMJSONService.h"
#import "TSOutgoingMessage.h"

@implementation CCSMJSONService

+(NSString *)blobFromMessage:(TSOutgoingMessage *)message
{
    
    NSDictionary *holdingDictionary = @{ @"formatVersion": @"",
                                         @"messageId": message.uniqueId,            // globally unique message id
                                         @"threadId": message.uniqueThreadId,       // globally unique thread id
                                         @"threadTitle": @"",                       // non-unique original name for the thread from its creator
                                         @"sendTime": [NSNumber numberWithUnsignedInteger:message.timestamp],
                                         @"type": @"",                              //  'ordinary'|'broadcast'|'survey'|'survey-response'|'control'|'receipt'
                                         @"data": @{
                                                 @"receipt": @{   // If 'receipt'
                                                         @"messageId": @"",
                                                         @"userTagId": @"",
                                                         @"receiveTime": @"",
                                                         @"readTime": @"",
                                                         @"removalTime": @"",
                                                         @"feedback": @""
                                                         },
                                                 
                                                 @"body": @[ // if 'ordinary' or 'broadcast'
                                                         @{ @"type": @"",  // 'text/html'|'text/plain'|...
                                                            @"value": @"" },
                                                         
                                                         @{ @"type": @"",  // 'text/html'|'text/plain'|...
                                                            @"value": @"" }
                                                         ],
                                                 
                                                 @"surveyMaxSelections": @"",  // int - if survey
                                                 @"surveyChoices": @[/* 'label string1', 'label string2', etc */ ],  //  if 'survey'
                                                 @"surveySelections": @[/* 'label string', 'label string', etc */],  //  if 'survey'
                                                 
                                                 @"expiration": @[
                                                         @{ @"base": @"", /* 'read'|'received'|'sent' */
                                                            @"offset": @"" /* int seconds */},
                                                         @{ @"base": @"", /* 'read'|'received'|'sent' */
                                                            @"offset": @"" /* int seconds */}
                                                         ]
                                                 },
                                         
                                         @"sender": @{
                                                 @"tagId": @"",  // sender's usertag id
                                                 @"tagPresentation": @"",  // string representation of sender's tag AT SEND TIME
                                                 @"userIds": @"", // id of sending user
                                                 @"number": @""
                                                 },
                                         
                                         @"recipients": @{
                                                 @"distributionExpression": @{},
                                                 @"distributionPresentation": @"",
                                                 @"distributionTagsIncluded": @[],
                                                 @"distributionTagExcluded": @[],
                                                 @"userIds": @[],
                                                 @"numbers": @[]
                                                 }
                                         };
    
    NSError *error;
    NSData* jsonData = [NSJSONSerialization dataWithJSONObject:holdingDictionary
                                                       options:NSJSONWritingPrettyPrinted error:&error];
    return [[NSString alloc] initWithData:jsonData
                          encoding:NSUTF8StringEncoding];
}


@end
