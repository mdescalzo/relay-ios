//
//  CCSMJSONService.m
//  Forsta
//
//  Created by Mark on 6/15/17.
//  Copyright © 2017 Forsta. All rights reserved.
//

#import "CCSMJSONService.h"
#import "TSOutgoingMessage.h"
#import "TSGroupThread.h"
#import "TSContactThread.h"
#import "CCSMStorage.h"

@interface CCSMJSONService()

+(NSArray *)arrayForTypeOrdinaryFromMessage:(TSOutgoingMessage *)message;
+(NSArray *)arrayForTypeBroadcastFromMessage:(TSOutgoingMessage *)message;
+(NSArray *)arrayForTypeSurveyFromMessage:(TSOutgoingMessage *)message;
+(NSArray *)arrayForTypeSurveyResponseFromMessage:(TSOutgoingMessage *)message;
+(NSArray *)arrayForTypeControlFromMessage:(TSOutgoingMessage *)message;
+(NSArray *)arrayForTypeReceiptFromMessage:(TSOutgoingMessage *)message;

@end

@implementation CCSMJSONService

#warning Need a mechanism for recognizing message type
+(NSString *)blobFromMessage:(TSOutgoingMessage *)message
{
    
    NSArray *holdingArray = [self arrayForTypeOrdinaryFromMessage:message];
    
    NSError *error;
    
    if ([NSJSONSerialization isValidJSONObject:holdingArray]) {
        NSData* jsonData = [NSJSONSerialization dataWithJSONObject:holdingArray
                                                           options:NSJSONWritingPrettyPrinted error:&error];
        if (error) {
            UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Error" message:error.localizedDescription delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
            [alert show];
        }
        return [[NSString alloc] initWithData:jsonData
                                     encoding:NSUTF8StringEncoding];
    } else {
        return nil;
    }
}
         
+(NSArray *)arrayForTypeOrdinaryFromMessage:(TSOutgoingMessage *)message
{
    NSNumber *version = [NSNumber numberWithInt:1];
//    NSString *messageId = message.uniqueId; // unused?
//    NSString *threadId = message.uniqueThreadId;
//    NSString *threadTitle = @"forsta";  // forsta for contact threads for now.  group threads have their own title
    NSString *sendTime = [self formattedStringFromDate:[NSDate date]];
    NSString *type = @"ordinary";
    NSDictionary *data = @{@"body": @[
                                        @{ @"type": @"text/plain",
                                           @"value": message.body }
                                     ]
                          };
    NSDictionary *sender = @{ @"tagId": [[CCSMStorage new] getUserName] };
    
    NSDictionary *tmpDict = @{ @"version" : version,
//                               @"messageId" : messageId,  //  Appears to be unused.
//                               @"threadId" : threadId,
//                               @"threadTitle" : threadTitle,
                               @"sendTime" : sendTime,
                               @"type" : type,
                               @"data" : data,
                               @"sender" : sender
                               };
    
    NSArray *returnArray = @[ tmpDict ];

    return returnArray;
}

+(NSArray *)arrayForTypeBroadcastFromMessage:(TSOutgoingMessage *)message
{
    return [NSArray new];
}

+(NSArray *)arrayForTypeSurveyFromMessage:(TSOutgoingMessage *)message
{
    return [NSArray new];
}

+(NSArray *)arrayForTypeSurveyResponseFromMessage:(TSOutgoingMessage *)message
{
    return [NSArray new];
}

+(NSArray *)arrayForTypeControlFromMessage:(TSOutgoingMessage *)message
{
    return [NSArray new];
}

+(NSArray *)arrayForTypeReceiptFromMessage:(TSOutgoingMessage *)message
{
    return [NSArray new];
}

+(NSString *)formattedStringFromDate:(NSDate *)date
{
    NSISO8601DateFormatter *df = [[NSISO8601DateFormatter alloc] init];
    df.formatOptions = NSISO8601DateFormatWithInternetDateTime;
    
    return [df stringFromDate:date];
}

@end

//                                      @{ @"version": @"",
//                                         @"messageId": message.uniqueId,            // globally unique message id
//                                         @"threadId": message.uniqueThreadId,       // globally unique thread id
//                                         @"threadTitle": @"",                 // non-unique original name for the thread from its creator
//                                         @"sendTime": [NSNumber numberWithUnsignedInteger:message.timestamp],
//                                         @"type": @"",                              //  'ordinary'|'broadcast'|'survey'|
//                                                                                    //  'survey-response'|'control'|'receipt'
//                                         @"data": @{
//                                                 @"receipt": @{   // If 'receipt'
//                                                         @"messageId": @"",
//                                                         @"userTagId": @"",
//                                                         @"receiveTime": @"",
//                                                         @"readTime": @"",
//                                                         @"removalTime": @"",
//                                                         @"feedback": @""
//                                                         },
//
//                                                 @"body": @[ // if 'ordinary' or 'broadcast'
//                                                         @{ @"type": @"",  // 'text/html'|'text/plain'|...
//                                                            @"value": @"" },
//
//                                                         @{ @"type": @"",  // 'text/html'|'text/plain'|...
//                                                            @"value": @"" }
//                                                         ],
//
//                                                 @"surveyMaxSelections": @"",  // int - if survey
//                                                 @"surveyChoices": @[/* 'label string1', 'label string2', etc */ ],  //  if 'survey'
//                                                 @"surveySelections": @[/* 'label string', 'label string', etc */],  //  if 'survey'
//
//                                                 @"expiration": @[
//                                                         @{ @"base": @"", /* 'read'|'received'|'sent' */
//                                                            @"offset": @"" /* int seconds */},
//                                                         @{ @"base": @"", /* 'read'|'received'|'sent' */
//                                                            @"offset": @"" /* int seconds */}
//                                                         ]
//                                                 },
//
//                                         @"sender": @{
//                                                 @"tagId": @"",  // sender's usertag id
//                                                 @"tagPresentation": @"",  // string representation of sender's tag AT SEND TIME
//                                                 @"userIds": @"", // id of sending user
//                                                 @"number": @""
//                                                 },
//
//                                         @"recipients": @{
//                                                 @"distributionExpression": @{},
//                                                 @"distributionPresentation": @"",
//                                                 @"distributionTagsIncluded": @[],
//                                                 @"distributionTagExcluded": @[],
//                                                 @"userIds": @[],
//                                                 @"numbers": @[]
//                                                 }
//                                         };
