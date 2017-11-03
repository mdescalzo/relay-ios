//  Created by Frederic Jacobs on 31/12/14.
//  Copyright (c) 2014 Open Whisper Systems. All rights reserved.

#import "TSInvalidIdentityKeyReceivingErrorMessage.h"
#import "OWSFingerprint.h"
#import "TSAccountManager.h"
#import "TSThread.h"
#import "TSDatabaseView.h"
#import "TSErrorMessage_privateConstructor.h"
#import "TSMessagesManager.h"
#import "TSStorageManager+IdentityKeyStore.h"
#import "TSStorageManager.h"
#import <AxolotlKit/NSData+keyVersionByte.h>
#import <AxolotlKit/PreKeyWhisperMessage.h>
#import <YapDatabase/YapDatabaseTransaction.h>
#import <YapDatabase/YapDatabaseView.h>

NS_ASSUME_NONNULL_BEGIN

@interface TSInvalidIdentityKeyReceivingErrorMessage ()

@property (nonatomic, readonly, copy) NSString *authorId;

@end

@implementation TSInvalidIdentityKeyReceivingErrorMessage {
    // Not using a property declaration in order to exclude from DB serialization
    OWSSignalServiceProtosEnvelope *_envelope;
}

@synthesize envelopeData = _envelopeData;

+ (instancetype)untrustedKeyWithEnvelope:(OWSSignalServiceProtosEnvelope *)envelope
                         withTransaction:(YapDatabaseReadWriteTransaction *)transaction
{
    __block TSThread *thread = nil;
    __block NSCountedSet *testSet = [NSCountedSet setWithObjects:envelope.source, TSAccountManager.sharedInstance.myself.uniqueId, nil];
    [transaction enumerateKeysAndObjectsInCollection:[TSThread collection] usingBlock:^(NSString *key, TSThread *aThread, BOOL *stop) {
        NSCountedSet *threadSet = [NSCountedSet setWithArray:aThread.participants];
        if ([threadSet isEqual:testSet]) {
            thread = aThread;
            *stop = YES;
        }
    }];
    if (thread == nil) {
        thread = [TSThread getOrCreateThreadWithID:[[NSUUID UUID] UUIDString] transaction:transaction];
        thread.participants = [NSArray arrayWithArray:[testSet allObjects]];
        [thread saveWithTransaction:transaction];
    }
    
    TSInvalidIdentityKeyReceivingErrorMessage *errorMessage =
    [[self alloc] initForUnknownIdentityKeyWithTimestamp:envelope.timestamp
                                                inThread:thread
                                        incomingEnvelope:envelope];
    return errorMessage;
}

- (instancetype)initForUnknownIdentityKeyWithTimestamp:(uint64_t)timestamp
                                              inThread:(TSThread *)thread
                                      incomingEnvelope:(OWSSignalServiceProtosEnvelope *)envelope
{
    self = [self initWithTimestamp:timestamp inThread:thread failedMessageType:TSErrorMessageWrongTrustedIdentityKey];
    if (!self) {
        return self;
    }

    _envelopeData = envelope.data;
    _authorId = envelope.source;

    return self;
}

- (OWSSignalServiceProtosEnvelope *)envelope
{
    if (!_envelope) {
        _envelope = [OWSSignalServiceProtosEnvelope parseFromData:self.envelopeData];
    }
    return _envelope;
}


- (void)acceptNewIdentityKey
{
    if (self.errorType != TSErrorMessageWrongTrustedIdentityKey) {
        DDLogError(@"Refusing to accept identity key for anything but a Key error.");
        return;
    }

    NSData *newKey = [self newIdentityKey];
    if (!newKey) {
        DDLogError(@"Couldn't extract identity key to accept");
        return;
    }

    [[TSStorageManager sharedManager] saveRemoteIdentity:newKey recipientId:self.envelope.source];

    // Decrypt this and any old messages for the newly accepted key
    NSArray<TSInvalidIdentityKeyReceivingErrorMessage *> *messagesToDecrypt =
        [self.thread receivedMessagesForInvalidKey:newKey];

    for (TSInvalidIdentityKeyReceivingErrorMessage *errorMessage in messagesToDecrypt) {
        [[TSMessagesManager sharedManager] handleReceivedEnvelope:errorMessage.envelope];

        // Here we remove the existing error message because handleReceivedEnvelope will either
        //  1.) succeed and create a new successful message in the thread or...
        //  2.) fail and create a new identical error message in the thread.
        [errorMessage remove];
    }
}

- (NSData *)newIdentityKey
{
    if (!self.envelope) {
        DDLogError(@"Error message had no envelope data to extract key from");
        return nil;
    }

    if (self.envelope.type != OWSSignalServiceProtosEnvelopeTypePrekeyBundle) {
        DDLogError(@"Refusing to attempt key extraction from an envelope which isn't a prekey bundle");
        return nil;
    }

    // DEPRECATED - Remove after all clients have been upgraded.
    NSData *pkwmData = self.envelope.hasContent ? self.envelope.content : self.envelope.legacyMessage;
    if (!pkwmData) {
        DDLogError(@"Ignoring acceptNewIdentityKey for empty message");
        return nil;
    }

    PreKeyWhisperMessage *message = [[PreKeyWhisperMessage alloc] initWithData:pkwmData];
    return [message.identityKey removeKeyType];
}

- (NSString *)theirSignalId
{
    if (self.authorId) {
        return self.authorId;
    } else {
        // for existing messages before we were storing author id.
        return self.envelope.source;
    }
}

@end

NS_ASSUME_NONNULL_END
