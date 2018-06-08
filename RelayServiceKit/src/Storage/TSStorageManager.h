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

extern NSString *const TSUIDatabaseConnectionDidUpdateNotification;

@interface TSStorageManager : NSObject

+ (instancetype)sharedManager;
- (void)setupDatabase;

- (void)deleteThreadsAndMessagesWithProtocolContext:(nullable id)protocolContext;

- (BOOL)databasePasswordAccessible;

- (void)wipeSignalStorage;

- (YapDatabase *)database;
- (YapDatabaseConnection *)newDatabaseConnection;


- (void)setObject:(id)object forKey:(NSString *)key inCollection:(NSString *)collection withProtocolContext:(nullable id)protocolContext;
- (void)removeObjectForKey:(NSString *)string inCollection:(NSString *)collection withProtocolContext:(nullable id)protocolContext;


- (BOOL)boolForKey:(NSString *)key inCollection:(NSString *)collection withProtocolContext:(nullable id)protocolContext;
- (int)intForKey:(NSString *)key inCollection:(NSString *)collection withProtocolContext:(nullable id)protocolContext;
- (void)setInt:(int)integer forKey:(NSString *)key inCollection:(NSString *)collection withProtocolContext:(nullable id)protocolContext;
- (id)objectForKey:(NSString *)key inCollection:(NSString *)collection withProtocolContext:(nullable id)protocolContext;
- (NSDictionary *)dictionaryForKey:(NSString *)key inCollection:(NSString *)collection withProtocolContext:(nullable id)protocolContext;
- (NSString *)stringForKey:(NSString *)key inCollection:(NSString *)collection withProtocolContext:(nullable id)protocolContext;
- (NSData *)dataForKey:(NSString *)key inCollection:(NSString *)collection withProtocolContext:(nullable id)protocolContext;
- (ECKeyPair *)keyPairForKey:(NSString *)key inCollection:(NSString *)collection withProtocolContext:(nullable id)protocolContext;
- (PreKeyRecord *)preKeyRecordForKey:(NSString *)key inCollection:(NSString *)collection withProtocolContext:(nullable id)protocolContext;
- (SignedPreKeyRecord *)signedPreKeyRecordForKey:(NSString *)key inCollection:(NSString *)collection withProtocolContext:(nullable id)protocolContext;
- (void)purgeCollection:(NSString *)collection withProtocolContext:(nullable id)protocolContext;

@property (nonatomic, readonly) YapDatabaseConnection *dbConnection;
@property (nonatomic ,readonly) YapDatabaseConnection *messagesConnection;
@property (nonatomic, readonly) TSPrivacyPreferences *privacyPreferences;

@end
