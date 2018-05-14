//
//  TSStorageManager+SessionStore.m
//  TextSecureKit
//
//  Created by Frederic Jacobs on 06/11/14.
//  Copyright (c) 2014 Open Whisper Systems. All rights reserved.
//

#import "TSStorageManager+SessionStore.h"

#define TSStorageManagerSessionStoreCollection @"TSStorageManagerSessionStoreCollection"

@implementation TSStorageManager (SessionStore)

- (nonnull SessionRecord *)loadSession:(nonnull NSString *)contactIdentifier deviceId:(int)deviceId protocolContext:(nullable id)protocolContext {
    NSDictionary *dictionary =
        [self dictionaryForKey:contactIdentifier inCollection:TSStorageManagerSessionStoreCollection];

    SessionRecord *record;

    if (dictionary) {
        record = [dictionary objectForKey:[self keyForInt:deviceId]];
    }

    if (!record) {
        return [SessionRecord new];
    }

    return record;
}

//- (NSArray *)subDevicesSessions:(NSString *)contactIdentifier {
//    NSDictionary *dictionary =
//        [self objectForKey:contactIdentifier inCollection:TSStorageManagerSessionStoreCollection];
//
//    NSMutableArray *subDevicesSessions = [NSMutableArray array];
//
//    if (dictionary) {
//        for (NSString *key in [dictionary allKeys]) {
//            NSNumber *number = @([key doubleValue]);
//
//            [subDevicesSessions addObject:number];
//        }
//    }
//
//    return subDevicesSessions;
//}

- (nonnull NSArray *)subDevicesSessions:(nonnull NSString *)contactIdentifier protocolContext:(nullable id)protocolContext {
    NSAssert([protocolContext isKindOfClass:[YapDatabaseReadTransaction class]], @"protocolContext must be a YapDatabaseReadTransaction");
    YapDatabaseReadTransaction *transaction = (YapDatabaseReadTransaction *)protocolContext;

    NSDictionary *dictionary =
    [self objectForKey:contactIdentifier inCollection:TSStorageManagerSessionStoreCollection withTransaction:transaction];
    
    NSMutableArray *subDevicesSessions = [NSMutableArray array];
    
    if (dictionary) {
        for (NSString *key in [dictionary allKeys]) {
            NSNumber *number = @([key doubleValue]);
            
            [subDevicesSessions addObject:number];
        }
    }
    
    return subDevicesSessions;
}

//- (void)storeSession:(NSString *)contactIdentifier deviceId:(int)deviceId session:(SessionRecord *)session {
//    NSMutableDictionary *dictionary =
//        [[self dictionaryForKey:contactIdentifier inCollection:TSStorageManagerSessionStoreCollection] mutableCopy];
//
//    if (!dictionary) {
//        dictionary = [NSMutableDictionary dictionary];
//    }
//
//    [dictionary setObject:session forKey:[self keyForInt:deviceId]];
//
//    [self setObject:dictionary forKey:contactIdentifier inCollection:TSStorageManagerSessionStoreCollection];
//}

- (void)storeSession:(nonnull NSString *)contactIdentifier deviceId:(int)deviceId session:(nonnull SessionRecord *)session protocolContext:(nullable id)protocolContext {
    NSAssert([protocolContext isKindOfClass:[YapDatabaseReadWriteTransaction class]], @"protocolContext must be a YapDatabaseReadWriteTransaction");
    YapDatabaseReadWriteTransaction *transaction = (YapDatabaseReadWriteTransaction *)protocolContext;

    NSMutableDictionary *dictionary =
    [[self dictionaryForKey:contactIdentifier inCollection:TSStorageManagerSessionStoreCollection withTransaction:transaction] mutableCopy];
    
    if (!dictionary) {
        dictionary = [NSMutableDictionary dictionary];
    }
    
    [dictionary setObject:session forKey:[self keyForInt:deviceId]];
    
    [self setObject:dictionary forKey:contactIdentifier inCollection:TSStorageManagerSessionStoreCollection withTransaction:transaction];

}


//- (BOOL)containsSession:(NSString *)contactIdentifier deviceId:(int)deviceId {
//    __block BOOL returnVal;
//
//    [TSStorageManager.sharedManager.dbConnection readWithBlock:^(YapDatabaseReadTransaction * _Nonnull transaction) {
//        returnVal = [self loadSession:contactIdentifier deviceId:deviceId protocolContext:transaction];
//    }];
//
//    return returnVal;
//}

- (BOOL)containsSession:(NSString *)contactIdentifier deviceId:(int)deviceId protocolContext:(id)protocolContext {
    NSAssert([protocolContext isKindOfClass:[YapDatabaseReadTransaction class]], @"protocolContext must be a YapDatabaseReadTransaction");
    YapDatabaseReadTransaction *transaction = (YapDatabaseReadTransaction *)protocolContext;
    return [self loadSession:contactIdentifier deviceId:deviceId protocolContext:transaction].sessionState.hasSenderChain;
}

//- (void)deleteSessionForContact:(NSString *)contactIdentifier deviceId:(int)deviceId {
//    NSMutableDictionary *dictionary =
//        [[self dictionaryForKey:contactIdentifier inCollection:TSStorageManagerSessionStoreCollection] mutableCopy];
//
//    if (!dictionary) {
//        dictionary = [NSMutableDictionary dictionary];
//    }
//
//    [dictionary removeObjectForKey:[self keyForInt:deviceId]];
//
//    [self setObject:dictionary forKey:contactIdentifier inCollection:TSStorageManagerSessionStoreCollection];
//}

- (void)deleteSessionForContact:(nonnull NSString *)contactIdentifier deviceId:(int)deviceId protocolContext:(nullable id)protocolContext {
    NSAssert([protocolContext class] == [YapDatabaseReadWriteTransaction class], @"protocolContext must be a YapDatabaseReadWriteTransaction");
    YapDatabaseReadWriteTransaction *transaction = (YapDatabaseReadWriteTransaction *)protocolContext;

    NSMutableDictionary *dictionary =
    [[self dictionaryForKey:contactIdentifier inCollection:TSStorageManagerSessionStoreCollection withTransaction:transaction] mutableCopy];
    
    if (!dictionary) {
        dictionary = [NSMutableDictionary dictionary];
    }
    
    [dictionary removeObjectForKey:[self keyForInt:deviceId]];
    
    [self setObject:dictionary forKey:contactIdentifier inCollection:TSStorageManagerSessionStoreCollection withTransaction:transaction];
}

-(void)deleteAllSessionsForContact:(NSString *)contactIdentifier protocolContext:(id)protocolContext {
    NSAssert([protocolContext class] == [YapDatabaseReadWriteTransaction class], @"protocolContext must be a YapDatabaseReadWriteTransaction");
    YapDatabaseReadWriteTransaction *transaction = (YapDatabaseReadWriteTransaction *)protocolContext;
    [self removeObjectForKey:contactIdentifier inCollection:TSStorageManagerSessionStoreCollection withTransaction:transaction];
}

- (NSNumber *)keyForInt:(int)number {
    return [NSNumber numberWithInt:number];
}

@end
