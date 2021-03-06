//  Created by Frederic Jacobs on 11/11/14.
//  Copyright (c) 2014 Open Whisper Systems. All rights reserved.

#import "Relay-Swift.h"
#import "TSMessagesManager.h"
#import "ContactsManagerProtocol.h"
#import "MimeTypeUtil.h"
#import "NSData+messagePadding.h"
#import "NSDate+millisecondTimeStamp.h"
#import "OWSAttachmentsProcessor.h"
#import "OWSDisappearingConfigurationUpdateInfoMessage.h"
#import "OWSDisappearingMessagesConfiguration.h"
#import "OWSDisappearingMessagesJob.h"
#import "OWSIncomingSentMessageTranscript.h"
#import "OWSMessageSender.h"
#import "OWSReadReceiptsProcessor.h"
#import "OWSRecordTranscriptJob.h"
#import "OWSSyncContactsMessage.h"
#import "OWSSyncGroupsMessage.h"
#import "OWSAttachmentsProcessor.h"
#import "TSAccountManager.h"
#import "TSAttachmentStream.h"
#import "TSCall.h"
#import "TSThread.h"
#import "TSDatabaseView.h"
#import "TSGroupModel.h"
#import "TSInfoMessage.h"
#import "TSInvalidIdentityKeyReceivingErrorMessage.h"
#import "TSNetworkManager.h"
#import "TSStorageHeaders.h"
#import "TextSecureKitEnv.h"
#import "FLCCSMJSONService.h"
#import "FLDeviceRegistrationService.h"

@import AxolotlKit;

NS_ASSUME_NONNULL_BEGIN

@interface TSMessagesManager ()

@property (nonatomic, readonly) id<ContactsManagerProtocol> contactsManager;
@property (nonatomic, readonly) TSStorageManager *storageManager;
@property (nonatomic, readonly) OWSMessageSender *messageSender;
@property (nonatomic, readonly) OWSDisappearingMessagesJob *disappearingMessagesJob;

@property (nonatomic, readonly) YapDatabaseConnection *readDbConnection;
@property (nonatomic, readonly) YapDatabaseConnection *readWriteDbConnection;
@property (nonatomic, readonly) TSNetworkManager *networkManager;

@property NSUInteger preKeyRetries;

@end

@implementation TSMessagesManager

+ (instancetype)sharedManager {
    static TSMessagesManager *sharedMyManager = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedMyManager = [[self alloc] initDefault];
    });
    return sharedMyManager;
}

- (instancetype)initDefault
{
    TSNetworkManager *networkManager = [TSNetworkManager sharedManager];
    TSStorageManager *storageManager = [TSStorageManager sharedManager];
    id<ContactsManagerProtocol> contactsManager = [TextSecureKitEnv sharedEnv].contactsManager;
    OWSMessageSender *messageSender = [[OWSMessageSender alloc] initWithNetworkManager:networkManager
                                                                        storageManager:storageManager
                                                                       contactsManager:contactsManager];
    
    return [self initWithNetworkManager:networkManager
                         storageManager:storageManager
                        contactsManager:contactsManager
                           messageSender:messageSender];
}

- (instancetype)initWithNetworkManager:(TSNetworkManager *)networkManager
                        storageManager:(TSStorageManager *)storageManager
                       contactsManager:(id<ContactsManagerProtocol>)contactsManager
                         messageSender:(OWSMessageSender *)messageSender
{
    self = [super init];
    
    if (!self) {
        return self;
    }
    
    _storageManager = storageManager;
    _networkManager = networkManager;
    _contactsManager = contactsManager;
    _messageSender = messageSender;
    
    _readDbConnection = storageManager.readDbConnection;
    _readWriteDbConnection = storageManager.writeDbConnection;
    
    _disappearingMessagesJob = [[OWSDisappearingMessagesJob alloc] initWithStorageManager:storageManager];
    
    _preKeyRetries = FLPreKeyRetries;
    
    return self;
}

