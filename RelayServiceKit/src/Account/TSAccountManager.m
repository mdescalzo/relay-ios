//
//  TSAccountManagement.m
//  TextSecureKit
//
//  Created by Frederic Jacobs on 27/10/14.
//  Copyright (c) 2014 Open Whisper Systems. All rights reserved.
//

#import "TSAccountManager.h"
#import "NSData+Base64.h"
#import "NSData+hexString.h"
#import "NSURLSessionDataTask+StatusCode.h"
#import "OWSError.h"
#import "SecurityUtils.h"
#import "TSNetworkManager.h"
#import "TSPreKeyManager.h"
#import "TSSocketManager.h"
#import "TSStorageManager+keyingMaterial.h"


NS_ASSUME_NONNULL_BEGIN

@interface TSAccountManager ()

@property (nullable, nonatomic, retain) NSString *phoneNumberAwaitingVerification;
@property (nonatomic, strong, readonly) TSNetworkManager *networkManager;
@property (nonatomic, strong, readonly) TSStorageManager *storageManager;

@end

@implementation TSAccountManager

- (instancetype)initWithNetworkManager:(TSNetworkManager *)networkManager
                        storageManager:(TSStorageManager *)storageManager
{
    self = [super init];
    if (!self) {
        return self;
    }

    _networkManager = networkManager;
    _storageManager = storageManager;

    return self;
}

+ (instancetype)sharedInstance
{
    static dispatch_once_t onceToken;
    static id sharedInstance = nil;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[self alloc] initWithNetworkManager:[TSNetworkManager sharedManager]
                                               storageManager:[TSStorageManager sharedManager]];
    });

    return sharedInstance;
}

+ (BOOL)isRegistered {
    CCSMStorage *ccsmStore = [CCSMStorage new];
    NSString *sessionToken = [ccsmStore getSessionToken];
    NSNumber *deviceId = [TSStorageManager deviceIdWithProtocolContext:nil];
    
    return (TSAccountManager.sharedInstance.myself.uniqueId && deviceId && sessionToken.length > 0) ? YES : NO;
}

- (void)ifRegistered:(BOOL)isRegistered runAsync:(void (^)())block
{
    [self.storageManager ifLocalNumberPresent:isRegistered withProtocolContext:nil runAsync:block];
}

- (void)didRegister
{
    DDLogInfo(@"%@ didRegister", self.tag);
    NSString *phoneNumber = self.phoneNumberAwaitingVerification;

    if (!phoneNumber) {
        @throw [NSException exceptionWithName:@"RegistrationFail" reason:@"Internal Corrupted State" userInfo:nil];
    }

    [self.storageManager storeLocalNumber:phoneNumber withProtocolContext:nil];
}

+ (nullable NSString *)localNumber
{
    TSAccountManager *sharedManager = [self sharedInstance];
    NSString *awaitingVerif         = sharedManager.phoneNumberAwaitingVerification;
    if (awaitingVerif) {
        return awaitingVerif;
    }

    return [TSStorageManager localNumberWithProtocolContext:nil];
}

+(uint32_t)getOrGenerateRegistrationIdWithProtocolContext:(nullable id)protocolContext
{
    uint32_t registrationID = 0;
    
    registrationID = [[TSStorageManager.sharedManager objectForKey:TSStorageLocalRegistrationId
                                                      inCollection:TSStorageUserAccountCollection
                                               withProtocolContext:protocolContext] unsignedIntValue];
    
    if (registrationID == 0) {
        registrationID = (uint32_t)arc4random_uniform(16380) + 1;
        
        [TSStorageManager.sharedManager setObject:[NSNumber numberWithUnsignedInteger:registrationID]
                        forKey:TSStorageLocalRegistrationId
                  inCollection:TSStorageUserAccountCollection
         withProtocolContext:protocolContext];
    }
    
    return registrationID;
}

- (void)registerForPushNotificationsWithPushToken:(NSString *)pushToken
                                        voipToken:(NSString *)voipToken
                                          success:(void (^)())successHandler
                                          failure:(void (^)(NSError *))failureHandler
{
    TSRegisterForPushRequest *request =
        [[TSRegisterForPushRequest alloc] initWithPushIdentifier:pushToken voipIdentifier:voipToken];

    [self.networkManager makeRequest:request
        success:^(NSURLSessionDataTask *task, id responseObject) {
            successHandler();
        }
        failure:^(NSURLSessionDataTask *task, NSError *error) {
            failureHandler(error);
        }];
}

+ (void)registerWithPhoneNumber:(NSString *)phoneNumber
                        success:(void (^)())successBlock
                        failure:(void (^)(NSError *error))failureBlock
                smsVerification:(BOOL)isSMS

{
    if ([self isRegistered]) {
        failureBlock([NSError errorWithDomain:@"tsaccountmanager.verify" code:4000 userInfo:nil]);
        return;
    }

    [[TSNetworkManager sharedManager]
        makeRequest:[[TSRequestVerificationCodeRequest alloc]
                        initWithPhoneNumber:phoneNumber
                                  transport:isSMS ? TSVerificationTransportSMS : TSVerificationTransportVoice]
        success:^(NSURLSessionDataTask *task, id responseObject) {
            DDLogInfo(@"%@ Successfully requested verification code request for number: %@ method:%@",
                self.tag,
                phoneNumber,
                isSMS ? @"SMS" : @"Voice");
            TSAccountManager *manager = [self sharedInstance];
            manager.phoneNumberAwaitingVerification = phoneNumber;
            successBlock();
        }
        failure:^(NSURLSessionDataTask *task, NSError *error) {
            DDLogError(@"%@ Failed to request verification code request with error:%@", self.tag, error);
            failureBlock(error);
        }];
}

