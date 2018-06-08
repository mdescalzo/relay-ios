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

+ (NSString *)signalingKeyWithProtocolContext:(nullable id)protocolContext;

/**
 *  The server auth token allows the TextSecure client to connect to the server
 *
 *  @return server authentication token
 */

+ (NSString *)serverAuthTokenWithProtocolContext:(nullable id)protocolContext;

/**
 *  Registered phone number
 *
 *  @return E164 string of the registered phone number
 */
- (NSString *)localNumberWithProtocolContext:(nullable id)protocolContext;
+ (NSString *)localNumberWithProtocolContext:(nullable id)protocolContext;
- (void)removeLocalNumberWithProtocolContext:(nullable id)protocolContext;
+ (void)removeLocalNumberWithProtocolContext:(nullable id)protocolContext;

/**
 * Registered device ID
 */
+ (NSNumber *)deviceIdWithProtocolContext:(nullable id)protocolContext;
- (NSNumber *)deviceIdWithProtocolContext:(nullable id)protocolContext;

- (void)ifLocalNumberPresent:(BOOL)isPresent withProtocolContext:(nullable id)protocolContext runAsync:(void (^)())block;

+ (void)storeServerToken:(NSString *)authToken signalingKey:(NSString *)signalingKey withProtocolContext:(nullable id)protocolContext;
+(void)removeServerTokenAndSignalingKeyWithProtocolContext:(nullable id)protocolContext;

- (void)storeLocalNumber:(NSString *)localNumber withProtocolContext:(nullable id)protocolContext;
- (void)storeDeviceId:(NSNumber *)deviceId withProtocolContext:(nullable id)protocolContext;

@end
