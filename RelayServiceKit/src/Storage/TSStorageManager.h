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

- (void)deleteThreadsAndMessages;
- (void)deleteThreadsAndMessagesWithTransaction:(YapDatabaseReadWriteTransaction *)transaction;

- (BOOL)databasePasswordAccessible;

- (void)wipeSignalStorage;
- (void)wipeSignalStorageWithTransaction:(YapDatabaseReadWriteTransaction *)transaction;

- (YapDatabase *)database;
- (YapDatabaseConnection *)newDatabaseConnection;


- (void)setObject:(id)object forKey:(NSString *)key inCollection:(NSString *)collection;
- (void)setObject:(id)object forKey:(NSString *)key inCollection:(NSString *)collection withTransaction:(YapDatabaseReadWriteTransaction *)transaction;
- (void)removeObjectForKey:(NSString *)string inCollection:(NSString *)collection;
- (void)removeObjectForKey:(NSString *)string inCollection:(NSString *)collection withTransaction:(YapDatabaseReadWriteTransaction *)transaction;


- (BOOL)boolForKey:(NSString *)key inCollection:(NSString *)collection;
- (BOOL)boolForKey:(NSString *)key inCollection:(NSString *)collection withTransaction:(YapDatabaseReadTransaction *)transaction;
- (int)intForKey:(NSString *)key inCollection:(NSString *)collection;
-(int)intForKey:(NSString *)key inCollection:(NSString *)collection withTransaction:(YapDatabaseReadTransaction *)transaction;
- (void)setInt:(int)integer forKey:(NSString *)key inCollection:(NSString *)collection;
- (void)setInt:(int)integer forKey:(NSString *)key inCollection:(NSString *)collection withTransaction:(YapDatabaseReadWriteTransaction *)transaction;
- (id)objectForKey:(NSString *)key inCollection:(NSString *)collection;
- (id)objectForKey:(NSString *)key inCollection:(NSString *)collection withTransaction:(YapDatabaseReadTransaction *)transaction;
- (NSDictionary *)dictionaryForKey:(NSString *)key inCollection:(NSString *)collection;
- (NSDictionary *)dictionaryForKey:(NSString *)key inCollection:(NSString *)collection withTransaction:(YapDatabaseReadTransaction *)transaction;
- (NSString *)stringForKey:(NSString *)key inCollection:(NSString *)collection;
- (NSData *)dataForKey:(NSString *)key inCollection:(NSString *)collection;
- (NSData *)dataForKey:(NSString *)key inCollection:(NSString *)collection withTransaction:(YapDatabaseReadTransaction *)transaction;
- (ECKeyPair *)keyPairForKey:(NSString *)key inCollection:(NSString *)collection;
- (ECKeyPair *)keyPairForKey:(NSString *)key inCollection:(NSString *)collection withTransaction:(YapDatabaseReadTransaction *)transaction;
- (PreKeyRecord *)preKeyRecordForKey:(NSString *)key inCollection:(NSString *)collection;
- (PreKeyRecord *)preKeyRecordForKey:(NSString *)key inCollection:(NSString *)collection withTransaction:(YapDatabaseReadTransaction *)transaction;
- (SignedPreKeyRecord *)signedPreKeyRecordForKey:(NSString *)key inCollection:(NSString *)collection;
- (SignedPreKeyRecord *)signedPreKeyRecordForKey:(NSString *)key inCollection:(NSString *)collection withTransaction:(YapDatabaseReadTransaction *)transaction;
- (void)purgeCollection:(NSString *)collection;
- (void)purgeCollection:(NSString *)collection withTransaction:(YapDatabaseReadWriteTransaction *)transaction;

@property (nonatomic, readonly) YapDatabaseConnection *dbConnection;
@property (nonatomic ,readonly) YapDatabaseConnection *messagesConnection;
@property (nonatomic, readonly) TSPrivacyPreferences *privacyPreferences;

@end