+ (void)rerequestSMSWithSuccess:(void (^)())successBlock failure:(void (^)(NSError *error))failureBlock
{
    TSAccountManager *manager = [self sharedInstance];
    NSString *number          = manager.phoneNumberAwaitingVerification;

    assert(number);

    [self registerWithPhoneNumber:number success:successBlock failure:failureBlock smsVerification:YES];
}

+ (void)rerequestVoiceWithSuccess:(void (^)())successBlock failure:(void (^)(NSError *error))failureBlock
{
    TSAccountManager *manager = [self sharedInstance];
    NSString *number          = manager.phoneNumberAwaitingVerification;

    assert(number);

    [self registerWithPhoneNumber:number success:successBlock failure:failureBlock smsVerification:NO];
}

- (void)verifyAccountWithCode:(NSString *)verificationCode
                      success:(void (^)())successBlock
                      failure:(void (^)(NSError *error))failureBlock
{
    NSString *authToken = [[self class] generateNewAccountAuthenticationToken];
    NSString *signalingKey = [[self class] generateNewSignalingKeyToken];
    NSString *phoneNumber = self.phoneNumberAwaitingVerification;

    assert(signalingKey);
    assert(authToken);
    assert(phoneNumber);

    TSVerifyCodeRequest *request = [[TSVerifyCodeRequest alloc] initWithVerificationCode:verificationCode
                                                                               forNumber:phoneNumber
                                                                            signalingKey:signalingKey
                                                                                 authKey:authToken];

    [self.networkManager makeRequest:request
        success:^(NSURLSessionDataTask *task, id responseObject) {
            NSHTTPURLResponse *response = (NSHTTPURLResponse *)task.response;
            long statuscode = response.statusCode;

            switch (statuscode) {
                case 200:
                case 204: {
                    [TSStorageManager storeServerToken:authToken signalingKey:signalingKey withProtocolContext:nil];
                    [self didRegister];
                    [TSSocketManager becomeActiveFromForeground];
                    [TSPreKeyManager registerPreKeysWithSuccess:successBlock failure:failureBlock];
                    break;
                }
                default: {
                    DDLogError(@"%@ Unexpected status while verifying code: %ld", self.tag, statuscode);
                    NSError *error = OWSErrorMakeUnableToProcessServerResponseError();
                    failureBlock(error);
                    break;
                }
            }
        }
        failure:^(NSURLSessionDataTask *task, NSError *error) {
            DDLogWarn(@"%@ Error verifying code: %@", self.tag, error.debugDescription);
            switch (error.code) {
                case 403: {
                    NSError *userError = OWSErrorWithCodeDescription(OWSErrorCodeUserError,
                        NSLocalizedString(@"REGISTRATION_VERIFICATION_FAILED_WRONG_CODE_DESCRIPTION",
                            "Alert body, during registration"));
                    failureBlock(userError);
                    break;
                }
                default: {
                    DDLogError(@"%@ verifying code failed with unhandled error: %@", self.tag, error);
                    failureBlock(error);
                    break;
                }
            }
        }];
}

#pragma mark Server keying material

+ (NSString *)generateNewAccountAuthenticationToken {
    NSData *authToken        = [SecurityUtils generateRandomBytes:16];
    NSString *authTokenPrint = [[NSData dataWithData:authToken] hexadecimalString];
    return authTokenPrint;
}

+ (NSString *)generateNewSignalingKeyToken {
    /*The signalingKey is 32 bytes of AES material (256bit AES) and 20 bytes of
     * Hmac key material (HmacSHA1) concatenated into a 52 byte slug that is
     * base64 encoded. */
    NSData *signalingKeyToken        = [SecurityUtils generateRandomBytes:52];
    NSString *signalingKeyTokenPrint = [[NSData dataWithData:signalingKeyToken] base64EncodedString];
    return signalingKeyTokenPrint;
}

+ (void)unregisterTextSecureWithSuccess:(void (^)())success failure:(void (^)(NSError *error))failureBlock
{
    [[TSNetworkManager sharedManager] makeRequest:[[TSUnregisterAccountRequest alloc] init]
        success:^(NSURLSessionDataTask *task, id responseObject) {
            DDLogInfo(@"%@ Successfully unregistered", self.tag);
            [[[self class] sharedInstance] setMyself:nil];
            success();
        }
        failure:^(NSURLSessionDataTask *task, NSError *error) {
            DDLogError(@"%@ Failed to unregister with error: %@", self.tag, error);
            failureBlock(error);
        }];
}

-(SignalRecipient *_Nullable)myself
{
    if (_myself == nil || _myself.fullName.length == 0) {
        _myself = [SignalRecipient fetchObjectWithUniqueID:[self.class localNumber]];
    }

    return _myself;
}

#pragma mark - Logging

+ (NSString *)tag
{
    return [NSString stringWithFormat:@"[%@]", self.class];
}

- (NSString *)tag
{
    return self.class.tag;
}

@end

NS_ASSUME_NONNULL_END
