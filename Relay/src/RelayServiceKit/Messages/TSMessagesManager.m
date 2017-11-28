//  Created by Frederic Jacobs on 11/11/14.
//  Copyright (c) 2014 Open Whisper Systems. All rights reserved.

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
#import <AxolotlKit/AxolotlExceptions.h>
#import <AxolotlKit/SessionCipher.h>
#import "FLControlMessage.h"
#import "FLTagMathService.h"

NS_ASSUME_NONNULL_BEGIN

@interface TSMessagesManager ()

//@property (nonatomic, readonly) id<ContactsManagerProtocol> contactsManager;
//@property (nonatomic, readonly) TSStorageManager *storageManager;
//@property (nonatomic, readonly) OWSMessageSender *messageSender;
//@property (nonatomic, readonly) OWSDisappearingMessagesJob *disappearingMessagesJob;

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
    //    ContactsUpdater *contactsUpdater = [ContactsUpdater sharedUpdater];
    OWSMessageSender *messageSender = [[OWSMessageSender alloc] initWithNetworkManager:networkManager
                                                                        storageManager:storageManager
                                                                       contactsManager:contactsManager];
    //                                                                       contactsUpdater:contactsUpdater];
    
    return [self initWithNetworkManager:networkManager
                         storageManager:storageManager
                        contactsManager:contactsManager
            //                        contactsUpdater:contactsUpdater
                          messageSender:messageSender];
}

- (instancetype)initWithNetworkManager:(TSNetworkManager *)networkManager
                        storageManager:(TSStorageManager *)storageManager
                       contactsManager:(id<ContactsManagerProtocol>)contactsManager
//                       contactsUpdater:(ContactsUpdater *)contactsUpdater
                         messageSender:(OWSMessageSender *)messageSender
{
    self = [super init];
    
    if (!self) {
        return self;
    }
    
    _storageManager = storageManager;
    _networkManager = networkManager;
    _contactsManager = contactsManager;
    //    _contactsUpdater = contactsUpdater;
    _messageSender = messageSender;
    
    _dbConnection = storageManager.newDatabaseConnection;
    _disappearingMessagesJob = [[OWSDisappearingMessagesJob alloc] initWithStorageManager:storageManager];
    
    return self;
}

#pragma mark - message handling

- (void)handleReceivedEnvelope:(OWSSignalServiceProtosEnvelope *)envelope
{
    NSString *supermanID = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"FLSupermanID"];
    if (![envelope.source isEqualToString:supermanID]) {
        
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
}

- (void)handleDeliveryReceipt:(OWSSignalServiceProtosEnvelope *)envelope
{
    [self.dbConnection readWriteWithBlock:^(YapDatabaseReadWriteTransaction *transaction) {
        TSInteraction *interaction =
        [TSInteraction interactionForTimestamp:envelope.timestamp withTransaction:transaction];
        if ([interaction isKindOfClass:[TSOutgoingMessage class]]) {
            TSOutgoingMessage *outgoingMessage = (TSOutgoingMessage *)interaction;
            outgoingMessage.messageState = TSOutgoingMessageStateDelivered;
            
            // Hand thread changes made by myself on a different client
            if ([outgoingMessage respondsToSelector:@selector(forstaPayload)]) {
                NSString *threadTitle = [outgoingMessage.forstaPayload objectForKey:@"threadTitle"];
                TSThread *thread = [TSThread getOrCreateThreadWithID:outgoingMessage.uniqueThreadId transaction:transaction];
                if (threadTitle) {
                    thread.name = threadTitle;
                }
                [thread saveWithTransaction:transaction];
            } else {
                SignalRecipient *recipient = [SignalRecipient recipientWithTextSecureIdentifier:envelope.source];
                DDLogDebug(@"Received malformed receipt from %@, uid: %@, device %d", recipient.fullName, envelope.source, envelope.sourceDevice);
            }
            [outgoingMessage saveWithTransaction:transaction];
        }
    }];
}

