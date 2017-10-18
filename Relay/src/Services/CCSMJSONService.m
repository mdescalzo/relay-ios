//
//  CCSMJSONService.m
//  Forsta
//
//  Created by Mark on 6/15/17.
//  Copyright © 2017 Forsta. All rights reserved.
//

#define FLBlobShapeRevision 1

#import "Environment.h"
#import "CCSMJSONService.h"
#import "TSOutgoingMessage.h"
#import "TSThread.h"
#import "CCSMStorage.h"
#import "DeviceTypes.h"
#import "TSAttachment.h"
#import "TSAttachmentPointer.h"
#import "TSAttachmentStream.h"

@interface CCSMJSONService()

+(NSArray *)arrayForTypeContentFromMessage:(TSOutgoingMessage *)message;
+(NSArray *)arrayForTypeBroadcastFromMessage:(TSOutgoingMessage *)message;
+(NSArray *)arrayForTypeSurveyFromMessage:(TSOutgoingMessage *)message;
+(NSArray *)arrayForTypeSurveyResponseFromMessage:(TSOutgoingMessage *)message;
+(NSArray *)arrayForTypeControlFromMessage:(TSOutgoingMessage *)message;
+(NSArray *)arrayForTypeReceiptFromMessage:(TSOutgoingMessage *)message;

@end

@implementation CCSMJSONService

+(NSString *_Nullable)blobFromMessage:(TSOutgoingMessage *_Nonnull)message
{
    NSArray *holdingArray = nil;
    if ([message.messageType isEqualToString:@"control"]) {
        holdingArray = [self arrayForTypeControlFromMessage:message];
    } else {
        if (message.messageType.length == 0) {
            message.messageType = @"content";
        }
        holdingArray = [self arrayForTypeContentFromMessage:message];
    }
    NSError *error;
    
    if ([NSJSONSerialization isValidJSONObject:holdingArray]) {
        NSData* jsonData = [NSJSONSerialization dataWithJSONObject:holdingArray
                                                           options:NSJSONWritingPrettyPrinted
                                                             error:&error];
        if (error) {
            UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Error" message:error.localizedDescription delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
            [alert show];
        }
        NSString *json = [[NSString alloc] initWithData:jsonData
                                     encoding:NSUTF8StringEncoding];
        return json;
    } else {
        return nil;
    }
}
         