#pragma mark - message handling

- (void)handleReceivedEnvelope:(OWSSignalServiceProtosEnvelope *)envelope
{
    @try {
        switch (envelope.type) {
            case OWSSignalServiceProtosEnvelopeTypeCiphertext:
                [self handleSecureMessage:envelope];
                break;
            case OWSSignalServiceProtosEnvelopeTypePrekeyBundle:
                [self handlePreKeyBundle:envelope];
                break;
            case OWSSignalServiceProtosEnvelopeTypeReceipt:
                DDLogInfo(@"Received a delivery receipt");
                [self handleDeliveryReceipt:envelope];
                break;
                
                // Other messages are just dismissed for now.
                
            case OWSSignalServiceProtosEnvelopeTypeKeyExchange:
                DDLogWarn(@"Received Key Exchange Message, not supported");
                break;
            case OWSSignalServiceProtosEnvelopeTypeUnknown:
                DDLogWarn(@"Received an unknown message type");
                break;
            default:
                DDLogWarn(@"Received unhandled envelope type: %d", (int)envelope.type);
                break;
        }
    } @catch (NSException *exception) {
        DDLogWarn(@"Received an incorrectly formatted protocol buffer: %@", exception.debugDescription);
    }
}

- (void)handleDeliveryReceipt:(OWSSignalServiceProtosEnvelope *)envelope
{
    __block TSInteraction *interaction = nil;

    [self.readWriteDbConnection readWriteWithBlock:^(YapDatabaseReadWriteTransaction *transaction) {
        interaction = [TSInteraction interactionForTimestamp:envelope.timestamp withTransaction:transaction];
    }];

    if ([interaction isKindOfClass:[TSOutgoingMessage class]]) {
        TSOutgoingMessage *outgoingMessage = (TSOutgoingMessage *)interaction;
        outgoingMessage.messageState = TSOutgoingMessageStateDelivered;

        [outgoingMessage save];
    }
}

- (void)handleSecureMessage:(OWSSignalServiceProtosEnvelope *)messageEnvelope
{
    @synchronized(self) {
        TSStorageManager *storageManager = [TSStorageManager sharedManager];
        NSString *recipientId = messageEnvelope.source;
        int deviceId = (int)messageEnvelope.sourceDevice;
        
        __block BOOL containsSessionId;
        containsSessionId = [storageManager containsSession:recipientId deviceId:deviceId protocolContext:nil];
        if (!containsSessionId) {
            [self.readWriteDbConnection readWriteWithBlock:^(YapDatabaseReadWriteTransaction *transaction) {
                TSErrorMessage *errorMessage =
                [TSErrorMessage missingSessionWithEnvelope:messageEnvelope withTransaction:transaction];
                [errorMessage saveWithTransaction:transaction];
            }];
            return;
        }
        
        // DEPRECATED - Remove after all clients have been upgraded.
        NSData *encryptedData = messageEnvelope.hasContent ? messageEnvelope.content : messageEnvelope.legacyMessage;
        if (!encryptedData) {
            DDLogError(@"Skipping message envelope which had no encrypted data");
            return;
        }
        
        __block NSData *plaintextData;
        @try {
                WhisperMessage *message = [[WhisperMessage alloc] initWithData:encryptedData];
                SessionCipher *cipher = [[SessionCipher alloc] initWithSessionStore:storageManager
                                                                        preKeyStore:storageManager
                                                                  signedPreKeyStore:storageManager
                                                                   identityKeyStore:storageManager
                                                                        recipientId:recipientId
                                                                           deviceId:deviceId];
                
                plaintextData = [[cipher decrypt:message protocolContext:nil] removePadding];
        } @catch (NSException *exception) {
            [self processException:exception envelope:messageEnvelope];
            return;
        }
        
        self.preKeyRetries = FLPreKeyRetries;
        
        if (messageEnvelope.hasContent) {
            OWSSignalServiceProtosContent *content = [OWSSignalServiceProtosContent parseFromData:plaintextData];
            if (content.hasSyncMessage) {
                [self handleIncomingEnvelope:messageEnvelope withSyncMessage:content.syncMessage];
            } else if (content.dataMessage) {
                [self handleIncomingEnvelope:messageEnvelope withDataMessage:content.dataMessage];
            }
        } else if (messageEnvelope.hasLegacyMessage) { // DEPRECATED - Remove after all clients have been upgraded.
            DDLogDebug(@"Received Legacy Message.");
            OWSSignalServiceProtosDataMessage *dataMessage =
            [OWSSignalServiceProtosDataMessage parseFromData:plaintextData];
            [self handleIncomingEnvelope:messageEnvelope withDataMessage:dataMessage];
        } else {
            DDLogWarn(@"Ignoring content that has no dataMessage or syncMessage.");
        }
    }
}

