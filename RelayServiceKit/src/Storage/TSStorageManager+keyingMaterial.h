//
//  TSStorageManager+keyingMaterial.h
//  TextSecureKit
//
//  Created by Frederic Jacobs on 06/11/14.
//  Copyright (c) 2014 Open Whisper Systems. All rights reserved.
//

#import "TSStorageManager.h"

@interface TSStorageManager (keyingMaterial)

#pragma mark Server Credentials

/**
 *  The server signaling key that's used to encrypt push payloads
 *
 *  @return signaling key
 */

+ (nullable NSString *)signalingKeyWithProtocolContext:(nullable id)protocolContext;

/**
 *  The server auth token allows the TextSecure client to connect to the server
 *
 *  @return server authentication token
 */

+ (nullable NSString *)serverAuthTokenWithProtocolContext:(nullable id)protocolContext;

/**
 *  Registered phone number
 *
 *  @return E164 string of the registered phone number
 */
- (nullable NSString *)localNumberWithProtocolContext:(nullable id)protocolContext;
+ (nullable NSString *)localNumberWithProtocolContext:(nullable id)protocolContext;
- (void)removeLocalNumberWithProtocolContext:(nullable id)protocolContext;
+ (void)removeLocalNumberWithProtocolContext:(nullable id)protocolContext;

/**
 * Registered device ID
 */
+ (nullable NSNumber *)deviceIdWithProtocolContext:(nullable id)protocolContext;
- (nullable NSNumber *)deviceIdWithProtocolContext:(nullable id)protocolContext;

- (void)ifLocalNumberPresent:(BOOL)isPresent withProtocolContext:(nullable id)protocolContext runAsync:(void (^_Nonnull)())block;

+ (void)storeServerToken:(NSString *_Nonnull)authToken signalingKey:(NSString *_Nonnull)signalingKey withProtocolContext:(nullable id)protocolContext;
+(void)removeServerTokenAndSignalingKeyWithProtocolContext:(nullable id)protocolContext;

- (void)storeLocalNumber:(NSString *_Nonnull)localNumber withProtocolContext:(nullable id)protocolContext;
- (void)storeDeviceId:(NSNumber *_Nonnull)deviceId withProtocolContext:(nullable id)protocolContext;

@end
