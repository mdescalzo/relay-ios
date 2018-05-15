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

- (nullable SignedPreKeyRecord *)loadSignedPrekeyOrNil:(int)signedPreKeyId {
    return [self signedPreKeyRecordForKey:[self keyFromInt:signedPreKeyId]
                             inCollection:TSStorageManagerSignedPreKeyStoreCollection];
}

- (SignedPreKeyRecord *)loadSignedPrekey:(int)signedPreKeyId {
    SignedPreKeyRecord *preKeyRecord = [self signedPreKeyRecordForKey:[self keyFromInt:signedPreKeyId]
                                                         inCollection:TSStorageManagerSignedPreKeyStoreCollection];

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

- (void)storeSignedPreKey:(int)signedPreKeyId signedPreKeyRecord:(SignedPreKeyRecord *)signedPreKeyRecord {
    [self setObject:signedPreKeyRecord
              forKey:[self keyFromInt:signedPreKeyId]
        inCollection:TSStorageManagerSignedPreKeyStoreCollection];
}

- (BOOL)containsSignedPreKey:(int)signedPreKeyId {
    PreKeyRecord *preKeyRecord = [self signedPreKeyRecordForKey:[self keyFromInt:signedPreKeyId]
                                                   inCollection:TSStorageManagerSignedPreKeyStoreCollection];
    return (preKeyRecord != nil);
}

- (void)removeSignedPreKey:(int)signedPrekeyId {
    [self removeObjectForKey:[self keyFromInt:signedPrekeyId] inCollection:TSStorageManagerSignedPreKeyStoreCollection];
}




@end
