//
//  TSStorageManager+PreKeyStore.h
//  TextSecureKit
//
//  Created by Frederic Jacobs on 06/11/14.
//  Copyright (c) 2014 Open Whisper Systems. All rights reserved.
//

#import <AxolotlKit/PreKeyStore.h>
#import "TSStorageManager.h"

@interface TSStorageManager (PreKeyStore) <PreKeyStore>

- (NSArray *)generatePreKeyRecordsWithProtocolContext:(nullable id)protocolContext;

- (PreKeyRecord *)getOrGenerateLastResortKeyWithProtocolContext:(nullable id)protocolContext;

- (void)storePreKeyRecords:(NSArray *)preKeyRecords withProtocolContext:(nullable id)protocolContext;

- (PreKeyRecord *)loadPreKey:(int)preKeyId withProtocolContext:(nullable id)protocolContext;
- (void)storePreKey:(int)preKeyId preKeyRecord:(PreKeyRecord *)record withProtocolContext:(nullable id)protocolContext;
- (BOOL)containsPreKey:(int)preKeyId withProtocolContext:(nullable id)protocolContext;
- (void)removePreKey:(int)preKeyId withProtocolContext:(nullable id)protocolContext;

@end
