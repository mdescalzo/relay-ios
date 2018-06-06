//
//  TSStorageManager+SignedPreKeyStore.m
//  TextSecureKit
//
//  Created by Frederic Jacobs on 06/11/14.
//  Copyright (c) 2014 Open Whisper Systems. All rights reserved.
//


#import "TSStorageManager+IdentityKeyStore.h"
#import "TSStorageManager+SignedPreKeyStore.h"
#import "TSStorageManager+keyFromIntLong.h"

#import <Curve25519Kit/Ed25519.h>
#import <AxolotlKit/AxolotlExceptions.h>
#import <AxolotlKit/NSData+keyVersionByte.h>

@implementation TSStorageManager (SignedPreKeyStore)

- (SignedPreKeyRecord *)generateRandomSignedRecord {
    ECKeyPair *keyPair = [Curve25519 generateKeyPair];
    
    __block ECKeyPair *myIdentityKeyPair = nil;
    [self.dbConnection readWithBlock:^(YapDatabaseReadTransaction * _Nonnull transaction) {
        myIdentityKeyPair = [self identityKeyPair:transaction];
    }];
    
    return [[SignedPreKeyRecord alloc]
            initWithId:rand()
            keyPair:keyPair
            signature:[Ed25519 sign:keyPair.publicKey.prependKeyType withKeyPair:myIdentityKeyPair]
            generatedAt:[NSDate date]];
}

- (SignedPreKeyRecord *)generateRandomSignedRecordWithTransaction:(YapDatabaseReadTransaction *)transaction {
    ECKeyPair *keyPair = [Curve25519 generateKeyPair];
    
    ECKeyPair *myIdentityKeyPair = [self identityKeyPair:transaction];
    
    return [[SignedPreKeyRecord alloc]
            initWithId:rand()
            keyPair:keyPair
            signature:[Ed25519 sign:keyPair.publicKey.prependKeyType withKeyPair:myIdentityKeyPair]
            generatedAt:[NSDate date]];
}

- (nullable SignedPreKeyRecord *)loadSignedPrekeyOrNil:(int)signedPreKeyId {
    __block SignedPreKeyRecord *record = nil;
    [TSStorageManager.sharedManager.dbConnection readWithBlock:^(YapDatabaseReadTransaction * _Nonnull transaction) {
        record = [self signedPreKeyRecordForKey:[self keyFromInt:signedPreKeyId]
                                   inCollection:TSStorageManagerSignedPreKeyStoreCollection
                                withTransaction:transaction];
    }];
    return record;
}

- (nullable SignedPreKeyRecord *)loadSignedPrekeyOrNil:(int)signedPreKeyId withTransaction:(YapDatabaseReadTransaction *)transaction {
    return [self signedPreKeyRecordForKey:[self keyFromInt:signedPreKeyId]
                             inCollection:TSStorageManagerSignedPreKeyStoreCollection withTransaction:transaction];
}


- (SignedPreKeyRecord *)loadSignedPrekey:(int)signedPreKeyId {
    __block SignedPreKeyRecord *preKeyRecord = nil;
    
    [TSStorageManager.sharedManager.dbConnection readWithBlock:^(YapDatabaseReadTransaction * _Nonnull transaction) {
        preKeyRecord = [self signedPreKeyRecordForKey:[self keyFromInt:signedPreKeyId]
                                         inCollection:TSStorageManagerSignedPreKeyStoreCollection
                                      withTransaction:transaction];
    }];
    
    if (!preKeyRecord) {
        @throw
        [NSException exceptionWithName:InvalidKeyIdException reason:@"No key found matching key id" userInfo:@{}];
    } else {
        return preKeyRecord;
    }
}

