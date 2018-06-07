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

- (PreKeyRecord *)getOrGenerateLastResortKey {
    if ([self containsPreKey:MAX_VALUE_LASTRESORT]) {
        return [self loadPreKey:MAX_VALUE_LASTRESORT];
    } else {
        PreKeyRecord *lastResort =
            [[PreKeyRecord alloc] initWithId:MAX_VALUE_LASTRESORT keyPair:[Curve25519 generateKeyPair]];
        [self storePreKey:MAX_VALUE_LASTRESORT preKeyRecord:lastResort];
        return lastResort;
    }
}

- (PreKeyRecord *)getOrGenerateLastResortKeyWithTransaction:(YapDatabaseReadWriteTransaction *)transaction {
    if ([self containsPreKey:MAX_VALUE_LASTRESORT withTransaction:transaction]) {
        return [self loadPreKey:MAX_VALUE_LASTRESORT];
    } else {
        PreKeyRecord *lastResort =
        [[PreKeyRecord alloc] initWithId:MAX_VALUE_LASTRESORT keyPair:[Curve25519 generateKeyPair]];
        [self storePreKey:MAX_VALUE_LASTRESORT preKeyRecord:lastResort withTransaction:transaction];
        return lastResort;
    }
}

- (NSArray *)generatePreKeyRecords {
    NSMutableArray *preKeyRecords = [NSMutableArray array];

    @synchronized(self) {
        int preKeyId = [self nextPreKeyId];
        for (int i = 0; i < BATCH_SIZE; i++) {
            ECKeyPair *keyPair   = [Curve25519 generateKeyPair];
            PreKeyRecord *record = [[PreKeyRecord alloc] initWithId:preKeyId keyPair:keyPair];

            [preKeyRecords addObject:record];
            preKeyId++;
        }

        [self setInt:preKeyId forKey:TSNextPrekeyIdKey inCollection:TSStorageInternalSettingsCollection];
    }
    return preKeyRecords;
}

- (NSArray *)generatePreKeyRecordsWithTransaction:(YapDatabaseReadWriteTransaction *)transaction {
    NSMutableArray *preKeyRecords = [NSMutableArray array];
    
    @synchronized(self) {
        int preKeyId = [self nextPreKeyIdWithTransaction:transaction];
        for (int i = 0; i < BATCH_SIZE; i++) {
            ECKeyPair *keyPair   = [Curve25519 generateKeyPair];
            PreKeyRecord *record = [[PreKeyRecord alloc] initWithId:preKeyId keyPair:keyPair];
            
            [preKeyRecords addObject:record];
            preKeyId++;
        }
        
        [self setInt:preKeyId forKey:TSNextPrekeyIdKey inCollection:TSStorageInternalSettingsCollection withTransaction:transaction];
    }
    return preKeyRecords;
}

- (void)storePreKeyRecords:(NSArray *)preKeyRecords {
    for (PreKeyRecord *record in preKeyRecords) {
        [self setObject:record forKey:[self keyFromInt:record.Id] inCollection:TSStorageManagerPreKeyStoreCollection];
    }
}

- (void)storePreKeyRecords:(NSArray *)preKeyRecords withTransaction:(YapDatabaseReadWriteTransaction *)transaction {
    for (PreKeyRecord *record in preKeyRecords) {
        [self setObject:record forKey:[self keyFromInt:record.Id] inCollection:TSStorageManagerPreKeyStoreCollection withTransaction:transaction];
    }
}

- (PreKeyRecord *)loadPreKey:(int)preKeyId {
    PreKeyRecord *preKeyRecord =
        [self preKeyRecordForKey:[self keyFromInt:preKeyId] inCollection:TSStorageManagerPreKeyStoreCollection];

    if (!preKeyRecord) {
        @throw
            [NSException exceptionWithName:InvalidKeyIdException reason:@"No key found matching key id" userInfo:@{}];
    } else {
        return preKeyRecord;
    }
}

- (PreKeyRecord *)loadPreKey:(int)preKeyId withTransaction:(YapDatabaseReadTransaction *)transaction {
    PreKeyRecord *preKeyRecord =
    [self preKeyRecordForKey:[self keyFromInt:preKeyId]
                inCollection:TSStorageManagerPreKeyStoreCollection
             withTransaction:transaction];
    
    if (!preKeyRecord) {
        @throw
        [NSException exceptionWithName:InvalidKeyIdException reason:@"No key found matching key id" userInfo:@{}];
    } else {
        return preKeyRecord;
    }
}

- (void)storePreKey:(int)preKeyId preKeyRecord:(PreKeyRecord *)record {
    [self setObject:record forKey:[self keyFromInt:preKeyId] inCollection:TSStorageManagerPreKeyStoreCollection];
}

- (void)storePreKey:(int)preKeyId preKeyRecord:(PreKeyRecord *)record withTransaction:(YapDatabaseReadWriteTransaction *)transaction {
    [self setObject:record forKey:[self keyFromInt:preKeyId] inCollection:TSStorageManagerPreKeyStoreCollection withTransaction:transaction];
}


- (BOOL)containsPreKey:(int)preKeyId {
    __block PreKeyRecord *preKeyRecord = nil;
    [TSStorageManager.sharedManager.dbConnection readWithBlock:^(YapDatabaseReadTransaction * _Nonnull transaction) {
        [self preKeyRecordForKey:[self keyFromInt:preKeyId] inCollection:TSStorageManagerPreKeyStoreCollection withTransaction:transaction];
    }];
    return (preKeyRecord != nil);
}

-(BOOL)containsPreKey:(int)preKeyId withTransaction:(YapDatabaseReadWriteTransaction *)transaction {
    PreKeyRecord *preKeyRecord =
    [self preKeyRecordForKey:[self keyFromInt:preKeyId] inCollection:TSStorageManagerPreKeyStoreCollection withTransaction:transaction];
    return (preKeyRecord != nil);
}

- (void)removePreKey:(int)preKeyId {
    [self removeObjectForKey:[self keyFromInt:preKeyId] inCollection:TSStorageManagerPreKeyStoreCollection];
}

- (void)removePreKey:(int)preKeyId withTransaction:(YapDatabaseReadWriteTransaction *)transaction {
    [self removeObjectForKey:[self keyFromInt:preKeyId] inCollection:TSStorageManagerPreKeyStoreCollection withTransaction:transaction];
}

- (int)nextPreKeyId {
    int lastPreKeyId = [self intForKey:TSNextPrekeyIdKey inCollection:TSStorageInternalSettingsCollection];

    while (lastPreKeyId < 1 || (lastPreKeyId > (MAX_VALUE_LASTRESORT - BATCH_SIZE))) {
        lastPreKeyId = rand();
    }

    return lastPreKeyId;
}

- (int)nextPreKeyIdWithTransaction:(YapDatabaseReadTransaction *)transaction {
    int lastPreKeyId = [self intForKey:TSNextPrekeyIdKey inCollection:TSStorageInternalSettingsCollection withTransaction:transaction];

    while (lastPreKeyId < 1 || (lastPreKeyId > (MAX_VALUE_LASTRESORT - BATCH_SIZE))) {
        lastPreKeyId = rand();
    }

    return lastPreKeyId;
}

@end