- (void)handlePreKeyBundle:(OWSSignalServiceProtosEnvelope *)preKeyEnvelope
{
    @synchronized(self) {
        TSStorageManager *storageManager = [TSStorageManager sharedManager];
        NSString *recipientId = preKeyEnvelope.source;
        int deviceId = (int)preKeyEnvelope.sourceDevice;
        
        // DEPRECATED - Remove after all clients have been upgraded.
        NSData *encryptedData = preKeyEnvelope.hasContent ? preKeyEnvelope.content : preKeyEnvelope.legacyMessage;
        if (!encryptedData) {
            DDLogError(@"Skipping message envelope which had no encrypted data");
            return;
        }
        
        __block NSData *plaintextData;
        @try {
            PreKeyWhisperMessage *message = [[PreKeyWhisperMessage alloc] initWithData:encryptedData];
            SessionCipher *cipher = [[SessionCipher alloc] initWithSessionStore:storageManager
                                                                    preKeyStore:storageManager
                                                              signedPreKeyStore:storageManager
                                                               identityKeyStore:storageManager
                                                                    recipientId:recipientId
                                                                       deviceId:deviceId];
            plaintextData = [[cipher decrypt:message protocolContext:nil] removePadding];
        } @catch (NSException *exception) {
            [self processException:exception envelope:preKeyEnvelope];
            return;
        }
        
        if (preKeyEnvelope.hasContent) {
            OWSSignalServiceProtosContent *content = [OWSSignalServiceProtosContent parseFromData:plaintextData];
            if (content.hasSyncMessage) {
                [self handleIncomingEnvelope:preKeyEnvelope withSyncMessage:content.syncMessage];
            } else if (content.dataMessage) {
                [self handleIncomingEnvelope:preKeyEnvelope withDataMessage:content.dataMessage];
            }
        } else if (preKeyEnvelope.hasLegacyMessage) { // DEPRECATED - Remove after all clients have been upgraded.
            OWSSignalServiceProtosDataMessage *dataMessage =
            [OWSSignalServiceProtosDataMessage parseFromData:plaintextData];
            [self handleIncomingEnvelope:preKeyEnvelope withDataMessage:dataMessage];
        } else {
            DDLogWarn(@"Ignoring content that has no dataMessage or syncMessage.");
        }
    }
}

