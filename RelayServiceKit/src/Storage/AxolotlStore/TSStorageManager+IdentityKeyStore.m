//  Created by Frederic Jacobs on 06/11/14.
//  Copyright (c) 2014 Open Whisper Systems. All rights reserved.

#import "NSDate+millisecondTimeStamp.h"
#import "TSAccountManager.h"
#import "TSThread.h"
#import "TSErrorMessage.h"
#import "TSPrivacyPreferences.h"
#import "TSStorageManager+IdentityKeyStore.h"
#import <25519/Curve25519.h>

#define TSStorageManagerIdentityKeyStoreIdentityKey \
    @"TSStorageManagerIdentityKeyStoreIdentityKey" // Key for our identity key
#define TSStorageManagerIdentityKeyStoreCollection @"TSStorageManagerIdentityKeyStoreCollection"
#define TSStorageManagerTrustedKeysCollection @"TSStorageManagerTrustedKeysCollection"


@implementation TSStorageManager (IdentityKeyStore)

- (void)generateNewIdentityKey {
    [self setObject:[Curve25519 generateKeyPair]
              forKey:TSStorageManagerIdentityKeyStoreIdentityKey
        inCollection:TSStorageManagerIdentityKeyStoreCollection];
}


- (NSData *)identityKeyForRecipientId:(NSString *)recipientId {
    return [self dataForKey:recipientId inCollection:TSStorageManagerTrustedKeysCollection];
}


- (ECKeyPair *)identityKeyPair {
    return [self keyPairForKey:TSStorageManagerIdentityKeyStoreIdentityKey
                  inCollection:TSStorageManagerIdentityKeyStoreCollection];
}

-(void)setIdentityKey:(ECKeyPair *)identityKeyPair
{
    [self setObject:identityKeyPair
             forKey:TSStorageManagerIdentityKeyStoreIdentityKey
       inCollection:TSStorageManagerIdentityKeyStoreCollection];
}

- (int)localRegistrationId {
    return (int)[TSAccountManager getOrGenerateRegistrationId];
}

- (void)saveRemoteIdentity:(NSData *)identityKey recipientId:(NSString *)recipientId {
    [self setObject:identityKey forKey:recipientId inCollection:TSStorageManagerTrustedKeysCollection];
}

- (BOOL)isTrustedIdentityKey:(NSData *)identityKey recipientId:(NSString *)recipientId {
    NSData *existingKey = [self dataForKey:recipientId inCollection:TSStorageManagerTrustedKeysCollection];

    if (!existingKey) {
        return YES;
    }

    if ([existingKey isEqualToData:identityKey]) {
        return YES;
    }

    if (self.privacyPreferences.shouldBlockOnIdentityChange) {
        return NO;
    }

    DDLogInfo(@"Updating identity key for recipient:%@", recipientId);
//    [self createIdentityChangeInfoMessageForRecipientId:recipientId];
    [self saveRemoteIdentity:identityKey recipientId:recipientId];
    return YES;
}

- (void)removeIdentityKeyForRecipient:(NSString *)receipientId {
    [self removeObjectForKey:receipientId inCollection:TSStorageManagerTrustedKeysCollection];
}

- (void)createIdentityChangeInfoMessageForRecipientId:(NSString *)recipientId
{
    __block TSThread *thread = nil;
    __block NSCountedSet *testSet = [NSCountedSet setWithObjects:recipientId, [TSAccountManager localNumber], nil];
    [self.newDatabaseConnection asyncReadWriteWithBlock:^(YapDatabaseReadWriteTransaction *transaction) {
        [transaction enumerateKeysAndObjectsInCollection:[TSThread collection] usingBlock:^(NSString *key, TSThread *aThread, BOOL *stop) {
            NSCountedSet *threadSet = [NSCountedSet setWithArray:aThread.participants];
            if ([threadSet isEqual:testSet]) {
                thread = aThread;
                *stop = YES;
            }
        }];
        if (thread == nil) {
            thread = [TSThread getOrCreateThreadWithID:[[NSUUID UUID] UUIDString]];
            thread.participants = [NSArray arrayWithArray:[testSet allObjects]];
            [thread saveWithTransaction:transaction];
        }
        [[[TSErrorMessage alloc] initWithTimestamp:[NSDate ows_millisecondTimeStamp]
                                          inThread:thread
                                 failedMessageType:TSErrorMessageNonBlockingIdentityChange] saveWithTransaction:transaction];
    }];
    
//    TSContactThread *contactThread = [TSContactThread getOrCreateThreadWithContactId:recipientId];
//    [[[TSErrorMessage alloc] initWithTimestamp:[NSDate ows_millisecondTimeStamp]
//                                      inThread:contactThread
//                             failedMessageType:TSErrorMessageNonBlockingIdentityChange] save];
}

@end
