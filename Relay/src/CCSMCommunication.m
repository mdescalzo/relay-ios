//
//  CCSMCommunication.m
//  Forsta
//
//  Created by Greg Perkins on 5/31/17.
//  Copyright © 2017 Forsta. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "Environment.h"
#import "CCSMCommunication.h"

@interface CCSMCommManager ()

@property (nullable, nonatomic, retain) NSString *userAwaitingVerification;

@end

@implementation CCSMCommManager

/*
- (void)verifyLogin:(NSString *)verificationCode
            success:(void (^)())successBlock
            failure:(void (^)(NSError *error))failureBlock
{
    NSString *userName = [Environment.ccsmStorage getUserName];
    NSString *orgName = [Environment.ccsmStorage getOrgName];
    
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
                                         [TSStorageManager storeServerToken:authToken signalingKey:signalingKey];
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
*/

- (void)requestLogin:(NSString *)userName
             orgName:(NSString *)orgName
             success:(void (^)())successBlock
             failure:(void (^)(NSError *error))failureBlock ;
{
    NSString * urlString = [NSString stringWithFormat:@"https://ccsm-dev-api.forsta.io/v1/login/send/%@/%@/?format=json", orgName, userName];
    NSURL *url = [NSURL URLWithString:[urlString stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding]];
    NSURLRequest *request = [NSURLRequest requestWithURL:url];
    [NSURLConnection sendAsynchronousRequest:request
                                       queue:[NSOperationQueue mainQueue]
                           completionHandler:^(NSURLResponse *response,
                                               NSData *data, NSError *connectionError)
     {
         if (data.length > 0 && connectionError == nil)
         {
             NSDictionary *result = [NSJSONSerialization JSONObjectWithData:data
                                                                    options:0
                                                                      error:NULL];
             [Environment.ccsmStorage setOrgName:orgName];
             [Environment.ccsmStorage setUserName:userName];
    
             successBlock();
         } else if (connectionError != nil) {
             failureBlock(connectionError);
         }
     }];
}

- (void)verifyLogin:(NSString *)verificationCode
            success:(void (^)())successBlock
            failure:(void (^)(NSError *error))failureBlock
{
    NSString *orgName = [Environment.ccsmStorage getOrgName];
    NSString *userName = [Environment.ccsmStorage getUserName];
    NSString * urlString = [NSString stringWithFormat:@"https://ccsm-dev-api.forsta.io/v1/login/authtoken/"];
    NSURL *url = [NSURL URLWithString:[urlString stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding]];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    [request setHTTPMethod:@"POST"];
    [request setValue:@"application/json" forHTTPHeaderField:@"Accept"];
    // soon: NSString *bodyString = [NSString stringWithFormat:@"authtoken=%@:%@:%@", orgname, userName, verificationCode];
    NSString *bodyString = [NSString stringWithFormat:@"authtoken=%@:%@", userName, verificationCode];
    [request setHTTPBody:[bodyString dataUsingEncoding:NSUTF8StringEncoding]];
    [NSURLConnection sendAsynchronousRequest:request
                                       queue:[NSOperationQueue mainQueue]
                           completionHandler:^(NSURLResponse *response,
                                               NSData *data, NSError *connectionError)
     {
         if (data.length > 0 && connectionError == nil)
         {
             NSDictionary *result = [NSJSONSerialization JSONObjectWithData:data
                                                                    options:0
                                                                      error:NULL];
             [Environment.ccsmStorage setSessionKey:[result objectForKey:@"token"]];
             [Environment.ccsmStorage setUserInfo:[result objectForKey:@"user"]];
             // TODO: fetch/sync other goodies, like all of the the user's potential :^)
             successBlock();
         } else if (connectionError != nil) {
             failureBlock(connectionError);
         }
     }];
}

@end