+(NSArray *)arrayForTypeContentFromMessage:(TSOutgoingMessage *)message
{
    NSNumber *version = [NSNumber numberWithInt:FLBlobShapeRevision];
    NSString *userAgent = [DeviceTypes deviceModelName];
    NSString *messageId = message.forstaMessageID;
    NSString *threadId = message.thread.uniqueId;
    NSString *threadTitle = (message.thread.name ? message.thread.name : @"");
    NSString *sendTime = [self formattedStringFromDate:[NSDate date]];
    NSString *messageType = message.messageType;
    NSString *threadType = message.thread.type;
    if (threadType.length == 0) {
        threadType = @"conversation";
    }
    
    // Sender blob
    NSDictionary *sender = @{ @"userId" :  TSAccountManager.sharedInstance.myself.uniqueId };
    
    // Build recipient blob
    NSArray *userIds = message.thread.participants;
    NSString *presentation = message.thread.universalExpression;
    
    //  Missing expresssion for some reason, make one
    if (presentation.length == 0) {
        for (NSString *userId in userIds) {
            if (presentation.length == 0) {
                presentation = [NSString stringWithFormat:@"(<%@>", userId];
            } else {
                presentation = [presentation stringByAppendingString:[NSString stringWithFormat:@"+<%@>", userId]];
            }
        }
        presentation = [presentation stringByAppendingString:@")"];
    }
    NSDictionary *recipients = @{ @"expression" : presentation };
    
    NSMutableDictionary *tmpDict = [NSMutableDictionary dictionaryWithDictionary:
                            @{ @"version" : version,
                               @"userAgent" : userAgent,
                               @"messageId" : messageId,
                               @"threadId" : threadId,
                               @"threadTitle" : threadTitle,
                               @"sendTime" : sendTime,
                               @"messageType" : messageType,
                               @"threadType" : threadType,
                               @"sender" : sender,
                               @"distribution" : recipients
                               }];
    // Handler for nil message.body
    NSDictionary *data;
    if (message.plainTextBody) {
        data = @{ @"body": @[ @{ @"type": @"text/plain",
                                 @"value": message.plainTextBody }
                              ]
                  };
        [tmpDict setObject:data forKey:@"data"];
    }
    
    // Attachment Handler
    NSMutableArray *attachments = [NSMutableArray new];
    if ([message hasAttachments]) {
        for (NSString *attachmentID in message.attachmentIds) {
            TSAttachment *attachment = [TSAttachment fetchObjectWithUniqueID:attachmentID];
            if ([attachment isKindOfClass:[TSAttachmentStream class]]) {
                TSAttachmentStream *stream = (TSAttachmentStream *)attachment;
                NSFileManager *fm = [NSFileManager defaultManager];
                if ([fm fileExistsAtPath:stream.filePath]) {
                    NSString *filename = [stream.mediaURL.pathComponents lastObject];
                    NSString *contentType = stream.contentType;
                    NSDictionary *attribs = [fm attributesOfItemAtPath:stream.filePath error:nil];
                    NSNumber *size = [attribs objectForKey:NSFileSize];
                    NSDate *modDate = [attribs objectForKey:NSFileModificationDate];
                    NSString *dateString = [self formattedStringFromDate:modDate];
                    NSDictionary *attachmentDict = @{ @"name" : filename,
                                                      @"size" : size,
                                                      @"type" : contentType,
                                                      @"mtime" : dateString
                                                      };
                    [attachments addObject:attachmentDict];
                }
                
            }
        }
        if ([attachments count] >= 1) {
            [tmpDict setObject:attachments forKey:@"attachments"];
        }
    }
    return @[ tmpDict ];
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
    NSNumber *version = [NSNumber numberWithInt:FLBlobShapeRevision];
    NSString *userAgent = [DeviceTypes deviceModelName];
    NSString *messageId = message.forstaMessageID;
    NSString *threadId = message.thread.uniqueId;
    NSString *threadTitle = (message.thread.name ? message.thread.name : @"");
    NSString *sendTime = [self formattedStringFromDate:[NSDate date]];
    NSString *messageType = message.messageType;
    
    // Sender blob
    NSDictionary *sender = @{ @"userId" :  TSAccountManager.sharedInstance.myself.uniqueId };
    
    // Build recipient blob
    NSString *presentation = message.thread.universalExpression;
    NSDictionary *recipients = @{ @"expression" : presentation };
    
    NSMutableDictionary *tmpDict = [NSMutableDictionary dictionaryWithDictionary:
                                    @{ @"version" : version,
                                       @"userAgent" : userAgent,
                                       @"messageId" : messageId,
                                       @"threadId" : threadId,
                                       @"threadTitle" : threadTitle,
                                       @"sendTime" : sendTime,
                                       @"messageType" : messageType,
                                       @"sender" : sender,
                                       @"distribution" : recipients
                                       }];

    // Attachment Handler
    NSMutableArray *attachments = [NSMutableArray new];
    if ([message hasAttachments]) {
        for (NSString *attachmentID in message.attachmentIds) {
            TSAttachment *attachment = [TSAttachment fetchObjectWithUniqueID:attachmentID];
            if ([attachment isKindOfClass:[TSAttachmentStream class]]) {
                TSAttachmentStream *stream = (TSAttachmentStream *)attachment;
                NSFileManager *fm = [NSFileManager defaultManager];
                if ([fm fileExistsAtPath:stream.filePath]) {
                    NSString *filename = [stream.mediaURL.pathComponents lastObject];
                    NSString *contentType = stream.contentType;
                    NSDictionary *attribs = [fm attributesOfItemAtPath:stream.filePath error:nil];
                    NSNumber *size = [attribs objectForKey:NSFileSize];
                    NSDate *modDate = [attribs objectForKey:NSFileModificationDate];
                    NSString *dateString = [self formattedStringFromDate:modDate];
                    NSDictionary *attachmentDict = @{ @"name" : filename,
                                                      @"size" : size,
                                                      @"type" : contentType,
                                                      @"mtime" : dateString
                                                      };
                    [attachments addObject:attachmentDict];
                }
                
            }
        }
        if ([attachments count] >= 1) {
            [tmpDict setObject:attachments forKey:@"attachments"];
        }
    }
    return @[ tmpDict ];
}


+(NSArray *)arrayForTypeReceiptFromMessage:(TSOutgoingMessage *)message
{
    return [NSArray new];
}

+(NSString *)formattedStringFromDate:(NSDate *)date
{
    NSString *returnString = nil;
    
    if ([[[UIDevice currentDevice] systemVersion] floatValue] < 10.0) {
        NSDateFormatter *df = [[NSDateFormatter alloc] init];
        NSLocale *enUSPOSIXLocale = [NSLocale localeWithLocaleIdentifier:@"en_US_POSIX"];
        [df setLocale:enUSPOSIXLocale];
        [df setDateFormat:@"yyyy-MM-dd'T'HH:mm:ssZZZZZ"];
        returnString = [df stringFromDate:date];
    } else {
        NSISO8601DateFormatter *df = [[NSISO8601DateFormatter alloc] init];
        df.formatOptions = NSISO8601DateFormatWithInternetDateTime;
        returnString = [df stringFromDate:date];
    }
    
    return returnString;
}

#pragma mark - JSON body parsing methods
+(nullable NSArray *)arrayFromMessageBody:(NSString *_Nonnull)body
{
    // Checks passed message body to see if it is JSON,
    //    If it is, return the array of contents
    //    else, return nil.
    if (body.length == 0) {
        return nil;
    }
    
    NSError *error =  nil;
    NSData *data = [body dataUsingEncoding:NSUTF8StringEncoding];
    
    if (data == nil) { // Not parseable.  Bounce out.
        return nil;
    }
    
    NSArray *output = [NSJSONSerialization JSONObjectWithData:data options:0 error:&error];
    
    if (error) {
        DDLogError(@"JSON Parsing error: %@", error.description);
        return nil;
    } else {
        return output;
    }
}

@end
