//  Created by Frederic Jacobs on 06/11/14.
//  Copyright (c) 2014 Open Whisper Systems. All rights reserved.

#import "NSDate+millisecondTimeStamp.h"
#import "TSAccountManager.h"
#import "TSThread.h"
#import "TSErrorMessage.h"
#import "TSPrivacyPreferences.h"
#import "TSStorageManager+IdentityKeyStore.h"
#import <Curve25519Kit/Curve25519.h>

#define TSStorageManagerIdentityKeyStoreIdentityKey \
    @"TSStorageManagerIdentityKeyStoreIdentityKey" // Key for our identity key
#define TSStorageManagerIdentityKeyStoreCollection @"TSStorageManagerIdentityKeyStoreCollection"
#define TSStorageManagerTrustedKeysCollection @"TSStorageManagerTrustedKeysCollection"


@implementation TSStorageManager (IdentityKeyStore)

- (void)generateNewIdentityKey {
    [self.dbConnection readWriteWithBlock:^(YapDatabaseReadWriteTransaction * _Nonnull transaction) {
        [self generateNewIdentityKeyWithTransaction:transaction];
    }];
}

-(void)generateNewIdentityKeyWithTransaction:(YapDatabaseReadWriteTransaction *)transaction {
    [self setObject:[Curve25519 generateKeyPair]
             forKey:TSStorageManagerIdentityKeyStoreIdentityKey
       inCollection:TSStorageManagerIdentityKeyStoreCollection
     withTransaction:transaction];
}


- (NSData *)identityKeyForRecipientId:(NSString *)recipientId {
    return [self dataForKey:recipientId inCollection:TSStorageManagerTrustedKeysCollection];
}


- (ECKeyPair *)identityKeyPair {
    return [self keyPairForKey:TSStorageManagerIdentityKeyStoreIdentityKey
                  inCollection:TSStorageManagerIdentityKeyStoreCollection];
}

-(ECKeyPair *)identityKeyPair:(id)protocolContext {
    NSAssert([protocolContext isKindOfClass:[YapDatabaseReadTransaction class]], @"protocolContext must be a YapDatabaseTransaction.");
    YapDatabaseReadTransaction *transaction = (YapDatabaseReadTransaction *)protocolContext;
    
    return [self keyPairForKey:TSStorageManagerIdentityKeyStoreIdentityKey
                  inCollection:TSStorageManagerIdentityKeyStoreCollection
               withTransaction:transaction];
    
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

- (int)localRegistrationId:(nullable id)protocolContext {
    NSAssert([protocolContext isKindOfClass:[YapDatabaseReadWriteTransaction class]], @"protocolContext must be a YapDatabaseReadWriteTransaction.");
    YapDatabaseReadWriteTransaction *transaction = (YapDatabaseReadWriteTransaction *)protocolContext;
    
    return (int)[TSAccountManager getOrGenerateRegistrationIdWithTransaction:transaction];
}


- (void)saveRemoteIdentity:(NSData *)identityKey recipientId:(NSString *)recipientId {
    [self setObject:identityKey forKey:recipientId inCollection:TSStorageManagerTrustedKeysCollection];
}

- (BOOL)saveRemoteIdentity:(nonnull NSData *)identityKey recipientId:(nonnull NSString *)recipientId protocolContext:(nullable id)protocolContext {
    NSAssert([protocolContext isKindOfClass:[YapDatabaseReadWriteTransaction class]], @"protocolContext must be a YapDatabaseReadWriteTransaction.");
    YapDatabaseReadWriteTransaction *transaction = (YapDatabaseReadWriteTransaction *)protocolContext;
    
    NSData *tmp = [self objectForKey:recipientId inCollection:TSStorageManagerTrustedKeysCollection withTransaction:transaction];
    
    [self setObject:identityKey forKey:recipientId inCollection:TSStorageManagerTrustedKeysCollection withTransaction:transaction];
    
    if (tmp) {
        return YES;
    } else {
        return NO;
    }
}


//- (BOOL)isTrustedIdentityKey:(NSData *)identityKey recipientId:(NSString *)recipientId {
//    NSData *existingKey = [self dataForKey:recipientId inCollection:TSStorageManagerTrustedKeysCollection];
//
//    if (!existingKey) {
//        return YES;
//    }
//
//    if ([existingKey isEqualToData:identityKey]) {
//        return YES;
//    }
//
//    if (self.privacyPreferences.shouldBlockOnIdentityChange) {
//        return NO;
//    }
//
//    DDLogInfo(@"Updating identity key for recipient:%@", recipientId);
////    [self createIdentityChangeInfoMessageForRecipientId:recipientId];
//    [self saveRemoteIdentity:identityKey recipientId:recipientId];
//    return YES;
//}

- (BOOL)isTrustedIdentityKey:(nonnull NSData *)identityKey
                 recipientId:(nonnull NSString *)recipientId
                   direction:(TSMessageDirection)direction
             protocolContext:(nullable id)protocolContext {
    
    NSAssert([protocolContext isKindOfClass:[YapDatabaseReadTransaction class]], @"protocolContext must be a YapDatabaseTransaction.");
    YapDatabaseReadTransaction *transaction = (YapDatabaseReadTransaction *)protocolContext;

    
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
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{
        DDLogInfo(@"Updating identity key for recipient:%@", recipientId);
        //    [self createIdentityChangeInfoMessageForRecipientId:recipientId];
        [self saveRemoteIdentity:identityKey recipientId:recipientId];
    });
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