- (void)handleIncomingEnvelope:(OWSSignalServiceProtosEnvelope *)incomingEnvelope
               withDataMessage:(OWSSignalServiceProtosDataMessage *)dataMessage
{
    if (dataMessage.hasGroup) {
        // Since no clients should be using this, this should never trip
        DDLogError(@"%@ Old school group message received.", self.tag);
    }
    if ((dataMessage.flags & OWSSignalServiceProtosDataMessageFlagsEndSession) != 0) {
        DDLogVerbose(@"%@ Received end session message", self.tag);
        [self handleEndSessionMessageWithEnvelope:incomingEnvelope dataMessage:dataMessage];
    } else if ((dataMessage.flags & OWSSignalServiceProtosDataMessageFlagsExpirationTimerUpdate) != 0) {
        DDLogVerbose(@"%@ Received expiration timer update message", self.tag);
        [self handleExpirationTimerUpdateMessageWithEnvelope:incomingEnvelope dataMessage:dataMessage];
    } else if (dataMessage.attachments.count > 0) {
        DDLogVerbose(@"%@ Received media message attachment", self.tag);
        [self handleReceivedMediaWithEnvelope:incomingEnvelope dataMessage:dataMessage];
    } else {
        DDLogVerbose(@"%@ Received data message.", self.tag);
        [self handleReceivedTextMessageWithEnvelope:incomingEnvelope dataMessage:dataMessage];
        if ([self isDataMessageGroupAvatarUpdate:dataMessage]) {
            DDLogError(@"%@ Data message had group avatar attachment, deprecated", self.tag);
        }
    }
}

- (void)handleReceivedMediaWithEnvelope:(OWSSignalServiceProtosEnvelope *)envelope
                            dataMessage:(OWSSignalServiceProtosDataMessage *)dataMessage
{
    //  Catch incoming messages and process the new way.
    __block NSDictionary *jsonPayload = [FLCCSMJSONService payloadDictionaryFromMessageBody:dataMessage.body];
    
    NSDictionary *dataBlob = [jsonPayload objectForKey:@"data"];
    if ([dataBlob allKeys].count == 0) {
        DDLogDebug(@"Received message contained no data object.");
        return;
    }
    // Process per messageType
    if ([[jsonPayload objectForKey:@"messageType"] isEqualToString:@"control"]) {
        NSString *controlMessageType = [dataBlob objectForKey:@"control"];
        DDLogInfo(@"Control message received: %@", controlMessageType);
        
        NSString *threadId = [jsonPayload objectForKey:@"threadId"];
        if (threadId.length > 0) {
            TSThread *thread = [TSThread getOrCreateThreadWithID:threadId];
            
            IncomingControlMessage *controlMessage = [[IncomingControlMessage alloc] initWithThread:thread
                                                                                             author:envelope.source
                                                                                              relay:envelope.relay
                                                                                            payload:jsonPayload
                                                                                        attachments:dataMessage.attachments];
            [ControlMessageManager processIncomingControlMessageWithMessage:controlMessage];
        }
        
    } else { // if ([[jsonPayload objectForKey:@"messageType"] isEqualToString:@"content"]) {
        DDLogDebug(@"%@: Received media message of type: %@", self.tag, [jsonPayload objectForKey:@"messageType"]);
        TSThread *thread = [self threadForEnvelope:envelope dataMessage:dataMessage];
        
        NSMutableArray *properties = [NSMutableArray new];
        for (OWSSignalServiceProtosAttachmentPointer *pointer in dataMessage.attachments) {
            [properties addObject:@{ @"name": pointer.fileName }];
        }
        
        OWSAttachmentsProcessor *attachmentsProcessor =
        [[OWSAttachmentsProcessor alloc] initWithAttachmentProtos:dataMessage.attachments
                                                       properties:properties
                                                        timestamp:envelope.timestamp
                                                            relay:envelope.relay
                                                           thread:thread
                                                   networkManager:self.networkManager];
        if (!attachmentsProcessor.hasSupportedAttachments) {
            DDLogWarn(@"%@ received unsupported media envelope", self.tag);
            return;
        }
        
        TSIncomingMessage *createdMessage = [self handleReceivedEnvelope:envelope
                                                         withDataMessage:dataMessage
                                                           attachmentIds:attachmentsProcessor.supportedAttachmentIds];
        
        [attachmentsProcessor fetchAttachmentsForMessage:createdMessage
                                                 success:^(TSAttachmentStream *_Nonnull attachmentStream) {
                                                     DDLogDebug(
                                                                @"%@ successfully fetched attachment: %@ for message: %@", self.tag, attachmentStream, createdMessage);
                                                 }
                                                 failure:^(NSError *_Nonnull error) {
                                                     DDLogError(
                                                                @"%@ failed to fetch attachments for message: %@ with error: %@", self.tag, createdMessage, error);
                                                 }];
    }
}

