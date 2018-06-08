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

-(void)generateNewIdentityKeyWithProtocolContext:(id)protocolContext
{
    [self setObject:[Curve25519 generateKeyPair]
             forKey:TSStorageManagerIdentityKeyStoreIdentityKey
       inCollection:TSStorageManagerIdentityKeyStoreCollection
withProtocolContext:protocolContext];
}

-(NSData *)identityKeyForRecipientId:(NSString *)recipientId withProtocolContext:(id)protocolContext
{
    return [self dataForKey:recipientId inCollection:TSStorageManagerTrustedKeysCollection withProtocolContext:protocolContext];
}

-(ECKeyPair *)identityKeyPair:(id)protocolContext
{
    return [self keyPairForKey:TSStorageManagerIdentityKeyStoreIdentityKey
                  inCollection:TSStorageManagerIdentityKeyStoreCollection
               withProtocolContext:protocolContext];
}

-(void)setIdentityKey:(ECKeyPair *)identityKeyPair withProtocolContext:(id)protocolContext
{
    [self setObject:identityKeyPair
             forKey:TSStorageManagerIdentityKeyStoreIdentityKey
       inCollection:TSStorageManagerIdentityKeyStoreCollection
withProtocolContext:protocolContext];
}


- (int)localRegistrationId:(nullable id)protocolContext {
    return (int)[TSAccountManager getOrGenerateRegistrationIdWithProtocolContext:protocolContext];
}

- (void)saveRemoteIdentity:(NSData *)identityKey recipientId:(NSString *)recipientId withProtocolContext:(nullable id)protocolContext
{
    [self setObject:identityKey forKey:recipientId inCollection:TSStorageManagerTrustedKeysCollection withProtocolContext:protocolContext];
}

- (BOOL)saveRemoteIdentity:(nonnull NSData *)identityKey recipientId:(nonnull NSString *)recipientId protocolContext:(nullable id)protocolContext
{
    NSData *tmp = [self objectForKey:recipientId inCollection:TSStorageManagerTrustedKeysCollection withProtocolContext:protocolContext];
    
    [self setObject:identityKey forKey:recipientId inCollection:TSStorageManagerTrustedKeysCollection withProtocolContext:protocolContext];
    
    if (tmp) {
        return YES;
    } else {
        return NO;
    }
}


- (BOOL)isTrustedIdentityKey:(NSData *)identityKey recipientId:(NSString *)recipientId withProtocolContext:(nullable id)protocolContext
{
    NSData *existingKey = [self dataForKey:recipientId inCollection:TSStorageManagerTrustedKeysCollection withProtocolContext:protocolContext];

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
    [self saveRemoteIdentity:identityKey recipientId:recipientId withProtocolContext:protocolContext];
    return YES;
}

- (BOOL)isTrustedIdentityKey:(nonnull NSData *)identityKey
                 recipientId:(nonnull NSString *)recipientId
                   direction:(TSMessageDirection)direction
             protocolContext:(nullable id)protocolContext
{
    NSData *existingKey = [self dataForKey:recipientId inCollection:TSStorageManagerTrustedKeysCollection withProtocolContext:protocolContext];
    
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
        [self saveRemoteIdentity:identityKey recipientId:recipientId withProtocolContext:protocolContext];

    return YES;
}

- (void)removeIdentityKeyForRecipient:(NSString *)receipientId withProtocolContext:(nullable id)protocolContext {
    [self removeObjectForKey:receipientId inCollection:TSStorageManagerTrustedKeysCollection withProtocolContext:protocolContext];
}

// TODO: Refactor for protocolContext before reviving this method
//- (void)createIdentityChangeInfoMessageForRecipientId:(NSString *)recipientId
//{
//    __block TSThread *thread = nil;
//    __block NSCountedSet *testSet = [NSCountedSet setWithObjects:recipientId, [TSAccountManager localNumber], nil];
//    [self.newDatabaseConnection asyncReadWriteWithBlock:^(YapDatabaseReadWriteTransaction *transaction) {
//        [transaction enumerateKeysAndObjectsInCollection:[TSThread collection] usingBlock:^(NSString *key, TSThread *aThread, BOOL *stop) {
//            NSCountedSet *threadSet = [NSCountedSet setWithArray:aThread.participants];
//            if ([threadSet isEqual:testSet]) {
//                thread = aThread;
//                *stop = YES;
//            }
//        }];
//        if (thread == nil) {
//            thread = [TSThread getOrCreateThreadWithID:[[NSUUID UUID] UUIDString]];
//            thread.participants = [NSArray arrayWithArray:[testSet allObjects]];
//            [thread saveWithTransaction:transaction];
//        }
//        [[[TSErrorMessage alloc] initWithTimestamp:[NSDate ows_millisecondTimeStamp]
//                                          inThread:thread
//                                 failedMessageType:TSErrorMessageNonBlockingIdentityChange] saveWithTransaction:transaction];
//    }];
//}

@end
