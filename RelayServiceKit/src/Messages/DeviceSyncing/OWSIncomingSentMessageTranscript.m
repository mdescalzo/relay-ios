//  Copyright © 2016 Open Whisper Systems. All rights reserved.

#import "OWSIncomingSentMessageTranscript.h"
#import "OWSAttachmentsProcessor.h"
#import "OWSSignalServiceProtos.pb.h"
#import "TSMessagesManager.h"
#import "TSOutgoingMessage.h"
#import "TSThread.h"

// Thread finding imports
//#import "TSThread.h"
//#import "TSGroupModel.h"
//#import "TSGroupThread.h"

NS_ASSUME_NONNULL_BEGIN

@interface OWSIncomingSentMessageTranscript()

@property (nonatomic, strong) NSDictionary *jsonPayload;

@end

@implementation OWSIncomingSentMessageTranscript

- (instancetype)initWithProto:(OWSSignalServiceProtosSyncMessageSent *)sentProto relay:(NSString *)relay
{
    self = [super init];
    if (!self) {
        return self;
    }

    _relay = relay;
    _dataMessage = sentProto.message;
    _recipientId = sentProto.destination;
    _timestamp = sentProto.timestamp;
    _expirationStartedAt = sentProto.expirationStartTimestamp;
    _expirationDuration = sentProto.message.expireTimer;
    _body = _dataMessage.body;
    _isGroupUpdate = _dataMessage.hasGroup && (_dataMessage.group.type == OWSSignalServiceProtosGroupContextTypeUpdate);
    _isExpirationTimerUpdate = (_dataMessage.flags & OWSSignalServiceProtosDataMessageFlagsExpirationTimerUpdate) != 0;
    _jsonPayload = [[self arrayFromMessageBody:_body] lastObject];

    return self;
}

- (NSArray<OWSSignalServiceProtosAttachmentPointer *> *)attachmentPointerProtos
{
    if (self.isGroupUpdate && self.dataMessage.group.hasAvatar) {
        return @[ self.dataMessage.group.avatar ];
    } else {
        return self.dataMessage.attachments;
    }
}

- (TSThread *)thread
{
    NSAssert(self.dataMessage.body, @"SyncDataMessage has no body!");
    if (_thread == nil) {
        if ([self.jsonPayload objectForKey:@"threadId"]) {
            _thread = [TSThread getOrCreateThreadWithID:[self.jsonPayload objectForKey:@"threadId"]];
        } else {
            _thread = nil;
        }
    }
    return _thread;
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

-(NSDictionary *)jsonPayload
{
    if (_jsonPayload == nil) {
        if (self.body.length > 0) {
            NSArray *tmpArray = [self arrayFromMessageBody:self.dataMessage.body];
            if (tmpArray.count > 0) {
                _jsonPayload = [tmpArray lastObject];
            }
        }
    }
    return _jsonPayload;
}

@end

NS_ASSUME_NONNULL_END
