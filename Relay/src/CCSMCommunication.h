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
+(void)refreshCCSMTags;

+(void)requestLogin:(NSString *)userName
             orgName:(NSString *)orgName
             success:(void (^)())successBlock
             failure:(void (^)(NSError *error))failureBlock ;

+(void)verifyLogin:(NSString *)verificationCode
            success:(void (^)())successBlock
            failure:(void (^)(NSError *error))failureBlock;

+(void)refreshSessionTokenAsynchronousSuccess:(void (^)())successBlock
                                       failure:(void (^)(NSError *error))failureBlock;

+(void)refreshSessionTokenSynchronousSuccess:(void (^)())successBlock
                                      failure:(void (^)(NSError *))failureBlock;

+(void)updateAllTheThings:(NSString *)urlString
                collection:(NSMutableDictionary *)collection
               synchronous:(BOOL)sync
                   success:(void (^)())successBlock
                   failure:(void (^)(NSError *error))failureBlock;

+(void)getThing:(NSString *)urlString
     synchronous:(BOOL)synchronous
         success:(void (^)(NSDictionary *))successBlock
         failure:(void (^)(NSError *error))failureBlock;

+(void)registerWithTSSViaCCSMForUserID:(NSString *)userID
                               success:(void (^)())successBlock
                               failure:(void (^)(NSError *error))failureBlock;

//+(void)registerWithTSSViaCCSMForPhone:(NSString *)phone
//                              Success:(void (^)())successBlock
//                              failure:(void (^)(NSError *error))failureBlock;

+(SignalRecipient *)recipientFromCCSMWithID:(NSString *)userId;
+(void)asyncRecipientFromCCSMWithID:(NSString *)userId
                                   success:(void (^)(SignalRecipient *recipient))successBlock
                                    failure:(void (^)(NSError *error))failureBlock;

+(void)requestAccountCreationWithUserDict:(NSDictionary *)userDict
                                  success:(void (^)())successBlock
                                  failure:(void (^)(NSError *error))failureBlock;
@end

#endif /* CCSMCommunication_h */