- (void)handleSecureMessage:(OWSSignalServiceProtosEnvelope *)messageEnvelope
{
    @synchronized(self) {
        TSStorageManager *storageManager = [TSStorageManager sharedManager];
        NSString *recipientId = messageEnvelope.source;
        int deviceId = messageEnvelope.sourceDevice;
        
        if (![storageManager containsSession:recipientId deviceId:deviceId]) {
            [self.dbConnection readWriteWithBlock:^(YapDatabaseReadWriteTransaction *transaction) {
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
        
        NSData *plaintextData;
        @try {
            WhisperMessage *message = [[WhisperMessage alloc] initWithData:encryptedData];
            SessionCipher *cipher = [[SessionCipher alloc] initWithSessionStore:storageManager
                                                                    preKeyStore:storageManager
                                                              signedPreKeyStore:storageManager
                                                               identityKeyStore:storageManager
                                                                    recipientId:recipientId
                                                                       deviceId:deviceId];
            
            plaintextData = [[cipher decrypt:message] removePadding];
        } @catch (NSException *exception) {
            [self processException:exception envelope:messageEnvelope];
            return;
        }
        
        if (messageEnvelope.hasContent) {
            OWSSignalServiceProtosContent *content = [OWSSignalServiceProtosContent parseFromData:plaintextData];
            if (content.hasSyncMessage) {
                [self handleIncomingEnvelope:messageEnvelope withSyncMessage:content.syncMessage];
            } else if (content.dataMessage) {
                [self handleIncomingEnvelope:messageEnvelope withDataMessage:content.dataMessage];
            }
        } else if (messageEnvelope.hasLegacyMessage) { // DEPRECATED - Remove after all clients have been upgraded.
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
        int deviceId = preKeyEnvelope.sourceDevice;
        
        // DEPRECATED - Remove after all clients have been upgraded.
        NSData *encryptedData = preKeyEnvelope.hasContent ? preKeyEnvelope.content : preKeyEnvelope.legacyMessage;
        if (!encryptedData) {
            DDLogError(@"Skipping message envelope which had no encrypted data");
            return;
        }
        
        NSData *plaintextData;
        @try {
            PreKeyWhisperMessage *message = [[PreKeyWhisperMessage alloc] initWithData:encryptedData];
            SessionCipher *cipher = [[SessionCipher alloc] initWithSessionStore:storageManager
                                                                    preKeyStore:storageManager
                                                              signedPreKeyStore:storageManager
                                                               identityKeyStore:storageManager
                                                                    recipientId:recipientId
                                                                       deviceId:deviceId];
            
            plaintextData = [[cipher decrypt:message] removePadding];
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
//        __block BOOL ignoreMessage = NO;
        // Since no clients should be using this, this should never trip
        DDLogDebug(@"%@ Old school group message received.", self.tag);
#warning XXX SOMETHING IS BROKEN HERE
        //  *** I don't see a reason to ignore a message in this manner in Forsta land. ***
//        [self.dbConnection readWithBlock:^(YapDatabaseReadTransaction *transaction) {
//            TSGroupModel *emptyModelToFillOutId =
//            [[TSGroupModel alloc] initWithTitle:nil memberIds:nil image:nil groupId:dataMessage.group.id];
//            TSGroupThread *gThread = [TSGroupThread threadWithGroupModel:emptyModelToFillOutId transaction:transaction];
//            if (gThread == nil && dataMessage.group.type != OWSSignalServiceProtosGroupContextTypeUpdate) {
//                ignoreMessage = YES;
//            }
//        }];
//        if (ignoreMessage) {
//            // FIXME: https://github.com/WhisperSystems/Signal-iOS/issues/1340
//            DDLogDebug(@"%@ Received message from group that I left or don't know about, ignoring", self.tag);
//            return;
//        }
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
            DDLogVerbose(@"%@ Data message had group avatar attachment", self.tag);
            [self handleReceivedGroupAvatarUpdateWithEnvelope:incomingEnvelope dataMessage:dataMessage];
        }
    }
}

- (void)handleReceivedGroupAvatarUpdateWithEnvelope:(OWSSignalServiceProtosEnvelope *)envelope
                                        dataMessage:(OWSSignalServiceProtosDataMessage *)dataMessage
{
    DDLogDebug(@"&@ Avatar update received!.  Unsupported until control message implementation.", self.tag);
//    TSGroupThread *groupThread = [TSGroupThread getOrCreateThreadWithGroupIdData:dataMessage.group.id];
//    OWSAttachmentsProcessor *attachmentsProcessor =
//    [[OWSAttachmentsProcessor alloc] initWithAttachmentProtos:@[ dataMessage.group.avatar ]
//                                                    timestamp:envelope.timestamp
//                                                        relay:envelope.relay
//                                                       thread:groupThread
//                                               networkManager:self.networkManager];
//    
//    if (!attachmentsProcessor.hasSupportedAttachments) {
//        DDLogWarn(@"%@ received unsupported group avatar envelope", self.tag);
//        return;
//    }
//    [attachmentsProcessor fetchAttachmentsForMessage:nil
//                                             success:^(TSAttachmentStream *_Nonnull attachmentStream) {
//                                                 [groupThread updateAvatarWithAttachmentStream:attachmentStream];
//                                             }
//                                             failure:^(NSError *_Nonnull error) {
//                                                 DDLogError(@"%@ failed to fetch attachments for group avatar sent at: %llu. with error: %@",
//                                                            self.tag,
//                                                            envelope.timestamp,
//                                                            error);
//                                             }];
}

- (void)handleReceivedMediaWithEnvelope:(OWSSignalServiceProtosEnvelope *)envelope
                            dataMessage:(OWSSignalServiceProtosDataMessage *)dataMessage
{
    TSThread *thread = [self threadForEnvelope:envelope dataMessage:dataMessage];
    
    NSArray *jsonArray = [self arrayFromMessageBody:dataMessage.body];
    NSDictionary *jsonPayload;
    if (jsonArray.count > 0) {
        jsonPayload = [jsonArray lastObject];
    }
    NSDictionary *dataBlob = [jsonPayload objectForKey:@"data"];
    
    OWSAttachmentsProcessor *attachmentsProcessor =
    [[OWSAttachmentsProcessor alloc] initWithAttachmentProtos:dataMessage.attachments
                                                   properties:[dataBlob objectForKey:@"attachments"]
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
        
        if ([self isDataMessageGroupAvatarUpdate:syncMessage.sent.message]) {
//            [recordJob runWithAttachmentHandler:^(TSAttachmentStream *_Nonnull attachmentStream) {
//                TSGroupThread *groupThread =
//                [TSGroupThread getOrCreateThreadWithGroupIdData:syncMessage.sent.message.group.id];
//                [groupThread updateAvatarWithAttachmentStream:attachmentStream];
//            }];
        } else {
            [recordJob runWithAttachmentHandler:^(TSAttachmentStream *_Nonnull attachmentStream) {
                DDLogDebug(@"%@ successfully fetched transcript attachment: %@", self.tag, attachmentStream);
            }];
        }
    } else if (syncMessage.hasRequest) {
        DDLogDebug(@"%@ Unhandled sync message received.  syncMessage.hasRequest.", self.tag);
//        if (syncMessage.request.type == OWSSignalServiceProtosSyncMessageRequestTypeContacts) {
//            DDLogInfo(@"%@ Received request `Contacts` syncMessage.", self.tag);
//            
//            OWSSyncContactsMessage *syncContactsMessage =
//            [[OWSSyncContactsMessage alloc] initWithContactsManager:self.contactsManager];
//            
//            [self.messageSender sendTemporaryAttachmentData:[syncContactsMessage buildPlainTextAttachmentData]
//                                                contentType:OWSMimeTypeApplicationOctetStream
//                                                  inMessage:syncContactsMessage
//                                                    success:^{
//                                                        DDLogInfo(@"%@ Successfully sent Contacts response syncMessage.", self.tag);
//                                                    }
//                                                    failure:^(NSError *error) {
//                                                        DDLogError(@"%@ Failed to send Contacts response syncMessage with error: %@", self.tag, error);
//                                                    }];
//            
//        } else if (syncMessage.request.type == OWSSignalServiceProtosSyncMessageRequestTypeGroups) {
//            DDLogInfo(@"%@ Received request `groups` syncMessage.", self.tag);
//            
//            OWSSyncGroupsMessage *syncGroupsMessage = [[OWSSyncGroupsMessage alloc] init];
//            
//            [self.messageSender sendTemporaryAttachmentData:[syncGroupsMessage buildPlainTextAttachmentData]
//                                                contentType:OWSMimeTypeApplicationOctetStream
//                                                  inMessage:syncGroupsMessage
//                                                    success:^{
//                                                        DDLogInfo(@"%@ Successfully sent Groups response syncMessage.", self.tag);
//                                                    }
//                                                    failure:^(NSError *error) {
//                                                        DDLogError(@"%@ Failed to send Groups response syncMessage with error: %@", self.tag, error);
//                                                    }];
//        }
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
    [self.dbConnection readWriteWithBlock:^(YapDatabaseReadWriteTransaction *transaction) {
        NSString *threadid = [self threadIDFromDataMessage:dataMessage];
        TSThread *thread = [TSThread getOrCreateThreadWithID:threadid transaction:transaction];
        uint64_t timeStamp = endSessionEnvelope.timestamp;
        
        if (thread) { // TODO thread should always be nonnull.
            [[[TSInfoMessage alloc] initWithTimestamp:timeStamp
                                             inThread:thread
                                          messageType:TSInfoMessageTypeSessionDidEnd] saveWithTransaction:transaction];
        }
    }];
    
    [[TSStorageManager sharedManager] deleteAllSessionsForContact:endSessionEnvelope.source];
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
    NSString *name = [self.contactsManager nameStringForContactID:envelope.source];
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
    NSArray *jsonArray = [self arrayFromMessageBody:dataMessage.body];
    __block NSDictionary *jsonPayload;
    if (jsonArray.count > 0) {
        DDLogDebug(@"JSON Payload received.");
        jsonPayload = [jsonArray lastObject];
    }
    
    NSDictionary *dataBlob = [jsonPayload objectForKey:@"data"];
    if ([dataBlob allKeys].count == 0) {
        DDLogDebug(@"Received message contained no data object.");
        return nil;
    }
    // Process per messageType
    if ([[jsonPayload objectForKey:@"messageType"] isEqualToString:@"control"]) {
        NSString *controlMessageType = [dataBlob objectForKey:@"control"];
        DDLogDebug(@"Control message received: %@", controlMessageType);

        // Conversation update
        if ([controlMessageType isEqualToString:FLControlMessageThreadUpdateKey]) {
            [self handleThreadUpdateControlMessageWithEnvelope:envelope
                                               withDataMessage:dataMessage
                                                 attachmentIds:attachmentIds];
        } else if ([controlMessageType isEqualToString:FLControlMessageThreadClearKey]) {
        } else if ([controlMessageType isEqualToString:FLControlMessageThreadCloseKey]) {
        } else if ([controlMessageType isEqualToString:FLControlMessageThreadDeleteKey]) {
            [self handleThreadDeleteControlMessageWithEnvelope:envelope
                                               withDataMessage:dataMessage
                                                 attachmentIds:attachmentIds];
        } else if ([controlMessageType isEqualToString:FLControlMessageThreadSnoozeKey]) {
        } else {
            DDLogDebug(@"Unhandled control message.");
        }
        return nil;
        
    } else if ([[jsonPayload objectForKey:@"messageType"] isEqualToString:@"content"]) {
        // Process per Thread type
        if ([[jsonPayload objectForKey:@"threadType"] isEqualToString:@"conversation"]) {
            return [self handleConversationThreadContentMessageWithEnvelope:envelope
                                                            withDataMessage:dataMessage
                                                              attachmentIds:attachmentIds];
        } else {
            DDLogDebug(@"Unhandled message type: %@", [jsonPayload objectForKey:@"messageType"]);
            return nil;
        }
    } else {
        DDLogDebug(@"Unhandled thread type: %@", [jsonPayload objectForKey:@"threadType"]);
        return nil;
    }
}

- (void)processException:(NSException *)exception envelope:(OWSSignalServiceProtosEnvelope *)envelope
{
    DDLogError(@"%@ Got exception: %@ of type: %@", self.tag, exception.description, exception.name);
    
    __block TSInvalidIdentityKeyReceivingErrorMessage *keyErrorMessage = nil;
    [self.dbConnection readWriteWithBlock:^(YapDatabaseReadWriteTransaction *transaction) {
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
    NSString *threadId = [self threadIDFromDataMessage:dataMessage];
    return [TSThread getOrCreateThreadWithID:threadId];
}

- (NSUInteger)unreadMessagesCount {
    __block NSUInteger numberOfItems;
    [self.dbConnection readWithBlock:^(YapDatabaseReadTransaction *transaction) {
        numberOfItems = [[transaction ext:TSUnreadDatabaseViewExtensionName] numberOfItemsInAllGroups];
    }];
    
    return numberOfItems;
}

- (NSUInteger)unreadMessagesCountExcept:(TSThread *)thread {
    __block NSUInteger numberOfItems;
    [self.dbConnection readWithBlock:^(YapDatabaseReadTransaction *transaction) {
        numberOfItems = [[transaction ext:TSUnreadDatabaseViewExtensionName] numberOfItemsInAllGroups];
        numberOfItems =
        numberOfItems - [[transaction ext:TSUnreadDatabaseViewExtensionName] numberOfItemsInGroup:thread.uniqueId];
    }];
    
    return numberOfItems;
}

- (NSUInteger)unreadMessagesInThread:(TSThread *)thread {
    __block NSUInteger numberOfItems;
    [self.dbConnection readWithBlock:^(YapDatabaseReadTransaction *transaction) {
        numberOfItems = [[transaction ext:TSUnreadDatabaseViewExtensionName] numberOfItemsInGroup:thread.uniqueId];
    }];
    return numberOfItems;
}

#pragma mark - message handlers by type
-(TSIncomingMessage *)handleConversationThreadContentMessageWithEnvelope:(OWSSignalServiceProtosEnvelope *)envelope
                                                         withDataMessage:(OWSSignalServiceProtosDataMessage *)dataMessage
                                                           attachmentIds:(NSArray<NSString *> *)attachmentIds
{
    NSArray *jsonArray = [self arrayFromMessageBody:dataMessage.body];
    __block NSDictionary *jsonPayload = [jsonArray lastObject];
    __block TSIncomingMessage *incomingMessage = nil;
    __block TSThread *thread = nil;
    
    [self.dbConnection readWriteWithBlock:^(YapDatabaseReadWriteTransaction *transaction) {
        thread = [TSThread threadWithPayload:jsonPayload transaction:transaction];
        
        // Check to see if we already have this message
        incomingMessage = [TSIncomingMessage fetchObjectWithUniqueID:[jsonPayload objectForKey:@"messageId"] transaction:transaction];
        
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
        [incomingMessage saveWithTransaction:transaction];
        
        // Android allows attachments to be sent with body.
        if ([attachmentIds count] > 0 && incomingMessage.plainTextBody.length > 0) {
            // We want the text to be displayed under the attachment
            uint64_t textMessageTimestamp = envelope.timestamp + 1;
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
            uint64_t textMessageTimestamp = envelope.timestamp + 1;
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
        return incomingMessage;
    } else {
        DDLogDebug(@"Unable to process incoming message.");
        return nil;
    }
}

-(void)handleThreadDeleteControlMessageWithEnvelope:(OWSSignalServiceProtosEnvelope *)envelope
                                    withDataMessage:(OWSSignalServiceProtosDataMessage *)dataMessage
                                      attachmentIds:(NSArray<NSString *> *)attachmentIds
{
    DDLogDebug(@"Received unhandled threadDelete control message.");
    // Remove the sender from the thread
//    [self.dbConnection asyncReadWriteWithBlock:^(YapDatabaseReadWriteTransaction * _Nonnull transaction) {
//
//        SignalRecipient *sender = [SignalRecipient recipientWithTextSecureIdentifier:envelope.source withTransaction:transaction];
//        if (sender) {
//            TSThread *thread = [TSThread fetchObjectWithUniqueID:[self threadIDFromDataMessage:dataMessage] transaction:transaction];
//            if (thread) {
//                if (sender.flTag.uniqueId) {
//                    [thread removeParticipants:[NSSet setWithObject:sender.flTag.uniqueId] transaction:transaction];
//                    TSInfoMessage *infoMessage = [[TSInfoMessage alloc] initWithTimestamp:envelope.timestamp
//                                                                                 inThread:thread
//                                                                              messageType:TSInfoMessageTypeConversationUpdate
//                                                                            customMessage:[NSString stringWithFormat:NSLocalizedString(@"GROUP_MEMBER_LEFT", @""), sender.fullName]];
//                    [infoMessage saveWithTransaction:transaction];
//                }
//            }
//        }
//    }];
}
    

-(void)handleThreadUpdateControlMessageWithEnvelope:(OWSSignalServiceProtosEnvelope *)envelope
                                    withDataMessage:(OWSSignalServiceProtosDataMessage *)dataMessage
                                      attachmentIds:(NSArray<NSString *> *)attachmentIds
{
    NSArray *jsonArray = [self arrayFromMessageBody:dataMessage.body];
    NSDictionary *jsonPayload;
    if (jsonArray.count > 0) {
        jsonPayload = [jsonArray lastObject];
    }
    NSDictionary *dataBlob = [jsonPayload objectForKey:@"data"];
    __block NSDictionary *threadUpdates = [dataBlob objectForKey:@"threadUpdates"];

    NSString *threadID = [threadUpdates objectForKey:@"threadId"];
    if (threadID.length == 0) {
        threadID = [jsonPayload objectForKey:@"threadId"];
    }
    __block TSThread *thread = [TSThread getOrCreateThreadWithID:threadID];
    __block SignalRecipient *sender = [SignalRecipient recipientWithTextSecureIdentifier:envelope.source];
    [sender save];

    [self.dbConnection readWriteWithBlock:^(YapDatabaseReadWriteTransaction *transaction) {
        
        // Handle thread name change.
        NSString *threadTitle = [threadUpdates objectForKey:@"threadTitle"];
        if (![thread.name isEqualToString:threadTitle]) {
            thread.name = threadTitle;
            NSString *customMessage = nil;
            TSInfoMessage *infoMessage = nil;
            if (sender) {
                NSString *messageFormat = NSLocalizedString(@"THREAD_TITLE_UPDATE_MESSAGE", @"Thread title update message");
                customMessage = [NSString stringWithFormat:messageFormat, sender.fullName];
                
                infoMessage = [[TSInfoMessage alloc] initWithTimestamp:envelope.timestamp
                                                              inThread:thread
                                                           messageType:TSInfoMessageTypeConversationUpdate
                                                         customMessage:customMessage];
            } else {
                infoMessage = [[TSInfoMessage alloc] initWithTimestamp:envelope.timestamp
                                                              inThread:thread
                                                           messageType:TSInfoMessageTypeConversationUpdate];
            }
            [infoMessage saveWithTransaction:transaction];
        }
        
        // Handle change to participants
        NSString *expression = [threadUpdates objectForKey:@"expression"];
        if (![thread.universalExpression isEqualToString:expression]) {
            NSDictionary *lookupResults = [FLTagMathService syncTagLookupWithString:expression];
            if (lookupResults) {
                NSCountedSet *newParticipants = [[NSCountedSet setWithArray:[lookupResults objectForKey:@"userids"]] copy];
                NSCountedSet *leaving = [[NSCountedSet setWithArray:thread.participants] copy];
                [leaving minusSet:newParticipants];
                for (NSString *uid in leaving) {
                    NSString *customMessage = nil;
                    SignalRecipient *recipient = [SignalRecipient recipientWithTextSecureIdentifier:uid];
                    [recipient saveWithTransaction:transaction];
                    
                    if ([recipient isEqual:TSAccountManager.sharedInstance.myself]) {
                        customMessage = NSLocalizedString(@"GROUP_YOU_LEFT", nil);
                    } else {
                        NSString *messageFormat = NSLocalizedString(@"GROUP_MEMBER_LEFT", nil);
                        customMessage = [NSString stringWithFormat:messageFormat, recipient.fullName];
                    }
                    TSInfoMessage *infoMessage = [[TSInfoMessage alloc] initWithTimestamp:[NSDate ows_millisecondTimeStamp]
                                                                                 inThread:thread
                                                                              messageType:TSInfoMessageTypeConversationUpdate
                                                                            customMessage:customMessage];
                    [infoMessage saveWithTransaction:transaction];
                }
                
                NSCountedSet *joining = [newParticipants copy];
                [joining minusSet:[NSCountedSet setWithArray:thread.participants]];
                for (NSString *uid in joining) {
                    NSString *customMessage = nil;
                    SignalRecipient *recipient = [SignalRecipient recipientWithTextSecureIdentifier:uid];
                    [recipient saveWithTransaction:transaction];

                    if ([recipient isEqual:TSAccountManager.sharedInstance.myself]) {
                        customMessage = NSLocalizedString(@"GROUP_YOU_JOINED", nil);
                    } else {
                        NSString *messageFormat = NSLocalizedString(@"GROUP_MEMBER_JOINED", nil);
                        customMessage = [NSString stringWithFormat:messageFormat, recipient.fullName];
                    }
                    
                    TSInfoMessage *infoMessage = [[TSInfoMessage alloc] initWithTimestamp:[NSDate ows_millisecondTimeStamp]
                                                                                 inThread:thread
                                                                              messageType:TSInfoMessageTypeConversationUpdate
                                                                            customMessage:customMessage];
                    [infoMessage saveWithTransaction:transaction];
                }
             
                // Update the local thread with the changes.
                thread.participants = [lookupResults objectForKey:@"userids"];
                thread.prettyExpression = [lookupResults objectForKey:@"pretty"];
                thread.universalExpression = [lookupResults objectForKey:@"universal"];
            }
        }
        [thread saveWithTransaction:transaction];
    }];
    
    // Handle change to avatar
    //  Must be done outside the transaction block
    if (dataMessage.attachments.count > 0) {
        OWSAttachmentsProcessor *attachmentsProcessor = [[OWSAttachmentsProcessor alloc] initWithAttachmentProtos:dataMessage.attachments
                                                                                                       properties:[dataBlob objectForKey:@"attachments"]
                                                                                                        timestamp:envelope.timestamp
                                                                                                            relay:envelope.relay
                                                                                                           thread:thread
                                                                                                   networkManager:self.networkManager];
        
        if (attachmentsProcessor.hasSupportedAttachments) {
            [attachmentsProcessor fetchAttachmentsForMessage:nil
                                                     success:^(TSAttachmentStream *_Nonnull attachmentStream) {
                                                         [thread updateImageWithAttachmentStream:attachmentStream];
                                                         
                                                         NSString *messageFormat = NSLocalizedString(@"THREAD_IMAGE_CHANGED_MESSAGE", nil);
                                                         NSString *customMessage = nil;
                                                         if ([sender.uniqueId isEqual:TSAccountManager.sharedInstance.myself]) {
                                                             customMessage = [NSString stringWithFormat:messageFormat, NSLocalizedString(@"YOU_STRING", nil)];
                                                         } else {
                                                             customMessage = [NSString stringWithFormat:messageFormat, sender.fullName];
                                                         }
                                                         
                                                         TSInfoMessage *infoMessage = [[TSInfoMessage alloc] initWithTimestamp:[NSDate ows_millisecondTimeStamp]
                                                                                                                      inThread:thread
                                                                                                                   messageType:TSInfoMessageTypeConversationUpdate
                                                                                                                 customMessage:customMessage];
                                                         [infoMessage save];
                                                     }
                                                     failure:^(NSError *_Nonnull error) {
                                                         DDLogError(@"%@ failed to fetch attachments for group avatar sent at: %llu. with error: %@",
                                                                    self.tag,
                                                                    envelope.timestamp,
                                                                    error);
                                                     }];
        }
    }
}

#pragma mark - JSON body parsing methods
-(NSString *)threadIDFromDataMessage:(OWSSignalServiceProtosDataMessage *)dataMessage
{
    NSArray *tmpArray = [self arrayFromMessageBody:dataMessage.body];
    if (tmpArray.count == 0) {
        return nil;
    } else {
        NSDictionary *tmpDict = [tmpArray lastObject];
        return [tmpDict objectForKey:@"threadId"];
    }
}

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
