//
//  FLMessagesManager.m
//  Forsta
//
//  Created by Mark on 9/4/17.
//  Copyright © 2017 Forsta. All rights reserved.
//

#import "FLMessagesManager.h"
#import "FLTagMathService.h"
#import "CCSMJSONService.h"
#import "TSAccountManager.h"
#import "TSContactThread.h"
#import "TSGroupThread.h"
#import "TSStorageHeaders.h"
#import "OWSReadReceiptsProcessor.h"
#import "TextSecureKitEnv.h"
#import "OWSDisappearingConfigurationUpdateInfoMessage.h"
#import "OWSDisappearingMessagesConfiguration.h"
#import "OWSDisappearingMessagesJob.h"
#import "OWSIncomingSentMessageTranscript.h"

@implementation FLMessagesManager

- (TSIncomingMessage *)handleReceivedEnvelope:(OWSSignalServiceProtosEnvelope *)envelope
                              withDataMessage:(OWSSignalServiceProtosDataMessage *)dataMessage
                                attachmentIds:(NSArray<NSString *> *)attachmentIds
{
    //  Catch incoming messages and process the new way.  Otherwise, call the super and complete the old way

    // If old group received, go with it the old way.
    if (dataMessage.hasGroup) {
        return [super handleReceivedEnvelope:envelope withDataMessage:dataMessage attachmentIds:attachmentIds];
    } else {
    
        uint64_t timestamp = envelope.timestamp;
        NSString *body = dataMessage.body;
        
        NSArray *jsonArray = [CCSMJSONService arrayFromMessageBody:body];
        __block NSDictionary *jsonPayload;
        if (jsonArray.count > 0) {
            DDLogDebug(@"JSON Payload received.");
            jsonPayload = [jsonArray lastObject];
        }
        // Process per Thread type
        if ([[jsonPayload objectForKey:@"threadType"] isEqualToString:@"conversation"]) {
            // Process per messageType
            if ([[jsonPayload objectForKey:@"messageType"] isEqualToString:@"content"]) {
                __block TSIncomingMessage *incomingMessage = nil;
                __block TSThread *thread = nil;
                
                NSString *expression = [(NSDictionary *)[jsonPayload objectForKey:@"distribution"] objectForKey:@"expression"];
                
                [[FLTagMathService new] tagLookupWithString:expression
                                                    success:^(NSDictionary *results) {
                                                        
                                                        [self.dbConnection readWriteWithBlock:^(YapDatabaseReadWriteTransaction *transaction) {
                                                            
                                                            // Look at the userids to determine which message handling to go with.
                                                            NSArray *participants = [results objectForKey:@"userids"];
                                                            if ([participants containsObject:[TSAccountManager localNumber]] &&
                                                                (participants.count > 2)) {
                                                                // Group handling here
                                                                TSGroupThread *gThread = [TSGroupThread getOrCreateThreadWithID:[jsonPayload objectForKey:@"threadId"]];
                                                                if (gThread.groupModel.groupMemberIds.count == 0) {
                                                                    gThread.groupModel.groupMemberIds = [participants mutableCopy];
                                                                }
                                                                thread = gThread;
                                                            } else {
                                                                // Conversation handling here
                                                                TSContactThread *cThread = [TSContactThread getOrCreateThreadWithContactId:envelope.source
                                                                                                                               transaction:transaction
                                                                                                                                     relay:envelope.relay];
                                                                thread = cThread;
                                                            }
                                                            incomingMessage = [[TSIncomingMessage alloc] initWithTimestamp:timestamp
                                                                                                                  inThread:thread
                                                                                                                  authorId:envelope.source
                                                                                                               messageBody:body
                                                                                                             attachmentIds:attachmentIds
                                                                                                          expiresInSeconds:dataMessage.expireTimer];
                                                            
                                                            // thread/message configuration from JSON payload
                                                            if (jsonPayload && thread && incomingMessage) {
                                                                incomingMessage.forstaPayload = [jsonPayload mutableCopy];
                                                                thread.forstaThreadID = [jsonPayload objectForKey:@"threadId"];
                                                                thread.universalExpression = [results objectForKey:@"universal"];
                                                                thread.participants = [results objectForKey:@"userids"];
                                                                thread.prettyExpression = [results objectForKey:@"pretty"];
                                                                thread.type = [jsonPayload objectForKey:@"threadType"];
                                                                
                                                                [thread saveWithTransaction:transaction];
                                                                [incomingMessage saveWithTransaction:transaction];
                                                                
                                                                // Android allows attachments to be sent with body.
                                                                //            if ([attachmentIds count] > 0 && body != nil && ![body isEqualToString:@""]) {
                                                                if ([attachmentIds count] > 0 && incomingMessage.plainTextBody != nil && ![incomingMessage.plainTextBody isEqualToString:@""]) {
                                                                    // We want the text to be displayed under the attachment
                                                                    uint64_t textMessageTimestamp = timestamp + 1;
                                                                    TSIncomingMessage *textMessage;
                                                                    if ([thread isGroupThread]) {
                                                                        TSGroupThread *gThread = (TSGroupThread *)thread;
                                                                        textMessage = [[TSIncomingMessage alloc] initWithTimestamp:textMessageTimestamp
                                                                                                                          inThread:gThread
                                                                                                                          authorId:envelope.source
                                                                                                                       messageBody:@""];
                                                                    } else {
                                                                        TSContactThread *cThread = (TSContactThread *)thread;
                                                                        textMessage = [[TSIncomingMessage alloc] initWithTimestamp:textMessageTimestamp
                                                                                                                          inThread:cThread
                                                                                                                          authorId:[cThread contactIdentifier]
                                                                                                                       messageBody:@""];
                                                                    }
                                                                    textMessage.plainTextBody = incomingMessage.plainTextBody;
                                                                    textMessage.expiresInSeconds = dataMessage.expireTimer;
                                                                    [textMessage saveWithTransaction:transaction];
                                                                }
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
                                                            
                                                            // Update thread preview in inbox
                                                            [thread touch];
                                                            
                                                            // TODO Delay notification by 100ms?
                                                            // It's pretty annoying when you're phone keeps buzzing while you're having a conversation on Desktop.
                                                            NSString *name = [thread name];
                                                            [[TextSecureKitEnv sharedEnv].notificationsManager notifyUserForIncomingMessage:incomingMessage
                                                                                                                                       from:name
                                                                                                                                   inThread:thread];
                                                        }
                                                        
                                                    }
                                                    failure:^(NSError *error) {
                                                                                          
                                                    }];
            } else {
                DDLogDebug(@"Unhandled message type: %@", [jsonPayload objectForKey:@"messageType"]);
            }
        } else {
            DDLogDebug(@"Unhanded thread type: %@", [jsonPayload objectForKey:@"threadType"]);
        }
    }
}

-(TSIncomingMessage *)incomingGroupMessageWithFromPayload:(NSDictionary *)payload
{
    
}

-(TSIncomingMessage *)incomingConversationMessageWithFromPayload:(NSDictionary *)payload
{
    
}
@end
