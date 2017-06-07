//
//  CCSMCommunication.h
//  Forsta
//
//  Created by Greg Perkins on 5/31/17.
//  Copyright © 2017 Forsta. All rights reserved.
//

#ifndef CCSMCommunication_h
#define CCSMCommunication_h

@interface CCSMCommManager : NSObject

- (void)requestLogin:(NSString *)userName
             orgName:(NSString *)orgName
             success:(void (^)())successBlock
             failure:(void (^)(NSError *error))failureBlock ;

- (void)verifyLogin:(NSString *)verificationCode
            success:(void (^)())successBlock
            failure:(void (^)(NSError *error))failureBlock;

- (void)refreshSessionTokenAsynchronousSuccess:(void (^)())successBlock
                           failure:(void (^)(NSError *error))failureBlock;

- (void)refreshSessionTokenSynchronousSuccess:(void (^)())successBlock
                                      failure:(void (^)(NSError *))failureBlock;

- (void)updateAllTheThings:(NSString *)urlString
                collection:(NSMutableDictionary *)collection
                   success:(void (^)())successBlock
                   failure:(void (^)(NSError *error))failureBlock;

- (void)getThing:(NSString *)urlString
         success:(void (^)(NSDictionary *))successBlock
         failure:(void (^)(NSError *error))failureBlock;
@end

#endif /* CCSMCommunication_h */