- (void)handleIncomingEnvelope:(OWSSignalServiceProtosEnvelope *)messageEnvelope
               withSyncMessage:(OWSSignalServiceProtosSyncMessage *)syncMessage
{
    if (syncMessage.hasSent) {
        DDLogInfo(@"%@ Received `sent` syncMessage, recording message transcript.", self.tag);
        OWSIncomingSentMessageTranscript *transcript =
        [[OWSIncomingSentMessageTranscript alloc] initWithProto:syncMessage.sent relay:messageEnvelope.relay];
        
        OWSRecordTranscriptJob *recordJob =
        [[OWSRecordTranscriptJob alloc] initWithIncomingSentMessageTranscript:transcript
                                                                messageSender:self.messageSender
                                                               networkManager:self.networkManager];
        
            [recordJob runWithAttachmentHandler:^(TSAttachmentStream *_Nonnull attachmentStream) {
                DDLogDebug(@"%@ successfully fetched transcript attachment: %@", self.tag, attachmentStream);
            }];
    } else if (syncMessage.hasRequest) {
        DDLogDebug(@"%@ Unhandled sync message received.  syncMessage.hasRequest.", self.tag);
    } else if (syncMessage.read.count > 0) {
        DDLogInfo(@"%@ Received %ld read receipt(s)", self.tag, (u_long)syncMessage.read.count);
        
        OWSReadReceiptsProcessor *readReceiptsProcessor =
        [[OWSReadReceiptsProcessor alloc] initWithReadReceiptProtos:syncMessage.read
                                                     storageManager:self.storageManager];
        [readReceiptsProcessor process];
    } else {
        DDLogWarn(@"%@ Ignoring unsupported sync message.", self.tag);
    }
}

- (void)handleEndSessionMessageWithEnvelope:(OWSSignalServiceProtosEnvelope *)endSessionEnvelope
                                dataMessage:(OWSSignalServiceProtosDataMessage *)dataMessage
{
    [self.readWriteDbConnection asyncReadWriteWithBlock:^(YapDatabaseReadWriteTransaction *transaction) {
        NSDictionary *messagePayload = [FLCCSMJSONService payloadDictionaryFromMessageBody:dataMessage.body];
        NSString *threadid = [messagePayload objectForKey:@"threadId"];
        TSThread *thread = [TSThread getOrCreateThreadWithID:threadid transaction:transaction];
        uint64_t timeStamp = endSessionEnvelope.timestamp;
        
        if (thread) { // TODO thread should always be nonnull.
            [[[TSInfoMessage alloc] initWithTimestamp:timeStamp
                                             inThread:thread
                                          messageType:TSInfoMessageTypeSessionDidEnd] saveWithTransaction:transaction];
        }
        
        [[TSStorageManager sharedManager] deleteAllSessionsForContact:endSessionEnvelope.source protocolContext:transaction];
    }];
}

