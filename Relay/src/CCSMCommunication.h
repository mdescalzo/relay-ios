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

- (void)refreshSessionTokenSuccess:(void (^)())successBlock
                           failure:(void (^)(NSError *error))failureBlock;

@end

#endif /* CCSMCommunication_h */
