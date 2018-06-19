//
//  TSStorageManager+PreKeyStore.m
//  TextSecureKit
//
//  Created by Frederic Jacobs on 06/11/14.
//  Copyright (c) 2014 Open Whisper Systems. All rights reserved.
//

#import <AxolotlKit/AxolotlExceptions.h>
#import "TSStorageManager+PreKeyStore.h"
#import "TSStorageManager+keyFromIntLong.h"

#define TSStorageManagerPreKeyStoreCollection @"TSStorageManagerPreKeyStoreCollection"
#define TSNextPrekeyIdKey @"TSStorageInternalSettingsNextPreKeyId"
#define BATCH_SIZE 100
#define MAX_VALUE_LASTRESORT 0xFFFFFF

@implementation TSStorageManager (PreKeyStore)

- (PreKeyRecord *)getOrGenerateLastResortKeyWithProtocolContext:(id)protocolContext
{
    if ([self containsPreKey:MAX_VALUE_LASTRESORT withProtocolContext:protocolContext]) {
        return [self loadPreKey:MAX_VALUE_LASTRESORT];
    } else {
        PreKeyRecord *lastResort =
        [[PreKeyRecord alloc] initWithId:MAX_VALUE_LASTRESORT keyPair:[Curve25519 generateKeyPair]];
        [self storePreKey:MAX_VALUE_LASTRESORT preKeyRecord:lastResort withProtocolContext:protocolContext];
        return lastResort;
    }
}

- (NSArray *)generatePreKeyRecordsWithProtocolContext:(id)protocolContext {
    NSMutableArray *preKeyRecords = [NSMutableArray array];

    @synchronized(self) {
        int preKeyId = [self nextPreKeyIdWithProtocolContext:protocolContext];
        for (int i = 0; i < BATCH_SIZE; i++) {
            ECKeyPair *keyPair   = [Curve25519 generateKeyPair];
            PreKeyRecord *record = [[PreKeyRecord alloc] initWithId:preKeyId keyPair:keyPair];

            [preKeyRecords addObject:record];
            preKeyId++;
        }

        [self setInt:preKeyId forKey:TSNextPrekeyIdKey inCollection:TSStorageInternalSettingsCollection withProtocolContext:protocolContext];
    }
    return preKeyRecords;
}

- (void)storePreKeyRecords:(NSArray *)preKeyRecords withProtocolContext:(nullable id)protocolContext {
    for (PreKeyRecord *record in preKeyRecords) {
        [self setObject:record forKey:[self keyFromInt:record.Id] inCollection:TSStorageManagerPreKeyStoreCollection withProtocolContext:protocolContext];
    }
}

- (int)nextPreKeyIdWithProtocolContext:(nullable id)protocolContext  {
    int lastPreKeyId = [self intForKey:TSNextPrekeyIdKey inCollection:TSStorageInternalSettingsCollection withProtocolContext:protocolContext];
    
    while (lastPreKeyId < 1 || (lastPreKeyId > (MAX_VALUE_LASTRESORT - BATCH_SIZE))) {
        lastPreKeyId = rand();
    }
    
    return lastPreKeyId;
}

// FIXME: Axolotl method
- (PreKeyRecord *)loadPreKey:(int)preKeyId {
    DDLogWarn(@"Called Axolotl method \"- (PreKeyRecord *)loadPreKey:(int)preKeyId\"");
    return  [self loadPreKey:preKeyId withProtocolContext:nil];
}

-(PreKeyRecord *)loadPreKey:(int)preKeyId withProtocolContext:(id)protocolContext
{
    PreKeyRecord *preKeyRecord =
    [self preKeyRecordForKey:[self keyFromInt:preKeyId] inCollection:TSStorageManagerPreKeyStoreCollection withProtocolContext:protocolContext];
    
    if (!preKeyRecord) {
        @throw
        [NSException exceptionWithName:InvalidKeyIdException reason:[NSString stringWithFormat:@"No prekey found matching key id: %d", preKeyId] userInfo:@{}];
    } else {
        return preKeyRecord;
    }
}

// FIXME: Axolotl method
- (void)storePreKey:(int)preKeyId preKeyRecord:(PreKeyRecord *)record {
    DDLogWarn(@"Called Axolotl method \"- (void)storePreKey:(int)preKeyId preKeyRecord:(PreKeyRecord *)record\"");
    [self storePreKey:preKeyId preKeyRecord:record withProtocolContext:nil];
}

- (void)storePreKey:(int)preKeyId preKeyRecord:(PreKeyRecord *)record withProtocolContext:(nullable id)protocolContext{
    [self setObject:record forKey:[self keyFromInt:preKeyId] inCollection:TSStorageManagerPreKeyStoreCollection withProtocolContext:protocolContext];
    DDLogDebug(@"Stored prekey id: %d", preKeyId);
}


// FIXME: Axolotl method
- (BOOL)containsPreKey:(int)preKeyId {
    DDLogWarn(@"Called Axolotl method \"- (BOOL)containsPreKey:(int)preKeyId\"");
    return [self containsPreKey:preKeyId withProtocolContext:nil];
}

- (BOOL)containsPreKey:(int)preKeyId withProtocolContext:(nullable id)protocolContext{
    PreKeyRecord *preKeyRecord = [self preKeyRecordForKey:[self keyFromInt:preKeyId] inCollection:TSStorageManagerPreKeyStoreCollection withProtocolContext:protocolContext];
    return (preKeyRecord != nil);
}

// FIXME: Axolotl method
- (void)removePreKey:(int)preKeyId {
    DDLogWarn(@"Called Axolotl method \"- (void)removePreKey:(int)preKeyId\"");
    [self removePreKey:preKeyId withProtocolContext:nil];
}

- (void)removePreKey:(int)preKeyId withProtocolContext:(nullable id)protocolContext{
    [self removeObjectForKey:[self keyFromInt:preKeyId] inCollection:TSStorageManagerPreKeyStoreCollection withProtocolContext:protocolContext];
    DDLogDebug(@"Removed prekey id: %d", preKeyId);
}

@end
