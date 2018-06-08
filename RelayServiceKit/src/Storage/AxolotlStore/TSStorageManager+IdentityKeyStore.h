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

-(void)generateNewIdentityKeyWithProtocolContext:(nullable id)protocolContext;

-(NSData *_Nonnull)identityKeyForRecipientId:(NSString *_Nonnull)recipientId withProtocolContext:(nullable id)protocolContext;

-(void)removeIdentityKeyForRecipient:(NSString *_Nonnull)receipientId withProtocolContext:(nullable id)protocolContext;

-(void)setIdentityKey:(ECKeyPair *_Nonnull)identityKeyPair withProtocolContext:(nullable id)protocolContext;

@end
