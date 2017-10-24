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
#import "FLControlMessage.h"
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
    // Process per messageType
    if ([[jsonPayload objectForKey:@"messageType"] isEqualToString:@"control"]) {
        NSString *controlMessageType = [jsonPayload objectForKey:@"control"];
        
        // Conversation update
        if ([controlMessageType isEqualToString:FLControlMessageThreadUpdateKey]) {
            [self.dbConnection readWriteWithBlock:^(YapDatabaseReadWriteTransaction *transaction) {
                // TODO: Attachments become avatars
                // TODO: Modfiy participants
                TSThread *thread = [TSThread getOrCreateThreadWithID:[jsonPayload objectForKey:@"threadId"] transaction:transaction];
                NSString *threadTitle = [jsonPayload objectForKey:@"threadTitle"];
                if (threadTitle.length > 0) {
                    thread.name = threadTitle;
                    SignalRecipient *sender = [SignalRecipient fetchObjectWithUniqueID:envelope.source transaction:transaction];
                    NSString *customMessage = nil;
                    TSInfoMessage *infoMessage = nil;
                    if (sender) {
                        NSString *messageFormat = NSLocalizedString(@"THREAD_TITLE_UPDATE_MESSAGE", @"Thread title update message");
                        customMessage = [NSString stringWithFormat:messageFormat, sender.fullName];
                        
                        infoMessage = [[TSInfoMessage alloc] initWithTimestamp:timestamp
                                                                      inThread:thread
                                                                   messageType:TSInfoMessageTypeConversationUpdate
                                                                 customMessage:customMessage];
                    } else {
                        infoMessage = [[TSInfoMessage alloc] initWithTimestamp:timestamp
                                                                      inThread:thread
                                                                   messageType:TSInfoMessageTypeConversationUpdate];
                    }
                    [infoMessage saveWithTransaction:transaction];
                }
//                NSString *expression = [(NSDictionary *)[jsonPayload objectForKey:@"distribution"] objectForKey:@"expression"];
//                if (expression.length > 0) {
//                    thread.universalExpression = expression;
//                    NSDictionary *lookupDict = [FLTagMathService syncTagLookupWithString:thread.universalExpression];
//                    if (lookupDict) {
//                        thread.participants = [lookupDict objectForKey:@"userids"];
//                        thread.prettyExpression = [lookupDict objectForKey:@"pretty"];
//                    }
//                }
                [thread saveWithTransaction:transaction];
            }];
            
        } else if ([controlMessageType isEqualToString:FLControlMessageThreadClearKey]) {
        } else if ([controlMessageType isEqualToString:FLControlMessageThreadCloseKey]) {
        } else if ([controlMessageType isEqualToString:FLControlMessageThreadDeleteKey]) {
        } else if ([controlMessageType isEqualToString:FLControlMessageThreadSnoozeKey]) {
        } else {
            DDLogDebug(@"Unhandled control message.");
        }
        return nil;
        
    } else if ([[jsonPayload objectForKey:@"messageType"] isEqualToString:@"content"]) {
        // Process per Thread type
        if ([[jsonPayload objectForKey:@"threadType"] isEqualToString:@"conversation"]) {
            // Check to see if there is actual content
            NSArray *bodyArray = [(NSDictionary *)[jsonPayload objectForKey:@"data"] objectForKey:@"body"];
            if (attachmentIds.count == 0 && bodyArray.count == 0) {
                DDLogDebug(@"Content message with no content received.");
                return nil;
            }
            
            __block TSIncomingMessage *incomingMessage = nil;
            __block TSThread *thread = nil;
            
            [self.dbConnection readWriteWithBlock:^(YapDatabaseReadWriteTransaction *transaction) {
                thread = [TSThread threadWithPayload:jsonPayload transaction:transaction];
                
                // Check to see if we already have this message
                incomingMessage = [TSIncomingMessage fetchObjectWithUniqueID:[jsonPayload objectForKey:@"messageId"] transaction:transaction];
                
                if (incomingMessage == nil) {
                    incomingMessage = [[TSIncomingMessage alloc] initWithTimestamp:timestamp
                                                                          inThread:thread
                                                                          authorId:envelope.source
                                                                       messageBody:body
                                                                     attachmentIds:attachmentIds
                                                                  expiresInSeconds:dataMessage.expireTimer];
                    incomingMessage.uniqueId = [jsonPayload objectForKey:@"messageId"];
                    incomingMessage.messageType = [jsonPayload objectForKey:@"messageType"];
                }
                incomingMessage.forstaPayload = [jsonPayload mutableCopy];
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
