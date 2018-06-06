//
//  TSStorageManager+IdentityKeyStore.h
//  TextSecureKit
//
//  Created by Frederic Jacobs on 06/11/14.
//  Copyright (c) 2014 Open Whisper Systems. All rights reserved.
//

#import <AxolotlKit/IdentityKeyStore.h>
#import "TSStorageManager.h"

@interface TSStorageManager (IdentityKeyStore) <IdentityKeyStore>

- (void)generateNewIdentityKey;
-(void)generateNewIdentityKeyWithTransaction:(YapDatabaseReadWriteTransaction *)transaction;

- (NSData *)identityKeyForRecipientId:(NSString *)recipientId;
- (NSData *)identityKeyForRecipientId:(NSString *)recipientId withTransaction:(YapDatabaseReadTransaction *)transaction;

- (void)removeIdentityKeyForRecipient:(NSString *)receipientId;
- (void)removeIdentityKeyForRecipient:(NSString *)receipientId withTransaction:(YapDatabaseReadWriteTransaction *)transaction;

-(void)setIdentityKey:(ECKeyPair *)identityKeyPair;
-(void)setIdentityKey:(ECKeyPair *)identityKeyPair withTransaction:(YapDatabaseReadWriteTransaction *)transaction;

@end
