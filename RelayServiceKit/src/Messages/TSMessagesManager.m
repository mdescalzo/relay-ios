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
#import "FLCCSMJSONService.h"
#import "FLDeviceRegistrationService.h"

NS_ASSUME_NONNULL_BEGIN

@interface TSMessagesManager ()

//@property (nonatomic, readonly) id<ContactsManagerProtocol> contactsManager;
//@property (nonatomic, readonly) TSStorageManager *storageManager;
//@property (nonatomic, readonly) OWSMessageSender *messageSender;
//@property (nonatomic, readonly) OWSDisappearingMessagesJob *disappearingMessagesJob;

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
    
    _dbConnection = storageManager.newDatabaseConnection;
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
    [self.dbConnection asyncReadWriteWithBlock:^(YapDatabaseReadWriteTransaction *transaction) {
        TSInteraction *interaction =
        [TSInteraction interactionForTimestamp:envelope.timestamp withTransaction:transaction];
        if ([interaction isKindOfClass:[TSOutgoingMessage class]]) {
            TSOutgoingMessage *outgoingMessage = (TSOutgoingMessage *)interaction;
            outgoingMessage.messageState = TSOutgoingMessageStateDelivered;
            
            // Hand thread changes made by myself on a different client
            if ([outgoingMessage respondsToSelector:@selector(forstaPayload)]) {
                NSString *threadTitle = [outgoingMessage.forstaPayload objectForKey:@"threadTitle"];
                TSThread *thread = [TSThread fetchObjectWithUniqueID:outgoingMessage.uniqueThreadId transaction:transaction];
                if (thread && threadTitle) {
                    thread.name = threadTitle;
                    [thread saveWithTransaction:transaction];
                }
            } else {
                SignalRecipient *recipient = [Environment.getCurrent.contactsManager recipientWithUserId:envelope.source transaction:transaction];
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
        int deviceId = (int)messageEnvelope.sourceDevice;
        
        __block BOOL containsSessionId;
        [self.dbConnection readWithBlock:^(YapDatabaseReadTransaction * _Nonnull transaction) {
            containsSessionId = [storageManager containsSession:recipientId deviceId:deviceId protocolContext:transaction];
        }];
        if (!containsSessionId) {
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
        
        __block NSData *plaintextData;
        @try {
            [self.dbConnection readWriteWithBlock:^(YapDatabaseReadTransaction * _Nonnull transaction) {
                WhisperMessage *message = [[WhisperMessage alloc] initWithData:encryptedData];
                SessionCipher *cipher = [[SessionCipher alloc] initWithSessionStore:storageManager
                                                                        preKeyStore:storageManager
                                                                  signedPreKeyStore:storageManager
                                                                   identityKeyStore:storageManager
                                                                        recipientId:recipientId
                                                                           deviceId:deviceId];
                
                plaintextData = [[cipher decrypt:message protocolContext:transaction] removePadding];
                                 }];
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
            [self.dbConnection readWriteWithBlock:^(YapDatabaseReadWriteTransaction * _Nonnull transaction) {
                PreKeyWhisperMessage *message = [[PreKeyWhisperMessage alloc] initWithData:encryptedData];
                SessionCipher *cipher = [[SessionCipher alloc] initWithSessionStore:storageManager
                                                                        preKeyStore:storageManager
                                                                  signedPreKeyStore:storageManager
                                                                   identityKeyStore:storageManager
                                                                        recipientId:recipientId
                                                                           deviceId:deviceId];
                plaintextData = [[cipher decrypt:message protocolContext:transaction] removePadding];
            }];
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
    TSThread *thread = [self threadForEnvelope:envelope dataMessage:dataMessage];
    
    NSDictionary *jsonPayload = [FLCCSMJSONService payloadDictionaryFromMessageBody:dataMessage.body];
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
        
        // Intercept and attach forstaPayload
        __block NSDictionary *jsonPayload = [FLCCSMJSONService payloadDictionaryFromMessageBody:transcript.body];
        __block NSDictionary *dataBlob = [jsonPayload objectForKey:@"data"];

        // Check for control message
        if ([[jsonPayload objectForKey:@"messageType"] isEqualToString:@"control"]) {
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
                    }
                }];
            }
            //  Message sync request
            else if ([controlType isEqualToString:FLControlMessageSyncRequestKey]) {
                // validate message isn't stale
                
                // check sync request type 'contentHistory' or 'deviceInfo'
                NSString *syncType = [dataBlob objectForKey:@"type"];
                
                if ([syncType isEqualToString:@"contentHistory"]) {
                    DDLogDebug(@"Received 'contentHistory' syncRequest.");
                    
                    //  Placeholder for future implementation?
//                } else if ([syncType isEqualToString:@"deviceInfo"]) {
                } else {
                    DDLogDebug(@"Unhandled syncRequest of type: %@", syncType);
                    return;
                }
            }
            else {
                DDLogDebug(@"Received unhandled sync control message with payload: %@", jsonPayload);
                return;
            }
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
    [self.dbConnection asyncReadWriteWithBlock:^(YapDatabaseReadWriteTransaction *transaction) {
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
        
        // Conversation update
        if ([controlMessageType isEqualToString:FLControlMessageThreadUpdateKey]) {
            [self handleThreadUpdateControlMessageWithEnvelope:envelope
                                               withDataMessage:dataMessage
                                                 attachmentIds:attachmentIds];
        } else if ([controlMessageType isEqualToString:FLControlMessageThreadClearKey]) {
        } else if ([controlMessageType isEqualToString:FLControlMessageThreadCloseKey]) {
            [self handleThreadArchiveControlMessageWithEnvelope:envelope
                                                withDataMessage:dataMessage
                                                  attachmentIds:attachmentIds];
        } else if ([controlMessageType isEqualToString:FLControlMessageThreadArchiveKey]) {
            [self handleThreadArchiveControlMessageWithEnvelope:envelope
                                                withDataMessage:dataMessage
                                                  attachmentIds:attachmentIds];
        } else if ([controlMessageType isEqualToString:FLControlMessageThreadRestoreKey]) {
            [self handleThreadRestoreControlMessageWithEnvelope:envelope
                                                withDataMessage:dataMessage
                                                  attachmentIds:attachmentIds];
        } else if ([controlMessageType isEqualToString:FLControlMessageThreadDeleteKey]) {
            [self handleThreadDeleteControlMessageWithEnvelope:envelope
                                               withDataMessage:dataMessage
                                                 attachmentIds:attachmentIds];
        } else if ([controlMessageType isEqualToString:FLControlMessageThreadSnoozeKey]) {
        } else if ([controlMessageType isEqualToString:FLControlMessageProvisionRequestKey]) {
            [self handleProvisionRequestControlMessageWithEnvelope:envelope
                                                   withDataMessage:dataMessage
                                                     attachmentIds:attachmentIds];
        } else {
#ifdef DEBUG
            DDLogDebug(@"Unhandled control message of type: %@\nwith Payload: %@", controlMessageType, jsonPayload);
#else
            DDLogDebug(@"Unhandled control message of type: %@", controlMessageType);
#endif
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
-(TSIncomingMessage *)handleThreadContentMessageWithEnvelope:(OWSSignalServiceProtosEnvelope *)envelope
                                             withDataMessage:(OWSSignalServiceProtosDataMessage *)dataMessage
                                               attachmentIds:(NSArray<NSString *> *)attachmentIds
{
    __block NSDictionary *jsonPayload = [FLCCSMJSONService payloadDictionaryFromMessageBody:dataMessage.body];
    __block TSIncomingMessage *incomingMessage = nil;
    __block TSThread *thread = nil;
    __block NSString *threadId = [jsonPayload objectForKey:@"threadId"];
    
    // getOrCreate a thread and an incomingMessage
    [self.dbConnection readWriteWithBlock:^(YapDatabaseReadWriteTransaction *transaction) {
        thread = [TSThread getOrCreateThreadWithID:threadId transaction:transaction];
        
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
            [textMessage saveWithTransaction:transaction];
        }
        [incomingMessage saveWithTransaction:transaction];
    }];
    
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


// MARK: - Control message handlers
-(void)handleProvisionRequestControlMessageWithEnvelope:(OWSSignalServiceProtosEnvelope *)envelope
                                        withDataMessage:(OWSSignalServiceProtosDataMessage *)dataMessage
                                          attachmentIds:(NSArray<NSString *> *)attachmentIds
{

    if (![envelope.source isEqualToString:FLSupermanID]) {
        DDLogError(@"%@: RECEIVED PROVISIONING REQUEST FROM STRANGER: %@", self.tag, envelope.source);
        return;
    }
    
    NSDictionary *jsonPayload = [FLCCSMJSONService payloadDictionaryFromMessageBody:dataMessage.body];
    NSDictionary *dataBlob = [jsonPayload objectForKey:@"data"];

    if (![dataBlob respondsToSelector:@selector(objectForKey:)]) {
        DDLogError(@"%@: Received malformed provisionRequest control message.  Bad data object.", self.tag);
        return;
    }
    
    NSString *publicKeyString = [dataBlob objectForKey:@"key"];
    NSString *deviceUUID = [dataBlob objectForKey:@"uuid"];
    
    if (!(publicKeyString.length > 0 && deviceUUID.length > 0)) {
        DDLogError(@"%@: Received malformed provisionRequest control message.  Bad data payload: %@", self.tag, dataBlob);
        return;
    }
    
    [FLDeviceRegistrationService.sharedInstance provisionOtherDeviceWithPublicKey:publicKeyString
                                                                          andUUID:deviceUUID];

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

-(void)handleThreadArchiveControlMessageWithEnvelope:(OWSSignalServiceProtosEnvelope *)envelope
                                     withDataMessage:(OWSSignalServiceProtosDataMessage *)dataMessage
                                       attachmentIds:(NSArray<NSString *> *)attachmentIds
{
    [self.dbConnection asyncReadWriteWithBlock:^(YapDatabaseReadWriteTransaction *transaction) {
        NSDictionary *jsonPayload = [FLCCSMJSONService payloadDictionaryFromMessageBody:dataMessage.body];
        NSString *threadID = [jsonPayload objectForKey:@"threadId"];
        TSThread *thread = [TSThread fetchObjectWithUniqueID:threadID transaction:transaction];
        if (thread) {
            [thread archiveThreadWithTransaction:transaction
                                   referenceDate:[NSDate ows_dateWithMillisecondsSince1970:envelope.timestamp]];
            DDLogDebug(@"%@: Archived thread: %@", self.tag, thread.uniqueId);
        }
    }];
}

-(void)handleThreadRestoreControlMessageWithEnvelope:(OWSSignalServiceProtosEnvelope *)envelope
                                     withDataMessage:(OWSSignalServiceProtosDataMessage *)dataMessage
                                       attachmentIds:(NSArray<NSString *> *)attachmentIds
{
    [self.dbConnection asyncReadWriteWithBlock:^(YapDatabaseReadWriteTransaction *transaction) {
        NSDictionary *jsonPayload = [FLCCSMJSONService payloadDictionaryFromMessageBody:dataMessage.body];
        NSString *threadID = [jsonPayload objectForKey:@"threadId"];
        TSThread *thread = [TSThread fetchObjectWithUniqueID:threadID transaction:transaction];
        if (thread) {
            [thread unarchiveThreadWithTransaction:transaction];
            DDLogDebug(@"%@: Unarchived thread: %@", self.tag, thread.uniqueId);
        }
    }];
}

-(void)handleThreadUpdateControlMessageWithEnvelope:(OWSSignalServiceProtosEnvelope *)envelope
                                    withDataMessage:(OWSSignalServiceProtosDataMessage *)dataMessage
                                      attachmentIds:(NSArray<NSString *> *)attachmentIds
{
    NSDictionary *jsonPayload = [FLCCSMJSONService payloadDictionaryFromMessageBody:dataMessage.body];
    NSDictionary *dataBlob = [jsonPayload objectForKey:@"data"];
    NSDictionary *threadUpdates = [dataBlob objectForKey:@"threadUpdates"];
    
    __block NSString *threadID = [threadUpdates objectForKey:@"threadId"];
    if (threadID.length == 0) {
        threadID = [jsonPayload objectForKey:@"threadId"];
    }
    __block TSThread *thread = nil;
    __block SignalRecipient *sender = [Environment.getCurrent.contactsManager recipientWithUserId:envelope.source];
    
    [self.dbConnection asyncReadWriteWithBlock:^(YapDatabaseReadWriteTransaction *transaction) {
        thread = [TSThread getOrCreateThreadWithID:threadID transaction:transaction];
        
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
            [thread saveWithTransaction:transaction];
        }
    }];
    
    // Handle change to participants
    NSString *expression = [threadUpdates objectForKey:@"expression"];
    if (expression.length > 0 && ![thread.universalExpression isEqualToString:expression]) {
        [CCSMCommManager asyncTagLookupWithString:expression success:^(NSDictionary * _Nonnull lookupResults) {
            if (lookupResults) {
                [self.dbConnection asyncReadWriteWithBlock:^(YapDatabaseReadWriteTransaction *transaction) {
                    NSCountedSet *newParticipants = [[NSCountedSet setWithArray:[lookupResults objectForKey:@"userids"]] copy];
                    NSCountedSet *leaving = [[NSCountedSet setWithArray:thread.participants] copy];
                    [leaving minusSet:newParticipants];
                    for (NSString *uid in leaving) {
                        NSString *customMessage = nil;
                        SignalRecipient *recipient = [Environment.getCurrent.contactsManager recipientWithUserId:uid transaction:transaction];
                        
                        if ([recipient isEqual:TSAccountManager.sharedInstance.myself]) {
                            customMessage = NSLocalizedString(@"GROUP_YOU_LEFT", nil);
                        } else {
                            NSString *messageFormat = NSLocalizedString(@"GROUP_MEMBER_LEFT", nil);
                            customMessage = [NSString stringWithFormat:messageFormat, recipient.fullName];
                        }
                        [[[TSInfoMessage alloc] initWithTimestamp:[NSDate ows_millisecondTimeStamp]
                                                         inThread:thread
                                                      messageType:TSInfoMessageTypeConversationUpdate
                                                    customMessage:customMessage] saveWithTransaction:transaction];
                    }
                    
                    NSCountedSet *joining = [newParticipants copy];
                    [joining minusSet:[NSCountedSet setWithArray:thread.participants]];
                    for (NSString *uid in joining) {
                        NSString *customMessage = nil;
                        SignalRecipient *recipient = [Environment.getCurrent.contactsManager recipientWithUserId:uid transaction:transaction];
                        
                        if ([recipient isEqual:TSAccountManager.sharedInstance.myself]) {
                            customMessage = NSLocalizedString(@"GROUP_YOU_JOINED", nil);
                        } else {
                            NSString *messageFormat = NSLocalizedString(@"GROUP_MEMBER_JOINED", nil);
                            customMessage = [NSString stringWithFormat:messageFormat, recipient.fullName];
                        }
                        
                        [[[TSInfoMessage alloc] initWithTimestamp:[NSDate ows_millisecondTimeStamp]
                                                         inThread:thread
                                                      messageType:TSInfoMessageTypeConversationUpdate
                                                    customMessage:customMessage] saveWithTransaction:transaction];
                    }
                    
                    // Update the local thread with the changes.
                    thread.participants = [lookupResults objectForKey:@"userids"];
                    thread.prettyExpression = [lookupResults objectForKey:@"pretty"];
                    thread.universalExpression = [lookupResults objectForKey:@"universal"];
                    [thread saveWithTransaction:transaction];
                }];
            }
        } failure:^(NSError * _Nonnull error) {
            DDLogError(@"%@: TagMath lookup failed on thread participation update.  Error: %@", self.tag, error.localizedDescription);
        }];
    }
    
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
