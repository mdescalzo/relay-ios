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

-(NSData *)identityKeyForRecipientId:(NSString *)recipientId withProtocolContext:(nullable id)protocolContext;

-(void)removeIdentityKeyForRecipient:(NSString *)receipientId withProtocolContext:(nullable id)protocolContext;

-(void)setIdentityKey:(ECKeyPair *)identityKeyPair withProtocolContext:(nullable id)protocolContext;

@end
