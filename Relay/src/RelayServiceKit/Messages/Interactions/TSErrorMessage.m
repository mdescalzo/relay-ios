//
//  TSErrorMessage.m
//  TextSecureKit
//
//  Created by Frederic Jacobs on 12/11/14.
//  Copyright (c) 2014 Open Whisper Systems. All rights reserved.
//

#import "TSErrorMessage.h"
#import "TSAccountManager.h"
#import "TSThread.h"
#import "TSErrorMessage_privateConstructor.h"
#import "TSMessagesManager.h"
#import "TextSecureKitEnv.h"
#import "YapDatabase.h"

@implementation TSErrorMessage

- (instancetype)initWithCoder:(NSCoder *)coder
{
    return [super initWithCoder:coder];
}

- (instancetype)initWithTimestamp:(uint64_t)timestamp
                         inThread:(TSThread *)thread
                failedMessageType:(TSErrorMessageType)errorMessageType
{
    self = [super initWithTimestamp:timestamp
                           inThread:thread
                        messageBody:nil
                      attachmentIds:@[]
                   expiresInSeconds:0
                    expireStartedAt:0];

    if (!self) {
        return self;
    }

    _errorType = errorMessageType;

    [[TextSecureKitEnv sharedEnv].notificationsManager notifyUserForErrorMessage:self inThread:thread];

    return self;
}

- (instancetype)initWithEnvelope:(OWSSignalServiceProtosEnvelope *)envelope
                 withTransaction:(YapDatabaseReadWriteTransaction *)transaction
               failedMessageType:(TSErrorMessageType)errorMessageType
{
    __block TSThread *thread = nil;
    __block NSCountedSet *testSet = [NSCountedSet setWithObjects:envelope.source, TSAccountManager.sharedInstance.myself.uniqueId, nil];
//    [self.dbConnection readWriteWithBlock:^(YapDatabaseReadWriteTransaction *transaction) {
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
//    }];
    
//    TSContactThread *contactThread = [TSContactThread getOrCreateThreadWithContactId:envelope.source transaction:transaction];
    
    return [self initWithTimestamp:envelope.timestamp inThread:thread failedMessageType:errorMessageType];
}

- (NSString *)description {
    switch (_errorType) {
        case TSErrorMessageNoSession:
            return NSLocalizedString(@"ERROR_MESSAGE_NO_SESSION", @"");
        case TSErrorMessageInvalidMessage:
            return NSLocalizedString(@"ERROR_MESSAGE_INVALID_MESSAGE", @"");
        case TSErrorMessageInvalidVersion:
            return NSLocalizedString(@"ERROR_MESSAGE_INVALID_VERSION", @"");
        case TSErrorMessageDuplicateMessage:
            return NSLocalizedString(@"ERROR_MESSAGE_DUPLICATE_MESSAGE", @"");
        case TSErrorMessageInvalidKeyException:
            return NSLocalizedString(@"ERROR_MESSAGE_INVALID_KEY_EXCEPTION", @"");
        case TSErrorMessageWrongTrustedIdentityKey:
            return NSLocalizedString(@"ERROR_MESSAGE_WRONG_TRUSTED_IDENTITY_KEY", @"");
        case TSErrorMessageNonBlockingIdentityChange:
            return NSLocalizedString(@"ERROR_MESSAGE_NON_BLOCKING_IDENTITY_CHANGE", @"");
        default:
            return NSLocalizedString(@"ERROR_MESSAGE_UNKNOWN_ERROR", @"");
            break;
    }
}

+ (instancetype)corruptedMessageWithEnvelope:(OWSSignalServiceProtosEnvelope *)envelope
                             withTransaction:(YapDatabaseReadWriteTransaction *)transaction
{
    return [[self alloc] initWithEnvelope:envelope
                          withTransaction:transaction
                        failedMessageType:TSErrorMessageInvalidMessage];
}

+ (instancetype)invalidVersionWithEnvelope:(OWSSignalServiceProtosEnvelope *)envelope
                           withTransaction:(YapDatabaseReadWriteTransaction *)transaction
{
    return [[self alloc] initWithEnvelope:envelope
                          withTransaction:transaction
                        failedMessageType:TSErrorMessageInvalidVersion];
}

+ (instancetype)invalidKeyExceptionWithEnvelope:(OWSSignalServiceProtosEnvelope *)envelope
                                withTransaction:(YapDatabaseReadWriteTransaction *)transaction
{
    return [[self alloc] initWithEnvelope:envelope
                          withTransaction:transaction
                        failedMessageType:TSErrorMessageInvalidKeyException];
}

+ (instancetype)missingSessionWithEnvelope:(OWSSignalServiceProtosEnvelope *)envelope
                           withTransaction:(YapDatabaseReadWriteTransaction *)transaction
{
    return
        [[self alloc] initWithEnvelope:envelope withTransaction:transaction failedMessageType:TSErrorMessageNoSession];
}

@end