- (void)handleExpirationTimerUpdateMessageWithEnvelope:(OWSSignalServiceProtosEnvelope *)envelope
                                           dataMessage:(OWSSignalServiceProtosDataMessage *)dataMessage
{
    TSThread *thread = [self threadForEnvelope:envelope dataMessage:dataMessage];
    
    OWSDisappearingMessagesConfiguration *disappearingMessagesConfiguration;
    if (dataMessage.hasExpireTimer && dataMessage.expireTimer > 0) {
        DDLogInfo(@"%@ Expiring messages duration turned to %u for thread %@",
                  self.tag,
                  (unsigned int)dataMessage.expireTimer,
                  thread);
        disappearingMessagesConfiguration =
        [[OWSDisappearingMessagesConfiguration alloc] initWithThreadId:thread.uniqueId
                                                               enabled:YES
                                                       durationSeconds:dataMessage.expireTimer];
    } else {
        DDLogInfo(@"%@ Expiring messages have been turned off for thread %@", self.tag, thread);
        disappearingMessagesConfiguration = [[OWSDisappearingMessagesConfiguration alloc]
                                             initWithThreadId:thread.uniqueId
                                             enabled:NO
                                             durationSeconds:OWSDisappearingMessagesConfigurationDefaultExpirationDuration];
    }
    [disappearingMessagesConfiguration save];
    NSString *name = [self.contactsManager nameStringForContactId:envelope.source];
    OWSDisappearingConfigurationUpdateInfoMessage *message =
    [[OWSDisappearingConfigurationUpdateInfoMessage alloc] initWithTimestamp:envelope.timestamp
                                                                      thread:thread
                                                               configuration:disappearingMessagesConfiguration
                                                         createdByRemoteName:name];
    [message save];
}

- (void)handleReceivedTextMessageWithEnvelope:(OWSSignalServiceProtosEnvelope *)textMessageEnvelope
                                  dataMessage:(OWSSignalServiceProtosDataMessage *)dataMessage
{
    [self handleReceivedEnvelope:textMessageEnvelope withDataMessage:dataMessage attachmentIds:@[]];
}

- (TSIncomingMessage *)handleReceivedEnvelope:(OWSSignalServiceProtosEnvelope *)envelope
                              withDataMessage:(OWSSignalServiceProtosDataMessage *)dataMessage
                                attachmentIds:(NSArray<NSString *> *)attachmentIds
{
    //  Catch incoming messages and process the new way.
    __block NSDictionary *jsonPayload = [FLCCSMJSONService payloadDictionaryFromMessageBody:dataMessage.body];
    
    NSDictionary *dataBlob = [jsonPayload objectForKey:@"data"];
    if ([dataBlob allKeys].count == 0) {
        DDLogDebug(@"Received message contained no data object.");
        return nil;
    }
    // Process per messageType
    if ([[jsonPayload objectForKey:@"messageType"] isEqualToString:@"control"]) {
        NSString *controlMessageType = [dataBlob objectForKey:@"control"];
        DDLogInfo(@"Control message received: %@", controlMessageType);
        
        NSString *threadId = [jsonPayload objectForKey:@"threadId"];
        if (threadId.length > 0) {
            TSThread *thread = [TSThread getOrCreateThreadWithID:threadId];
            
            IncomingControlMessage *controlMessage = [[IncomingControlMessage alloc] initWithThread:thread
                                                                                             author:envelope.source
                                                                                              relay:envelope.relay
                                                                                            payload:jsonPayload
                                                                                        attachments:dataMessage.attachments];
            [ControlMessageManager processIncomingControlMessageWithMessage:controlMessage];
        }
        return nil;
        
    } else if ([[jsonPayload objectForKey:@"messageType"] isEqualToString:@"content"]) {
        // Process per Thread type
        if ([[jsonPayload objectForKey:@"threadType"] isEqualToString:@"conversation"] ||
            [[jsonPayload objectForKey:@"threadType"] isEqualToString:@"announcement"]) {
            return [self handleThreadContentMessageWithEnvelope:envelope
                                                withDataMessage:dataMessage
                                                  attachmentIds:attachmentIds];            
        } else {
            DDLogDebug(@"Unhandled thread type: %@", [jsonPayload objectForKey:@"threadType"]);
            return nil;
        }
    } else {
        DDLogDebug(@"Unhandled message type: %@", [jsonPayload objectForKey:@"messageType"]);
        return nil;
    }
}

