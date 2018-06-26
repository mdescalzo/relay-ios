//  Created by Michael Kirk on 9/23/16.
//  Copyright © 2016 Open Whisper Systems. All rights reserved.

#import "Relay-Swift.h"
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
    
    TSThread *thread = transcript.thread;
    [thread updateWithPayload:jsonPayload];
    [thread touch];
    
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
        outgoingMessage.hasAnnotation = YES;
        uint64_t textMessageTimestamp = transcript.timestamp + 1;
        TSOutgoingMessage *textMessage = [[TSOutgoingMessage alloc] initWithTimestamp:textMessageTimestamp
                                                                             inThread:thread
                                                                          messageBody:@""
                                                                        attachmentIds:[NSMutableArray new]
                                                                     expiresInSeconds:transcript.expirationDuration
                                                                      expireStartedAt:transcript.expirationStartedAt];
        textMessage.plainTextBody = outgoingMessage.plainTextBody;
        textMessage.attributedTextBody = outgoingMessage.attributedTextBody;
        textMessage.expiresInSeconds = outgoingMessage.expiresInSeconds;
        textMessage.messageState = TSOutgoingMessageStateDelivered;
        textMessage.messageType = @"content";
        [textMessage save];
    }
    [outgoingMessage save];
    //    }
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
