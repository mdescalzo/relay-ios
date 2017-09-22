//
//  CCSMCommunication.m
//  Forsta
//
//  Created by Greg Perkins on 5/31/17.
//  Copyright © 2017 Forsta. All rights reserved.
//

#import "Environment.h"
#import "CCSMCommunication.h"
#import "DeviceTypes.h"
#import "TSAccountManager.h"
#import "SignalKeyingStorage.h"
#import "SecurityUtils.h"
#import "NSData+Base64.h"
#import "TSStorageManager.h"
#import "TSSocketManager.h"
#import "TSPreKeyManager.h"

@interface CCSMCommManager ()

@property (nullable, nonatomic, retain) NSString *userAwaitingVerification;

@end

@implementation CCSMCommManager

- (void)requestLogin:(NSString *)userName
             orgName:(NSString *)orgName
             success:(void (^)())successBlock
             failure:(void (^)(NSError *error))failureBlock ;
{
    NSString * urlString = [NSString stringWithFormat:@"%@/v1/login/send/%@/%@/?format=json", FLHomeURL, orgName, userName];
    NSURL *url = [NSURL URLWithString:[urlString stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding]];
    NSURLRequest *request = [NSURLRequest requestWithURL:url];
    [NSURLConnection sendAsynchronousRequest:request
                                       queue:[NSOperationQueue mainQueue]
                           completionHandler:^(NSURLResponse *response,
                                               NSData *data, NSError *connectionError)
     {
         NSHTTPURLResponse *HTTPresponse = (NSHTTPURLResponse *)response;
         DDLogDebug(@"Server response code: %ld", (long)HTTPresponse.statusCode);
         DDLogDebug(@"%@",[NSHTTPURLResponse localizedStringForStatusCode:HTTPresponse.statusCode]);
         if (connectionError != nil)  // Failed connection
         {
             failureBlock(connectionError);
         }
         else if (HTTPresponse.statusCode == 200) // SUCCESS!
         {
             NSDictionary *result = [NSJSONSerialization JSONObjectWithData:data
                                                                    options:0
                                                                      error:NULL];
             [[Environment getCurrent].ccsmStorage setOrgName:orgName];
             [[Environment getCurrent].ccsmStorage setUserName:userName];
             DDLogDebug(@"login result's msg is: %@", [result objectForKey:@"msg"]);
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
    NSString *orgName = [[Environment getCurrent].ccsmStorage getOrgName];
    NSString *userName = [[Environment getCurrent].ccsmStorage getUserName];
    NSString * urlString = [NSString stringWithFormat:@"%@/v1/login/authtoken/", FLHomeURL];
    NSURL *url = [NSURL URLWithString:[urlString stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding]];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    [request setHTTPMethod:@"POST"];
    [request setValue:@"application/json" forHTTPHeaderField:@"Accept"];
    NSString *bodyString = [NSString stringWithFormat:@"authtoken=%@:%@:%@", orgName, userName, verificationCode];
    [request setHTTPBody:[bodyString dataUsingEncoding:NSUTF8StringEncoding]];
    [NSURLConnection sendAsynchronousRequest:request
                                       queue:[NSOperationQueue mainQueue]
                           completionHandler:^(NSURLResponse *response,
                                               NSData *data, NSError *connectionError)
     {
         
         NSHTTPURLResponse *HTTPresponse = (NSHTTPURLResponse *)response;
         DDLogDebug(@"Server response code: %ld", (long)HTTPresponse.statusCode);
         DDLogDebug(@"%@",[NSHTTPURLResponse localizedStringForStatusCode:HTTPresponse.statusCode]);
         if (connectionError != nil)  // Failed connection
         {
             failureBlock(connectionError);
         }
         else if (HTTPresponse.statusCode == 200) // SUCCESS!
         {
             NSDictionary *result = [NSJSONSerialization JSONObjectWithData:data
                                                                    options:0
                                                                      error:NULL];
             [[Environment getCurrent].ccsmStorage setSessionToken:[result objectForKey:@"token"]];
             [[Environment getCurrent].ccsmStorage setUserInfo:[result objectForKey:@"user"]];
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
    NSString *sessionToken = [[Environment getCurrent].ccsmStorage getSessionToken];
    NSString *urlString = [NSString stringWithFormat:@"%@/v1/api-token-refresh/", FLHomeURL];
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
    
    DDLogDebug(@"Server response code: %ld", (long)HTTPresponse.statusCode);
    DDLogDebug(@"%@",[NSHTTPURLResponse localizedStringForStatusCode:HTTPresponse.statusCode]);
    
    if (connectionError != nil)  // Failed connection
    {
        failureBlock(connectionError);
    }
    else if (HTTPresponse.statusCode == 200) // SUCCESS!
    {
        NSDictionary *result = [NSJSONSerialization JSONObjectWithData:data
                                                               options:0
                                                                 error:NULL];
        [[Environment getCurrent].ccsmStorage setSessionToken:[result objectForKey:@"token"]];
        [[Environment getCurrent].ccsmStorage setUserInfo:[result objectForKey:@"user"]];
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
    NSString *sessionToken = [[Environment getCurrent].ccsmStorage getSessionToken];
    NSString *urlString = [NSString stringWithFormat:@"%@/v1/api-token-refresh/", FLHomeURL];
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
         DDLogDebug(@"Server response code: %ld", (long)HTTPresponse.statusCode);
         DDLogDebug(@"%@",[NSHTTPURLResponse localizedStringForStatusCode:HTTPresponse.statusCode]);
         
         if (connectionError != nil)  // Failed connection
         {
             failureBlock(connectionError);
         }
         else if (HTTPresponse.statusCode == 200) // SUCCESS!
         {
             NSDictionary *result = [NSJSONSerialization JSONObjectWithData:data
                                                                    options:0
                                                                      error:NULL];
             [[Environment getCurrent].ccsmStorage setSessionToken:[result objectForKey:@"token"]];
             [[Environment getCurrent].ccsmStorage setUserInfo:[result objectForKey:@"user"]];
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
               synchronous:(BOOL)sync
                   success:(void (^)())successBlock
                   failure:(void (^)(NSError *error))failureBlock
{
    NSURL *url = [NSURL URLWithString:[urlString stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding]];
    
    if (sync)
    {
        [self getPageSynchronous:url
                         success:^(NSDictionary *result){
                             NSArray *results = [result objectForKey:@"results"];
                             for (id thing in results) {
                                 [collection setValue:thing forKey:[thing valueForKey:@"id"]];
                             }
                             NSString *next = [result valueForKey:@"next"];
                             if (next && (NSNull *)next != [NSNull null]) {
                                 [self updateAllTheThings:next
                                               collection:collection
                                              synchronous:sync
                                                  success:successBlock
                                                  failure:failureBlock];
                             } else {
                                 successBlock();
                             }
                         }
                         failure:^(NSError *err){
                             failureBlock(err);
                         }];
    }
    else
    {
        [self getPage:url
              success:^(NSDictionary *result){
                  NSArray *results = [result objectForKey:@"results"];
                  for (id thing in results) {
                      [collection setValue:thing forKey:[thing valueForKey:@"id"]];
                  }
                  NSString *next = [result valueForKey:@"next"];
                  if (next && (NSNull *)next != [NSNull null]) {
                      [self updateAllTheThings:next
                                    collection:collection
                                   synchronous:sync
                                       success:successBlock
                                       failure:failureBlock];
                  } else {
                      successBlock();
                  }
              }
              failure:^(NSError *err){
                  failureBlock(err);
              }];
    }
}

- (void)getPageSynchronous:(NSURL *)url
                   success:(void (^)(NSDictionary *result))successBlock
                   failure:(void (^)(NSError *error))failureBlock
{
    NSString *sessionToken = [[Environment getCurrent].ccsmStorage getSessionToken];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    [request setHTTPMethod:@"GET"];
    [request setValue:@"application/json" forHTTPHeaderField:@"Accept"];
    [request addValue:[NSString stringWithFormat:@"JWT %@", sessionToken] forHTTPHeaderField:@"Authorization"];
    
    
    NSHTTPURLResponse *HTTPresponse;
    NSError *connectionError;
    NSData *data = [NSURLConnection sendSynchronousRequest:request
                                         returningResponse:&HTTPresponse
                                                     error:&connectionError];
    
    DDLogDebug(@"Server response code: %ld", (long)HTTPresponse.statusCode);
    DDLogDebug(@"%@",[NSHTTPURLResponse localizedStringForStatusCode:HTTPresponse.statusCode]);
    
    if (connectionError != nil)  // Failed connection
    {
        failureBlock(connectionError);
    }
    else if (HTTPresponse.statusCode == 200) // SUCCESS!
    {
        NSDictionary *result = [NSJSONSerialization JSONObjectWithData:data
                                                               options:0
                                                                 error:NULL];
        successBlock(result);
    }
    else  // Connection good, error from server
    {
        NSError *error = [NSError errorWithDomain:NSURLErrorDomain
                                             code:HTTPresponse.statusCode
                                         userInfo:@{NSLocalizedDescriptionKey:[NSHTTPURLResponse localizedStringForStatusCode:HTTPresponse.statusCode]}];
        failureBlock(error);
    }
}


- (void)getPage:(NSURL *)url
        success:(void (^)(NSDictionary *result))successBlock
        failure:(void (^)(NSError *error))failureBlock
{
    NSString *sessionToken = [[Environment getCurrent].ccsmStorage getSessionToken];
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


- (void)getThing:(NSString *)urlString
     synchronous:(BOOL)synchronous
         success:(void (^)(NSDictionary *))successBlock
         failure:(void (^)(NSError *error))failureBlock;
{
    NSURL *url = [NSURL URLWithString:[urlString stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding]];
    NSString *sessionToken = [[Environment getCurrent].ccsmStorage getSessionToken];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    [request setHTTPMethod:@"GET"];
    [request setValue:@"application/json" forHTTPHeaderField:@"Accept"];
    [request addValue:[NSString stringWithFormat:@"JWT %@", sessionToken] forHTTPHeaderField:@"Authorization"];
    
    if (synchronous) {
        
        NSHTTPURLResponse *HTTPresponse;
        NSError *connectionError;
        NSData *data = [NSURLConnection sendSynchronousRequest:request
                                             returningResponse:&HTTPresponse
                                                         error:&connectionError];
        
        if (connectionError != nil)  // Failed connection
        {
            failureBlock(connectionError);
        }
        else if (HTTPresponse.statusCode == 200) // SUCCESS!
        {
            NSDictionary *result = [NSJSONSerialization JSONObjectWithData:data
                                                                   options:0
                                                                     error:NULL];
            successBlock(result);
        }
        else  // Connection good, error from server
        {
            NSError *error = [NSError errorWithDomain:NSURLErrorDomain
                                                 code:HTTPresponse.statusCode
                                             userInfo:@{NSLocalizedDescriptionKey:[NSHTTPURLResponse localizedStringForStatusCode:HTTPresponse.statusCode]}];
            failureBlock(error);
        }
        
    } else {
        
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
}

-(void)refreshCCSMData
{
    [self refreshCCSMUsers];
    [self refreshCCSMtags];
}

-(void)refreshCCSMUsers
{
    
    NSMutableDictionary *users = [NSMutableDictionary new];
    
    [self updateAllTheThings:[NSString stringWithFormat:@"%@/v1/user/", FLHomeURL]
                  collection:users
                 synchronous:YES
                     success:^{
                         DDLogDebug(@"Refreshed all users.");
                         [[Environment getCurrent].ccsmStorage setUsers:[NSDictionary dictionaryWithDictionary:users]];
                         [self notifyOfUsersRefresh];
                     }
                     failure:^(NSError *err){
                         DDLogError(@"Failed to refresh all users. Error: %@", err.localizedDescription);
                     }];
}

-(void)refreshCCSMtags
{
    NSMutableDictionary *tags = [NSMutableDictionary new];
    
    [self updateAllTheThings:[NSString stringWithFormat:@"%@/v1/tag/", FLHomeURL]
                  collection:tags
                 synchronous:YES
                     success:^{
                         NSMutableDictionary *holdingDict = [NSMutableDictionary new];
                         for (NSDictionary *tagDict in [tags allValues]) {
                             if (![[tagDict objectForKey:@"slug"] isEqualToString:@"."]) {
                                 [holdingDict setObject:[tagDict objectForKey:@"id"] forKey:[tagDict objectForKey:@"slug"]];
                             }
                         }
                         [[Environment getCurrent].ccsmStorage setTags:[NSDictionary dictionaryWithDictionary:holdingDict]];
                         [self notifyOfTagsRefresh];
                         DDLogDebug(@"Refreshed all tags.");
                    }
                     failure:^(NSError *err){
                         DDLogError(@"Failed to refresh all tags. Error: %@", err.localizedDescription);
                     }];
}

-(void)notifyOfUsersRefresh
{
    [[NSNotificationCenter defaultCenter] postNotificationName:FLCCSMUsersUpdated object:nil];
}

-(void)notifyOfTagsRefresh
{
    [[NSNotificationCenter defaultCenter] postNotificationName:FLCCSMTagsUpdated object:nil];
}


#pragma mark - CCSM proxied TextSecure registration
-(void)registerWithTSSViaCCSMForUserID:(NSString *)userID
                               success:(void (^)())successBlock
                               failure:(void (^)(NSError *error))failureBlock
{
    NSString *urlString = [NSString stringWithFormat:@"%@/v1/provision-proxy/", FLHomeURL];
    NSURL *url = [NSURL URLWithString:[urlString stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding]];
    
    NSString *authToken = [[Environment getCurrent].ccsmStorage getSessionToken];
    
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    [request setHTTPMethod:@"PUT"];
    [request setValue:@"application/json; charset=utf-8" forHTTPHeaderField:@"Content-Type"];
    
    [request setValue:[NSString stringWithFormat:@"JWT %@", authToken] forHTTPHeaderField:@"Authorization"];
    
    NSData *signalingKeyToken = [SecurityUtils generateRandomBytes:52];
    NSString *signalingKey = [[NSData dataWithData:signalingKeyToken] base64EncodedString];
    
    NSString *deviceName = [DeviceTypes deviceModelName];
    [SignalKeyingStorage generateServerAuthPassword];
    NSString *password = [SignalKeyingStorage serverAuthPassword];
    
    NSDictionary *bodyDict = @{ @"signalingKey": signalingKey,
                                @"supportSms" : @NO,
                                @"fetchesMessages" : @YES,
                                @"registrationId" :[NSNumber numberWithUnsignedInteger:[TSAccountManager getOrGenerateRegistrationId]],
                                @"deviceName" : deviceName,
                                @"password" : password
                                };
    
    NSData *bodyData = [NSJSONSerialization dataWithJSONObject:bodyDict options:0 error:nil];
    [request setHTTPBody:bodyData];
    
    [NSURLConnection sendAsynchronousRequest:request
                                       queue:[NSOperationQueue mainQueue]
                           completionHandler:^(NSURLResponse *response,
                                               NSData *data, NSError *connectionError)
     {
         
         NSHTTPURLResponse *HTTPresponse = (NSHTTPURLResponse *)response;
         DDLogDebug(@"Server response code: %ld", (long)HTTPresponse.statusCode);
         DDLogDebug(@"%@",[NSHTTPURLResponse localizedStringForStatusCode:HTTPresponse.statusCode]);
         if (connectionError != nil)  // Failed connection
         {
             failureBlock(connectionError);
         }
         else if (HTTPresponse.statusCode == 200) // SUCCESS!
         {
             if (data.length > 0 && connectionError == nil)
             {
                 NSDictionary *result = [NSJSONSerialization JSONObjectWithData:data
                                                                        options:0
                                                                          error:NULL];
                 successBlock(result);
                 DDLogDebug(@"Results: %@", result);
                 
                 [Environment getCurrent].ccsmStorage.textSecureURL = [result objectForKey:@"serverUrl"];
                 NSString *deviceID = [result objectForKey:@"deviceId"];
                 
                 [TSStorageManager storeServerToken:password signalingKey:signalingKey];
                 [[TSStorageManager sharedManager] storePhoneNumber:userID];
                 [TSSocketManager becomeActiveFromForeground];
                 [TSPreKeyManager registerPreKeysWithSuccess:successBlock failure:failureBlock];
             }
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

-(SignalRecipient *)recipientFromCCSMWithID:(NSString *)userId synchronoous:(BOOL)synchronous
{
    __block SignalRecipient *recipient = nil;
    
    if (userId) {
        NSString *url = [NSString stringWithFormat:@"%@/v1/directory/user/?id=%@", FLHomeURL, userId];
        [self getThing:url
           synchronous:synchronous
               success:^(NSDictionary *payload) {
                   NSArray *tmpArray = [payload objectForKey:@"results"];
                   NSDictionary *results = [tmpArray lastObject];
                   recipient = [SignalRecipient recipientForUserDict:results];
               }
               failure:^(NSError *error) {
                   DDLogDebug(@"CCSM User lookup failed or returned no results.");
               }];
    }
    
    return recipient;
}

-(void)recipientFromCCSMWithID:(NSString *)userId
                                    success:(void (^)(NSDictionary *results))successBlock
                                    failure:(void (^)(NSError *error))failureBlock
{
    if (userId) {
        NSString *url = [NSString stringWithFormat:@"%@/v1/directory/user/?id=%@", FLHomeURL, userId];
        [self getThing:url
           synchronous:NO
               success:^(NSDictionary *result) {
                   successBlock(result);
               }
               failure:^(NSError *error) {
                   DDLogDebug(@"CCSM User lookup failed or returned no results.");
                   failureBlock(error);
               }];
    }
}


@end