- (void)processException:(NSException *)exception envelope:(OWSSignalServiceProtosEnvelope *)envelope
{
    DDLogError(@"%@ Got exception: %@ of type: %@", self.tag, exception.description, exception.name);
    
    __block TSInvalidIdentityKeyReceivingErrorMessage *keyErrorMessage = nil;
    [self.readWriteDbConnection readWriteWithBlock:^(YapDatabaseReadWriteTransaction *transaction) {
        TSErrorMessage *errorMessage;
        
        if ([exception.name isEqualToString:NoSessionException]) {
            errorMessage = [TSErrorMessage missingSessionWithEnvelope:envelope withTransaction:transaction];
        } else if ([exception.name isEqualToString:InvalidKeyException]) {
            errorMessage = [TSErrorMessage invalidKeyExceptionWithEnvelope:envelope withTransaction:transaction];
        } else if ([exception.name isEqualToString:InvalidKeyIdException]) {
            errorMessage = [TSErrorMessage invalidKeyExceptionWithEnvelope:envelope withTransaction:transaction];
        } else if ([exception.name isEqualToString:DuplicateMessageException]) {
            // Duplicate messages are dismissed
            return;
        } else if ([exception.name isEqualToString:InvalidVersionException]) {
            errorMessage = [TSErrorMessage invalidVersionWithEnvelope:envelope withTransaction:transaction];
        } else if ([exception.name isEqualToString:UntrustedIdentityKeyException]) {
            // Automatically accept safety number changes.
            errorMessage = nil; // [TSInvalidIdentityKeyReceivingErrorMessage untrustedKeyWithEnvelope:envelope withTransaction:transaction];
            keyErrorMessage = [TSInvalidIdentityKeyReceivingErrorMessage untrustedKeyWithEnvelope:envelope withTransaction:transaction];
        } else {
            errorMessage = [TSErrorMessage corruptedMessageWithEnvelope:envelope withTransaction:transaction];
        }
        
        if (errorMessage) {
            [errorMessage saveWithTransaction:transaction];
        }
    }];
    
    if (keyErrorMessage) {
        [keyErrorMessage acceptNewIdentityKey];
        if (self.preKeyRetries > 0) {
            [self handlePreKeyBundle:envelope];
        }
        self.preKeyRetries -= 1;
    }
}

#pragma mark - helpers

- (BOOL)isDataMessageGroupAvatarUpdate:(OWSSignalServiceProtosDataMessage *)dataMessage
{
    return dataMessage.hasGroup
    && dataMessage.group.type == OWSSignalServiceProtosGroupContextTypeUpdate
    && dataMessage.group.hasAvatar;
}

- (TSThread *)threadForEnvelope:(OWSSignalServiceProtosEnvelope *)envelope
                    dataMessage:(OWSSignalServiceProtosDataMessage *)dataMessage
{
    NSDictionary *messagePayload = [FLCCSMJSONService payloadDictionaryFromMessageBody:dataMessage.body];
    NSString *threadId = [messagePayload objectForKey:@"threadId"];
    return [TSThread getOrCreateThreadWithID:threadId];
}

- (NSUInteger)unreadMessagesCount {
    __block NSUInteger numberOfItems;
    [self.readDbConnection readWithBlock:^(YapDatabaseReadTransaction *transaction) {
        numberOfItems = [[transaction ext:TSUnreadDatabaseViewExtensionName] numberOfItemsInAllGroups];
    }];
    
    return numberOfItems;
}

- (NSUInteger)unreadMessagesCountExcept:(TSThread *)thread {
    __block NSUInteger numberOfItems;
    [self.readDbConnection readWithBlock:^(YapDatabaseReadTransaction *transaction) {
        numberOfItems = [[transaction ext:TSUnreadDatabaseViewExtensionName] numberOfItemsInAllGroups];
        numberOfItems =
        numberOfItems - [[transaction ext:TSUnreadDatabaseViewExtensionName] numberOfItemsInGroup:thread.uniqueId];
    }];
    
    return numberOfItems;
}

