//
//  FLMessagesManager.m
//  Forsta
//
//  Created by Mark on 9/4/17.
//  Copyright © 2017 Forsta. All rights reserved.
//

#import "FLMessagesManager.h"
#import "FLTagMathService.h"
#import "TSAccountManager.h"
#import "TSThread.h"
#import "TSStorageHeaders.h"
#import "OWSReadReceiptsProcessor.h"
#import "TextSecureKitEnv.h"
#import "OWSDisappearingConfigurationUpdateInfoMessage.h"
#import "OWSDisappearingMessagesConfiguration.h"
#import "OWSDisappearingMessagesJob.h"
//#import "OWSIncomingSentMessageTranscript.h"

@implementation FLMessagesManager

- (TSIncomingMessage *)handleReceivedEnvelope:(OWSSignalServiceProtosEnvelope *)envelope
                              withDataMessage:(OWSSignalServiceProtosDataMessage *)dataMessage
                                attachmentIds:(NSArray<NSString *> *)attachmentIds
{
    //  Catch incoming messages and process the new way.
        uint64_t timestamp = envelope.timestamp;
        NSString *body = dataMessage.body;
        
        NSArray *jsonArray = [self arrayFromMessageBody:body];
        __block NSDictionary *jsonPayload;
        if (jsonArray.count > 0) {
            DDLogDebug(@"JSON Payload received.");
            jsonPayload = [jsonArray lastObject];
        }
        // Process per Thread type
        if ([[jsonPayload objectForKey:@"threadType"] isEqualToString:@"conversation"]) {
            // Process per messageType
            if ([[jsonPayload objectForKey:@"messageType"] isEqualToString:@"content"]) {
                // Check to see if there is actual content
                NSArray *bodyArray = [[jsonPayload objectForKey:@"data"] objectForKey:@"body"];
                if (attachmentIds.count == 0 && bodyArray.count == 0) {
                    DDLogDebug(@"Content message with no content received.");
                    return nil;
                }
                
                __block TSIncomingMessage *incomingMessage = nil;
                __block TSThread *thread = nil;

                [self.dbConnection readWriteWithBlock:^(YapDatabaseReadWriteTransaction *transaction) {
                    thread = [TSThread threadWithPayload:jsonPayload transaction:transaction];
                    
                    incomingMessage = [[TSIncomingMessage alloc] initWithTimestamp:timestamp
                                                                          inThread:thread
                                                                          authorId:envelope.source
                                                                       messageBody:body
                                                                     attachmentIds:attachmentIds
                                                                  expiresInSeconds:dataMessage.expireTimer];
                    incomingMessage.forstaPayload = [jsonPayload mutableCopy];
                    incomingMessage.forstaMessageType = [jsonPayload objectForKey:@"messageType"];
                    [incomingMessage saveWithTransaction:transaction];
                    
                    // Android allows attachments to be sent with body.
                    if ([attachmentIds count] > 0 && incomingMessage.plainTextBody.length > 0) {
                        // We want the text to be displayed under the attachment
                        uint64_t textMessageTimestamp = timestamp + 1;
                        TSIncomingMessage *textMessage = [[TSIncomingMessage alloc] initWithTimestamp:textMessageTimestamp
                                                                                             inThread:thread
                                                                                             authorId:envelope.source
                                                                                          messageBody:@""];
                        textMessage.forstaPayload = incomingMessage.forstaPayload;
                        textMessage.plainTextBody = incomingMessage.plainTextBody;
                        textMessage.expiresInSeconds = dataMessage.expireTimer;
                        [textMessage saveWithTransaction:transaction];
                    }
                }];
                
                if (incomingMessage && thread) {
                    // In case we already have a read receipt for this new message (happens sometimes).
                    OWSReadReceiptsProcessor *readReceiptsProcessor =
                    [[OWSReadReceiptsProcessor alloc] initWithIncomingMessage:incomingMessage
                                                               storageManager:self.storageManager];
                    [readReceiptsProcessor process];
                    
                    [self.disappearingMessagesJob becomeConsistentWithConfigurationForMessage:incomingMessage
                                                                              contactsManager:self.contactsManager];
                    
                    // Update thread
                    [thread touch];

                    // TODO Delay notification by 100ms?
                    // It's pretty annoying when you're phone keeps buzzing while you're having a conversation on Desktop.
                    NSString *name = thread.displayName;
                    [[TextSecureKitEnv sharedEnv].notificationsManager notifyUserForIncomingMessage:incomingMessage
                                                                                               from:name
                                                                                           inThread:thread];
                }
                return incomingMessage;
            } else {
                DDLogDebug(@"Unhandled message type: %@", [jsonPayload objectForKey:@"messageType"]);
                return nil;
            }
        } else {
            DDLogDebug(@"Unhandled thread type: %@", [jsonPayload objectForKey:@"threadType"]);
            return nil;
        }
}

-(nullable NSArray *)arrayFromMessageBody:(NSString *_Nonnull)body
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