- (SignedPreKeyRecord *)loadSignedPrekey:(int)signedPreKeyId withTransaction:(YapDatabaseReadTransaction *)transaction {
    
    SignedPreKeyRecord *preKeyRecord = [self signedPreKeyRecordForKey:[self keyFromInt:signedPreKeyId]
                                                         inCollection:TSStorageManagerSignedPreKeyStoreCollection
                                                      withTransaction:transaction];
    
    if (!preKeyRecord) {
        @throw
        [NSException exceptionWithName:InvalidKeyIdException reason:@"No key found matching key id" userInfo:@{}];
    } else {
        return preKeyRecord;
    }
}


- (NSArray *)loadSignedPreKeys {
    NSMutableArray *signedPreKeyRecords = [NSMutableArray array];
    
    YapDatabaseConnection *conn = [self newDatabaseConnection];
    
    [conn readWithBlock:^(YapDatabaseReadTransaction *transaction) {
        [transaction enumerateRowsInCollection:TSStorageManagerSignedPreKeyStoreCollection
                                    usingBlock:^(NSString *key, id object, id metadata, BOOL *stop) {
                                        [signedPreKeyRecords addObject:object];
                                    }];
    }];
    
    return signedPreKeyRecords;
}

- (NSArray *)loadSignedPreKeysWithTransaction:(YapDatabaseReadTransaction *)transaction {
    NSMutableArray *signedPreKeyRecords = [NSMutableArray array];
    
    [transaction enumerateRowsInCollection:TSStorageManagerSignedPreKeyStoreCollection
                                usingBlock:^(NSString *key, id object, id metadata, BOOL *stop) {
                                    [signedPreKeyRecords addObject:object];
                                }];
    
    return signedPreKeyRecords;
}


- (void)storeSignedPreKey:(int)signedPreKeyId signedPreKeyRecord:(SignedPreKeyRecord *)signedPreKeyRecord {
    [self setObject:signedPreKeyRecord
             forKey:[self keyFromInt:signedPreKeyId]
       inCollection:TSStorageManagerSignedPreKeyStoreCollection];
}
- (void)storeSignedPreKey:(int)signedPreKeyId signedPreKeyRecord:(SignedPreKeyRecord *)signedPreKeyRecord withTransaction:(YapDatabaseReadWriteTransaction *)transaction {
    [self setObject:signedPreKeyRecord
             forKey:[self keyFromInt:signedPreKeyId]
       inCollection:TSStorageManagerSignedPreKeyStoreCollection
    withTransaction:transaction];
}


- (BOOL)containsSignedPreKey:(int)signedPreKeyId {
    __block PreKeyRecord *preKeyRecord = nil;
    [TSStorageManager.sharedManager.dbConnection readWithBlock:^(YapDatabaseReadTransaction * _Nonnull transaction) {
        
        preKeyRecord = [self signedPreKeyRecordForKey:[self keyFromInt:signedPreKeyId]
                                         inCollection:TSStorageManagerSignedPreKeyStoreCollection
                                      withTransaction:transaction];
    }];
    return (preKeyRecord != nil);
}

- (BOOL)containsSignedPreKey:(int)signedPreKeyId withTransaction:(YapDatabaseReadTransaction *)transaction {
    PreKeyRecord *preKeyRecord = [self signedPreKeyRecordForKey:[self keyFromInt:signedPreKeyId]
                                                   inCollection:TSStorageManagerSignedPreKeyStoreCollection
                                                withTransaction:transaction];
    return (preKeyRecord != nil);
}


- (void)removeSignedPreKey:(int)signedPrekeyId {
    [self removeObjectForKey:[self keyFromInt:signedPrekeyId]
                inCollection:TSStorageManagerSignedPreKeyStoreCollection];
}

- (void)removeSignedPreKey:(int)signedPrekeyId withTransaction:(YapDatabaseReadWriteTransaction *)transaction {
    [self removeObjectForKey:[self keyFromInt:signedPrekeyId]
                inCollection:TSStorageManagerSignedPreKeyStoreCollection
             withTransaction:transaction];
}



@end
