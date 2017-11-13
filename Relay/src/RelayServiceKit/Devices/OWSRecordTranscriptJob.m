//  Created by Michael Kirk on 9/23/16.
//  Copyright © 2016 Open Whisper Systems. All rights reserved.

#import "OWSRecordTranscriptJob.h"
#import "OWSAttachmentsProcessor.h"
#import "OWSDisappearingMessagesJob.h"
#import "OWSIncomingSentMessageTranscript.h"
#import "OWSMessageSender.h"
#import "TSOutgoingMessage.h"
#import "TSStorageManager.h"

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
    TSThread *thread = transcript.thread;
    
    // Intercept and attach forstaPayload
    NSArray *jsonArray = [self arrayFromMessageBody:transcript.body];
    NSDictionary *jsonPayload;
    if (jsonArray.count > 0) {
        DDLogDebug(@"JSON Payload received.");
        jsonPayload = [jsonArray lastObject];
    }
    NSDictionary *dataBlob = [jsonPayload objectForKey:@"data"];
    
    OWSAttachmentsProcessor *attachmentsProcessor =
    [[OWSAttachmentsProcessor alloc] initWithAttachmentProtos:transcript.attachmentPointerProtos
                                                   properties:[dataBlob objectForKey:@"attachments"]
                                                    timestamp:transcript.timestamp
                                                        relay:transcript.relay
                                                       thread:thread
                                               networkManager:self.networkManager];
    
    // TODO group updates. Currently desktop doesn't support group updates, so not a problem yet.
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

#pragma mark - JSON body parsing methods
-(nullable NSArray *)arrayFromMessageBody:(NSString *)body
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
