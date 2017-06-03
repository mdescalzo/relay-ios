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
         NSHTTPURLResponse *HTTPresponse = (NSHTTPURLResponse *)response;
         NSLog(@"Server response code: %ld", (long)HTTPresponse.statusCode);
         NSLog(@"%@",[NSHTTPURLResponse localizedStringForStatusCode:HTTPresponse.statusCode]);
         if (connectionError != nil)  // Failed connection
         {
             failureBlock(connectionError);
         }
         else if (HTTPresponse.statusCode == 200) // SUCCESS!
         {
             NSDictionary *result = [NSJSONSerialization JSONObjectWithData:data
                                                                    options:0
                                                                      error:NULL];
             [Environment.ccsmStorage setOrgName:orgName];
             [Environment.ccsmStorage setUserName:userName];
             NSLog(@"login result's msg is: %@", [result objectForKey:@"msg"]);
             successBlock();
         }
         else  // Connection good, error from server
         {
             NSError *error = [NSError errorWithDomain:NSURLErrorDomain
                                                  code:HTTPresponse.statusCode
                                              userInfo:@{NSLocalizedDescriptionKey:[NSHTTPURLResponse localizedStringForStatusCode:HTTPresponse.statusCode]}];
             failureBlock(error);
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

         NSHTTPURLResponse *HTTPresponse = (NSHTTPURLResponse *)response;
         NSLog(@"Server response code: %ld", (long)HTTPresponse.statusCode);
         NSLog(@"%@",[NSHTTPURLResponse localizedStringForStatusCode:HTTPresponse.statusCode]);
         if (connectionError != nil)  // Failed connection
         {
             failureBlock(connectionError);
         }
         else if (HTTPresponse.statusCode == 200) // SUCCESS!
         {
             NSDictionary *result = [NSJSONSerialization JSONObjectWithData:data
                                                                    options:0
                                                                      error:NULL];
             [Environment.ccsmStorage setSessionToken:[result objectForKey:@"token"]];
             [Environment.ccsmStorage setUserInfo:[result objectForKey:@"user"]];
             // TODO: fetch/sync other goodies, like all of the the user's potential :^)
             successBlock();
         }
         else  // Connection good, error from server
         {
             NSError *error = [NSError errorWithDomain:NSURLErrorDomain
                                                  code:HTTPresponse.statusCode
                                              userInfo:@{NSLocalizedDescriptionKey:[NSHTTPURLResponse localizedStringForStatusCode:HTTPresponse.statusCode]}];
             failureBlock(error);
         }
     }];
}


- (void)refreshSessionTokenSynchronousSuccess:(void (^)())successBlock
                           failure:(void (^)(NSError *error))failureBlock
{
    NSString *sessionToken = [Environment.ccsmStorage getSessionToken];
    NSString *urlString = [NSString stringWithFormat:@"https://ccsm-dev-api.forsta.io/v1/api-token-refresh/"];
    NSURL *url = [NSURL URLWithString:[urlString stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding]];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    [request setHTTPMethod:@"POST"];
    [request setValue:@"application/json" forHTTPHeaderField:@"Accept"];
    NSString *bodyString = [NSString stringWithFormat:@"token=%@", sessionToken];
    [request setHTTPBody:[bodyString dataUsingEncoding:NSUTF8StringEncoding]];
    
    NSHTTPURLResponse *HTTPresponse;
    NSError *connectionError;
    NSData *data = [NSURLConnection sendSynchronousRequest:request
                                         returningResponse:&HTTPresponse
                                                     error:&connectionError];
    
    NSLog(@"Server response code: %ld", (long)HTTPresponse.statusCode);
    NSLog(@"%@",[NSHTTPURLResponse localizedStringForStatusCode:HTTPresponse.statusCode]);
    
    if (connectionError != nil)  // Failed connection
    {
        failureBlock(connectionError);
    }
    else if (HTTPresponse.statusCode == 200) // SUCCESS!
    {
        NSDictionary *result = [NSJSONSerialization JSONObjectWithData:data
                                                               options:0
                                                                 error:NULL];
        [Environment.ccsmStorage setSessionToken:[result objectForKey:@"token"]];
        [Environment.ccsmStorage setUserInfo:[result objectForKey:@"user"]];
        // TODO: fetch/sync other goodies, like all of the the user's potential :^)
        successBlock();
    }
    else  // Connection good, error from server
    {
        NSError *error = [NSError errorWithDomain:NSURLErrorDomain
                                             code:HTTPresponse.statusCode
                                         userInfo:@{NSLocalizedDescriptionKey:[NSHTTPURLResponse localizedStringForStatusCode:HTTPresponse.statusCode]}];
        failureBlock(error);
    }
}

