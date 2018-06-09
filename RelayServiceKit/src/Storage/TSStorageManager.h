//
//  TSStorageManager.h
//  TextSecureKit
//
//  Created by Frederic Jacobs on 27/10/14.
//  Copyright (c) 2014 Open Whisper Systems. All rights reserved.
//

#import "TSStorageKeys.h"

#import <Foundation/Foundation.h>
#import <YapDatabase/YapDatabase.h>

@class ECKeyPair;
@class PreKeyRecord;
@class SignedPreKeyRecord;
@class TSPrivacyPreferences;

extern NSString *_Nonnull const TSUIDatabaseConnectionDidUpdateNotification;

@interface TSStorageManager : NSObject

+ (instancetype _Nonnull )sharedManager;
- (void)setupDatabase;

- (void)deleteThreadsAndMessagesWithProtocolContext:(nullable id)protocolContext;

- (BOOL)databasePasswordAccessible;

- (void)wipeSignalStorage;

- (YapDatabase *_Nonnull)database;
- (YapDatabaseConnection *_Nonnull)newDatabaseConnection;


- (void)setObject:(nullable id)object forKey:(NSString *_Nonnull)key inCollection:(NSString *_Nonnull)collection withProtocolContext:(nullable id)protocolContext;
- (void)removeObjectForKey:(NSString *_Nonnull)string inCollection:(NSString *_Nonnull)collection withProtocolContext:(nullable id)protocolContext;


- (BOOL)boolForKey:(NSString *_Nonnull)key inCollection:(NSString *_Nonnull)collection withProtocolContext:(nullable id)protocolContext;
- (int)intForKey:(NSString *_Nonnull)key inCollection:(NSString *_Nonnull)collection withProtocolContext:(nullable id)protocolContext;
- (void)setInt:(int)integer forKey:(NSString *_Nonnull)key inCollection:(NSString *_Nonnull)collection withProtocolContext:(nullable id)protocolContext;
- (nullable id)objectForKey:(NSString *_Nonnull)key inCollection:(NSString *_Nonnull)collection withProtocolContext:(nullable id)protocolContext;
- (nullable NSDictionary *)dictionaryForKey:(NSString *_Nonnull)key inCollection:(NSString *_Nonnull)collection withProtocolContext:(nullable id)protocolContext;
- (nullable NSString *)stringForKey:(NSString *_Nonnull)key inCollection:(NSString *_Nonnull)collection withProtocolContext:(nullable id)protocolContext;
- (nullable NSData *)dataForKey:(NSString *_Nonnull)key inCollection:(NSString *_Nonnull)collection withProtocolContext:(nullable id)protocolContext;
- (nullable ECKeyPair *)keyPairForKey:(NSString *_Nonnull)key inCollection:(NSString *_Nonnull)collection withProtocolContext:(nullable id)protocolContext;
- (nullable PreKeyRecord *)preKeyRecordForKey:(NSString *_Nonnull)key inCollection:(NSString *_Nonnull)collection withProtocolContext:(nullable id)protocolContext;
- (nullable SignedPreKeyRecord *)signedPreKeyRecordForKey:(NSString *_Nonnull)key inCollection:(NSString *_Nonnull)collection withProtocolContext:(nullable id)protocolContext;
- (void)purgeCollection:(NSString *_Nonnull)collection withProtocolContext:(nullable id)protocolContext;

@property (readonly) YapDatabaseConnection * _Nonnull writeDbConnection;
@property (readonly) YapDatabaseConnection * _Nonnull readDbConnection;
@property (readonly) YapDatabaseConnection * _Nonnull messagesConnection;
@property (nonatomic, readonly) TSPrivacyPreferences * _Nonnull privacyPreferences;

@end
