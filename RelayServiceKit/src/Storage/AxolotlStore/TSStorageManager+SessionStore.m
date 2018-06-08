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

- (nonnull SessionRecord *)loadSession:(nonnull NSString *)contactIdentifier deviceId:(int)deviceId protocolContext:(nullable id)protocolContext
{
    NSDictionary *dictionary =
    [self dictionaryForKey:contactIdentifier inCollection:TSStorageManagerSessionStoreCollection withProtocolContext:protocolContext];

    SessionRecord *record = nil;

    if (dictionary) {
        record = [dictionary objectForKey:[self keyForInt:deviceId]];
    }

    if (!record) {
        return [SessionRecord new];
    }

    return record;
}

- (nonnull NSArray *)subDevicesSessions:(nonnull NSString *)contactIdentifier protocolContext:(nullable id)protocolContext
{
    NSDictionary *dictionary =
    [self objectForKey:contactIdentifier inCollection:TSStorageManagerSessionStoreCollection withProtocolContext:protocolContext];
    
    NSMutableArray *subDevicesSessions = [NSMutableArray array];
    
    if (dictionary) {
        for (NSString *key in [dictionary allKeys]) {
            NSNumber *number = @([key doubleValue]);
            
            [subDevicesSessions addObject:number];
        }
    }
    return subDevicesSessions;
}

- (void)storeSession:(nonnull NSString *)contactIdentifier
            deviceId:(int)deviceId
             session:(nonnull SessionRecord *)session
     protocolContext:(nullable id)protocolContext
{
    [session markAsUnFresh];
    
    NSMutableDictionary *dictionary =
    [[self dictionaryForKey:contactIdentifier inCollection:TSStorageManagerSessionStoreCollection withProtocolContext:protocolContext] mutableCopy];
    
    if (!dictionary) {
        dictionary = [NSMutableDictionary new];
    }
    
    [dictionary setObject:session forKey:[self keyForInt:deviceId]];
    
    [self setObject:[NSDictionary dictionaryWithDictionary:dictionary]
             forKey:contactIdentifier
       inCollection:TSStorageManagerSessionStoreCollection
withProtocolContext:protocolContext];
}

- (BOOL)containsSession:(NSString *)contactIdentifier
               deviceId:(int)deviceId
        protocolContext:(id)protocolContext
{
    return [self loadSession:contactIdentifier deviceId:deviceId protocolContext:protocolContext].sessionState.hasSenderChain;
}

- (void)deleteSessionForContact:(nonnull NSString *)contactIdentifier deviceId:(int)deviceId protocolContext:(nullable id)protocolContext
{
    NSMutableDictionary *dictionary = [[self dictionaryForKey:contactIdentifier
                                                 inCollection:TSStorageManagerSessionStoreCollection
                                          withProtocolContext:protocolContext] mutableCopy];
    
    if (!dictionary) {
        dictionary = [NSMutableDictionary dictionary];
    }
    
    [dictionary removeObjectForKey:[self keyForInt:deviceId]];
    
    [self setObject:dictionary forKey:contactIdentifier inCollection:TSStorageManagerSessionStoreCollection withProtocolContext:protocolContext];
}

-(void)deleteAllSessionsForContact:(NSString *)contactIdentifier protocolContext:(id)protocolContext {
    [self removeObjectForKey:contactIdentifier inCollection:TSStorageManagerSessionStoreCollection withProtocolContext:protocolContext];
}

- (NSNumber *)keyForInt:(int)number {
    return [NSNumber numberWithInt:number];
}

@end
