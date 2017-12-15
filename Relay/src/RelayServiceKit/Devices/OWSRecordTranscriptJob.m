//  Created by Michael Kirk on 9/23/16.
//  Copyright © 2016 Open Whisper Systems. All rights reserved.

#import "OWSRecordTranscriptJob.h"
#import "OWSAttachmentsProcessor.h"
#import "OWSDisappearingMessagesJob.h"
#import "OWSIncomingSentMessageTranscript.h"
#import "OWSMessageSender.h"
#import "TSOutgoingMessage.h"
#import "TSStorageManager.h"
#import "TSThread.h"
#import "NSDate+millisecondTimeStamp.h"
#import "FLCCSMJSONService.h"
#import "FLControlMessage.h"

NS_ASSUME_NONNULL_BEGIN

@interface OWSRecordTranscriptJob ()

@property (nonatomic, readonly) OWSIncomingSentMessageTranscript *incomingSentMessageTranscript;
@property (nonatomic, readonly) OWSMessageSender *messageSender;
@property (nonatomic, readonly) TSNetworkManager *networkManager;

@end

@implementation OWSRecordTranscriptJob

- (instancetype)initWithIncomingSentMessageTranscript:(OWSIncomingSentMessageTranscript *)incomingSentMessageTranscript
                                        messageSender:(OWSMessageSender *)messageSender
                                       networkManager:(TSNetworkManager *)networkManager
{
    self = [super init];
    if (!self) {
        return self;
    }
    
    _incomingSentMessageTranscript = incomingSentMessageTranscript;
    _messageSender = messageSender;
    _networkManager = networkManager;
    
    return self;
}

- (void)runWithAttachmentHandler:(void (^)(TSAttachmentStream *attachmentStream))attachmentHandler
{
    OWSIncomingSentMessageTranscript *transcript = self.incomingSentMessageTranscript;
    DDLogDebug(@"%@ Recording transcript: %@", self.tag, transcript);
    
    // Intercept and attach forstaPayload
    __block NSDictionary *jsonPayload = [FLCCSMJSONService payloadDictionaryFromMessageBody:transcript.body];

    // Check for control message
    if ([[jsonPayload objectForKey:@"messageType"] isEqualToString:@"control"]) {
        __block NSDictionary *dataBlob = [jsonPayload objectForKey:@"data"];
        NSString *controlType = [dataBlob objectForKey:@"control"];
        
          // Archive a thread
        if ([controlType isEqualToString:FLControlMessageThreadArchiveKey] ||
            [controlType isEqualToString:FLControlMessageThreadCloseKey]) {
            [TSStorageManager.sharedManager.dbConnection asyncReadWriteWithBlock:^(YapDatabaseReadWriteTransaction *transaction) {
                NSString *threadID = [jsonPayload objectForKey:@"threadId"];
                TSThread *thread = [TSThread fetchObjectWithUniqueID:threadID transaction:transaction];
                if (thread) {
                    [thread archiveThreadWithTransaction:transaction
                                           referenceDate:[NSDate ows_dateWithMillisecondsSince1970:transcript.timestamp]];
                    DDLogDebug(@"%@: Archived thread: %@", self.tag, thread);
                }
            }];
        }
        // Restore Archived thread
        else if ([controlType isEqualToString:FLControlMessageThreadRestoreKey]) {
        [TSStorageManager.sharedManager.dbConnection asyncReadWriteWithBlock:^(YapDatabaseReadWriteTransaction *transaction) {
            NSString *threadID = [jsonPayload objectForKey:@"threadId"];
            TSThread *thread = [TSThread fetchObjectWithUniqueID:threadID transaction:transaction];
            if (thread) {
                [thread unarchiveThreadWithTransaction:transaction];
                DDLogDebug(@"%@: Unarchived thread: %@", self.tag, thread);
            }
        }];
    }
        else {
            DDLogDebug(@"Received unhandled sync control message with payload: %@", jsonPayload);
        }
    } else {
        TSThread *thread = transcript.thread;
        
        NSDictionary *dataBlob = [jsonPayload objectForKey:@"data"];
        
        OWSAttachmentsProcessor *attachmentsProcessor =
        [[OWSAttachmentsProcessor alloc] initWithAttachmentProtos:transcript.attachmentPointerProtos
                                                       properties:[dataBlob objectForKey:@"attachments"]
                                                        timestamp:transcript.timestamp
                                                            relay:transcript.relay
                                                           thread:thread
                                                   networkManager:self.networkManager];
        
        TSOutgoingMessage *outgoingMessage =
        [[TSOutgoingMessage alloc] initWithTimestamp:transcript.timestamp
                                            inThread:thread
                                         messageBody:@""
                                       attachmentIds:[attachmentsProcessor.attachmentIds mutableCopy]
                                    expiresInSeconds:transcript.expirationDuration
                                     expireStartedAt:transcript.expirationStartedAt];
        outgoingMessage.forstaPayload = [jsonPayload mutableCopy];
        if (transcript.isExpirationTimerUpdate) {
            [self.messageSender becomeConsistentWithDisappearingConfigurationForMessage:outgoingMessage];
            // early return to avoid saving an empty incoming message.
            return;
        }
        
        [self.messageSender handleMessageSentRemotely:outgoingMessage sentAt:transcript.expirationStartedAt];
        
        [attachmentsProcessor
         fetchAttachmentsForMessage:outgoingMessage
         success:attachmentHandler
         failure:^(NSError *_Nonnull error) {
             DDLogError(@"%@ failed to fetch transcripts attachments for message: %@",
                        self.tag,
                        outgoingMessage);
         }];
        
        
        
        // If there is an attachment + text, render the text here, as Signal-iOS renders two messages.
        if (attachmentsProcessor.hasSupportedAttachments && outgoingMessage.plainTextBody && ![outgoingMessage.plainTextBody isEqualToString:@""]) {
            // render text *after* the attachment
            uint64_t textMessageTimestamp = transcript.timestamp + 1;
            TSOutgoingMessage *textMessage = [[TSOutgoingMessage alloc] initWithTimestamp:textMessageTimestamp
                                                                                 inThread:thread
                                                                              messageBody:@""
                                                                            attachmentIds:[NSMutableArray new]
                                                                         expiresInSeconds:transcript.expirationDuration
                                                                          expireStartedAt:transcript.expirationStartedAt];
            textMessage.forstaPayload = [jsonPayload mutableCopy];
            textMessage.messageState = TSOutgoingMessageStateDelivered;
            [textMessage save];
        }
    }
}

#pragma mark - Logging

+ (NSString *)tag
{
    return [NSString stringWithFormat:@"[%@]", self.class];
}

- (NSString *)tag
{
    return self.class.tag;
}

@end

NS_ASSUME_NONNULL_END