- (NSUInteger)unreadMessagesInThread:(TSThread *)thread {
    __block NSUInteger numberOfItems;
    [self.readDbConnection readWithBlock:^(YapDatabaseReadTransaction *transaction) {
        numberOfItems = [[transaction ext:TSUnreadDatabaseViewExtensionName] numberOfItemsInGroup:thread.uniqueId];
    }];
    return numberOfItems;
}

#pragma mark - message handlers by type
-(TSIncomingMessage *)handleThreadContentMessageWithEnvelope:(OWSSignalServiceProtosEnvelope *)envelope
                                             withDataMessage:(OWSSignalServiceProtosDataMessage *)dataMessage
                                               attachmentIds:(NSArray<NSString *> *)attachmentIds
{
    NSDictionary *jsonPayload = [FLCCSMJSONService payloadDictionaryFromMessageBody:dataMessage.body];
    TSIncomingMessage *incomingMessage = nil;
    TSThread *thread = nil;
    NSString *threadId = [jsonPayload objectForKey:@"threadId"];
    
    // getOrCreate a thread and an incomingMessage
    thread = [TSThread getOrCreateThreadWithID:threadId];
    
    // Check to see if we already have this message
    incomingMessage = [TSIncomingMessage fetchObjectWithUniqueID:[jsonPayload objectForKey:@"messageId"]];
    
    if (incomingMessage == nil) {
        incomingMessage = [[TSIncomingMessage alloc] initWithTimestamp:envelope.timestamp
                                                              inThread:thread
                                                              authorId:envelope.source
                                                           messageBody:dataMessage.body
                                                         attachmentIds:attachmentIds
                                                      expiresInSeconds:dataMessage.expireTimer];
        incomingMessage.uniqueId = [jsonPayload objectForKey:@"messageId"];
        incomingMessage.messageType = [jsonPayload objectForKey:@"messageType"];
    }
    incomingMessage.forstaPayload = [jsonPayload mutableCopy];
    
    // Android & web client allow attachments to be sent with body.
    if (attachmentIds.count > 0 && incomingMessage.plainTextBody.length > 0) {
        incomingMessage.hasAnnotation = YES;
        // We want the text to be displayed under the attachment
        uint64_t textMessageTimestamp = envelope.timestamp + 1;
        TSIncomingMessage *textMessage = [[TSIncomingMessage alloc] initWithTimestamp:textMessageTimestamp
                                                                             inThread:thread
                                                                             authorId:envelope.source
                                                                          messageBody:@""];
        textMessage.plainTextBody = incomingMessage.plainTextBody;
        textMessage.attributedTextBody = incomingMessage.attributedTextBody;
        textMessage.expiresInSeconds = dataMessage.expireTimer;
        textMessage.messageType = @"content";
        [textMessage save];
    }
    [incomingMessage save];
    
    // Ensure the thread is updated in background
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{
        [thread updateWithPayload:jsonPayload];
        [thread touch];
    });
    
    if (incomingMessage && thread) {
        // In case we already have a read receipt for this new message (happens sometimes).
        OWSReadReceiptsProcessor *readReceiptsProcessor =
        [[OWSReadReceiptsProcessor alloc] initWithIncomingMessage:incomingMessage
                                                   storageManager:self.storageManager];
        [readReceiptsProcessor process];
        
        [self.disappearingMessagesJob becomeConsistentWithConfigurationForMessage:incomingMessage
                                                                  contactsManager:self.contactsManager];
        
        // TODO Delay notification by 100ms?
        // It's pretty annoying when you're phone keeps buzzing while you're having a conversation on Desktop.
        
        NSString *senderName = [Environment.getCurrent.contactsManager nameStringForContactId:envelope.source];
        [[TextSecureKitEnv sharedEnv].notificationsManager notifyUserForIncomingMessage:incomingMessage
                                                                                   from:senderName
                                                                               inThread:thread];
        return incomingMessage;
    } else {
        DDLogDebug(@"Unable to process incoming message.");
        return nil;
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
