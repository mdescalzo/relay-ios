//
//  CCSMCommunication.h
//  Forsta
//
//  Created by Greg Perkins on 5/31/17.
//  Copyright © 2017 Forsta. All rights reserved.
//

#ifndef CCSMCommunication_h
#define CCSMCommunication_h

//#import <Foundation/Foundation.h>

@class SignalRecipient;

@interface CCSMCommManager : NSObject

+(void)refreshCCSMData;
//+(void)refreshCCSMUsers;
//+(void)refreshCCSMTags;

+(void)requestLogin:(NSString *)userName
             orgName:(NSString *)orgName
             success:(void (^)())successBlock
             failure:(void (^)(NSError *error))failureBlock ;

+(void)verifySMSCode:(NSString *)verificationCode
        completion:(void (^)(BOOL success, NSError *error))completionBlock;

+(void)authenticateWithPayload:(NSDictionary *)payload
                    completion:(void (^)(BOOL success, NSError *error))completionBlock;

+(void)refreshSessionTokenAsynchronousSuccess:(void (^)())successBlock
                                       failure:(void (^)(NSError *error))failureBlock;

+(void)getThing:(NSString *)urlString
         success:(void (^)(NSDictionary *))successBlock
         failure:(void (^)(NSError *error))failureBlock;

+(void)checkAccountRegistrationWithCompletion:(void (^)(NSDictionary *response, NSError *error))completionBlock;

+(void)registerDeviceWithParameters:(NSDictionary *)parameters
                         completion:(void (^)(NSDictionary *response, NSError *error))completionBlock;

+(void)registerAccountWithParameters:(NSDictionary *)parameters
                      completion:(void (^)(NSDictionary *response, NSError *error))completionBlock;

+(void)requestAccountCreationWithUserDict:(NSDictionary *)userDict
                                    token:(NSString *)token
                               completion:(void (^)(BOOL success, NSError *error))completionBlock;

+(void)sendDeviceProvisioningRequestWithPayload:(NSDictionary *_Nonnull)payload;

// Tag Math lookups
+(void)asyncTagLookupWithString:(NSString *_Nonnull)lookupString
                        success:(void (^_Nonnull)(NSDictionary *_Nonnull))successBlock
                        failure:(void (^_Nonnull)(NSError *_Nonnull))failureBlock;
@end

#endif /* CCSMCommunication_h */