- (void)refreshSessionTokenAsynchronousSuccess:(void (^)())successBlock
                           failure:(void (^)(NSError *error))failureBlock
{
    NSString *sessionToken = [Environment.ccsmStorage getSessionToken];
    NSString *urlString = [NSString stringWithFormat:@"https://ccsm-dev-api.forsta.io/v1/api-token-refresh/"];
    NSURL *url = [NSURL URLWithString:[urlString stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding]];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    [request setHTTPMethod:@"POST"];
    [request setValue:@"application/json" forHTTPHeaderField:@"Accept"];
    NSString *bodyString = [NSString stringWithFormat:@"token=%@", sessionToken];
    [request setHTTPBody:[bodyString dataUsingEncoding:NSUTF8StringEncoding]];
    [NSURLConnection sendAsynchronousRequest:request
                                       queue:[NSOperationQueue mainQueue]
                           completionHandler:^(NSURLResponse *response,
                                               NSData *data, NSError *connectionError)
     {
         
         NSHTTPURLResponse *HTTPresponse = (NSHTTPURLResponse *)response;
         NSLog(@"Server response code: %ld", (long)HTTPresponse.statusCode);
         NSLog(@"%@",[NSHTTPURLResponse localizedStringForStatusCode:HTTPresponse.statusCode]);
         
         if (connectionError != nil)  // Failed connection
         {
             failureBlock(connectionError);
         }
         else if (HTTPresponse.statusCode == 200) // SUCCESS!
         {
             NSDictionary *result = [NSJSONSerialization JSONObjectWithData:data
                                                                    options:0
                                                                      error:NULL];
             [Environment.ccsmStorage setSessionToken:[result objectForKey:@"token"]];
             [Environment.ccsmStorage setUserInfo:[result objectForKey:@"user"]];
             // TODO: fetch/sync other goodies, like all of the the user's potential :^)
             successBlock();
         }
         else  // Connection good, error from server
         {
             NSError *error = [NSError errorWithDomain:NSURLErrorDomain
                                                  code:HTTPresponse.statusCode
                                              userInfo:@{NSLocalizedDescriptionKey:[NSHTTPURLResponse localizedStringForStatusCode:HTTPresponse.statusCode]}];
             failureBlock(error);
         }
         
     }];
}

- (void)updateAllTheThings:(NSString *)urlString
                collection:(NSMutableDictionary *)collection
                   success:(void (^)())successBlock
                   failure:(void (^)(NSError *error))failureBlock
{
    NSURL *url = [NSURL URLWithString:[urlString stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding]];
    
    [self getPage:url
          success:^(NSDictionary *result){
              NSArray *results = [result objectForKey:@"results"];
              for (id thing in results) {
                  [collection setValue:thing forKey:[thing valueForKey:@"id"]];
              }
              NSString *next = [result valueForKey:@"next"];
              if (next && (NSNull *)next != [NSNull null]) {
                  [self updateAllTheThings:next collection:collection success:successBlock failure:failureBlock];
              } else {
                  successBlock();
              }
          }
          failure:^(NSError *err){
              failureBlock(err);
          }];
}

- (void)getPage:(NSURL *)url
        success:(void (^)(NSDictionary *result))successBlock
        failure:(void (^)(NSError *error))failureBlock
{
    NSString *sessionToken = [Environment.ccsmStorage getSessionToken];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    [request setHTTPMethod:@"GET"];
    [request setValue:@"application/json" forHTTPHeaderField:@"Accept"];
    [request addValue:[NSString stringWithFormat:@"JWT %@", sessionToken] forHTTPHeaderField:@"Authorization"];
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
             successBlock(result);
         }
         else if (connectionError != nil) {
             failureBlock(connectionError);
         }
     }];
}

@end
