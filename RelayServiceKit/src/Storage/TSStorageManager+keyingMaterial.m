//
//  TSStorageManager+keyingMaterial.m
//  TextSecureKit
//
//  Created by Frederic Jacobs on 06/11/14.
//  Copyright (c) 2014 Open Whisper Systems. All rights reserved.
//

#import "TSStorageManager+keyingMaterial.h"

@implementation TSStorageManager (keyingMaterial)

+ (NSString *)localNumberWithProtocolContext:(id)protocolContext
{
    return [[self sharedManager] localNumberWithProtocolContext:protocolContext];
}

- (NSString *)localNumberWithProtocolContext:(id)protocolContext
{
    return [self stringForKey:TSStorageRegisteredNumberKey inCollection:TSStorageUserAccountCollection withProtocolContext:protocolContext];
}

+ (NSNumber *)deviceIdWithProtocolContext:(id)protocolContext
{
    return [[self sharedManager] deviceIdWithProtocolContext:protocolContext];
}

- (NSNumber *)deviceIdWithProtocolContext:(id)protocolContext
{
    NSNumber *number = [self objectForKey:TSStorageRegisteredDeviceIDKey inCollection:TSStorageUserAccountCollection withProtocolContext:protocolContext];
        return number;
}


+ (void)removeLocalNumberWithProtocolContext:(id)protocolContext;
{
    [[self sharedManager] removeLocalNumberWithProtocolContext:protocolContext];
}

- (void)removeLocalNumberWithProtocolContext:(id)protocolContext;
{
    [self removeObjectForKey:TSStorageRegisteredNumberKey inCollection:TSStorageUserAccountCollection withProtocolContext:protocolContext];
}

- (void)ifLocalNumberPresent:(BOOL)runIfPresent withProtocolContext:(nullable id)protocolContext runAsync:(void (^)())block
{
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        BOOL isPresent = [[self objectForKey:TSStorageRegisteredNumberKey
                                inCollection:TSStorageUserAccountCollection
                         withProtocolContext:protocolContext] boolValue];
        
        if (isPresent == runIfPresent) {
            if (runIfPresent) {
                DDLogDebug(@"%@ Running existing-user block", self.logTag);
            } else {
                DDLogDebug(@"%@ Running new-user block", self.logTag);
            }
            block();
        } else {
            if (runIfPresent) {
                DDLogDebug(@"%@ Skipping existing-user block for new-user", self.logTag);
            } else {
                DDLogDebug(@"%@ Skipping new-user block for existing-user", self.logTag);
            }
        }
    });
}

+ (NSString *)signalingKeyWithProtocolContext:(id)protocolContext {
    return [[self sharedManager] stringForKey:TSStorageServerSignalingKey inCollection:TSStorageUserAccountCollection withProtocolContext:protocolContext];
}

+ (NSString *)serverAuthTokenWithProtocolContext:(id)protocolContext {
    return [[self sharedManager] stringForKey:TSStorageServerAuthToken inCollection:TSStorageUserAccountCollection withProtocolContext:protocolContext];
}

- (void)storeLocalNumber:(NSString *)localNumber withProtocolContext:(nullable id)protocolContext
{
    [self setObject:localNumber forKey:TSStorageRegisteredNumberKey inCollection:TSStorageUserAccountCollection withProtocolContext:protocolContext];
}

- (void)storeDeviceId:(NSNumber *)deviceId withProtocolContext:(nullable id)protocolContext
{
    [self setObject:deviceId forKey:TSStorageRegisteredDeviceIDKey inCollection:TSStorageUserAccountCollection withProtocolContext:protocolContext];
}

+(void)removeServerTokenAndSignalingKeyWithProtocolContext:(id)protocolContext
{
    [[self sharedManager] removeObjectForKey:TSStorageServerAuthToken inCollection:TSStorageUserAccountCollection withProtocolContext:protocolContext];
    [[self sharedManager] removeObjectForKey:TSStorageServerSignalingKey inCollection:TSStorageUserAccountCollection withProtocolContext:protocolContext];
}

+ (void)storeServerToken:(NSString *)authToken signalingKey:(NSString *)signalingKey withProtocolContext:(nullable id)protocolContext
{
      [[self sharedManager] setObject:authToken forKey:TSStorageServerAuthToken inCollection:TSStorageUserAccountCollection withProtocolContext:protocolContext];
      [[self sharedManager] setObject:signalingKey
                      forKey:TSStorageServerSignalingKey
                inCollection:TSStorageUserAccountCollection withProtocolContext:protocolContext];
}

#pragma mark - Logging

+ (NSString *)logTag
{
    return [NSString stringWithFormat:@"[%@]", self.class];
}

- (NSString *)logTag
{
    return self.class.logTag;
}

@end
