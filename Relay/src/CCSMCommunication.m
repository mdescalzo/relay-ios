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
#import "TSStorageManager.h"
#import "AFNetworking.h"

@import Fabric;
@import Crashlytics;

@interface CCSMCommManager ()

@property (nullable, nonatomic, strong) NSString *userAwaitingVerification;
@property (nonatomic, strong) NSArray *controlTags;

@end

@implementation CCSMCommManager

+(void)requestLogin:(NSString *)userName
            orgName:(NSString *)orgName
            success:(void (^)())successBlock
            failure:(void (^)(NSError *error))failureBlock ;
{
    NSString *urlString = [NSString stringWithFormat:@"%@/v1/login/send/%@/%@/?format=json", FLHomeURL, orgName, userName];
    NSURL *url = [NSURL URLWithString:[urlString stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding]];
    NSURLRequest *request = [NSURLRequest requestWithURL:url cachePolicy:NSURLRequestReloadIgnoringLocalAndRemoteCacheData timeoutInterval:10];
    NSURLSession *sharedSession = NSURLSession.sharedSession;
    NSURLSessionDataTask *loginTask = [sharedSession dataTaskWithRequest:request
                                                       completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable connectionError)
                                       {
                                           NSHTTPURLResponse *HTTPresponse = (NSHTTPURLResponse *)response;
                                           DDLogDebug(@"Request Login - Server response code: %ld", (long)HTTPresponse.statusCode);
                                           DDLogDebug(@"%@",[NSHTTPURLResponse localizedStringForStatusCode:HTTPresponse.statusCode]);
                                           
                                           NSDictionary *result = nil;
                                           if (data) {  // Grab payload if its there
                                               result = [NSJSONSerialization JSONObjectWithData:data options:0 error:NULL];
                                           }
                                           
                                           if (HTTPresponse.statusCode == 200) // SUCCESS!
                                           {
                                               [Environment.getCurrent.ccsmStorage setOrgName:orgName];
                                               [Environment.getCurrent.ccsmStorage setUserName:userName];
                                               DDLogDebug(@"login result's msg is: %@", [result objectForKey:@"msg"]);
                                               successBlock();
                                           }
                                           else  // Connection good, error from server
                                           {
                                               NSError *error = nil;
                                               if ([result objectForKey:@"non_field_errors"]) {
                                                   NSMutableString *errorDescription = [NSMutableString new];
                                                   for (NSString *message in [result objectForKey:@"non_field_errors"]) {
                                                       [errorDescription appendString:[NSString stringWithFormat:@"\n%@", message]];
                                                   }
                                                   error = [NSError errorWithDomain:NSURLErrorDomain
                                                                               code:HTTPresponse.statusCode
                                                                           userInfo:@{ NSLocalizedDescriptionKey : errorDescription }];
                                                   
                                               } else if ([result objectForKey:@"detail"]) {
                                                   error = [NSError errorWithDomain:NSURLErrorDomain
                                                                               code:HTTPresponse.statusCode
                                                                           userInfo:@{ NSLocalizedDescriptionKey : [result objectForKey:@"detail"] }];
                                               } else {
                                                   error = [NSError errorWithDomain:NSURLErrorDomain
                                                                               code:HTTPresponse.statusCode
                                                                           userInfo:@{NSLocalizedDescriptionKey:[NSHTTPURLResponse localizedStringForStatusCode:HTTPresponse.statusCode]}];
                                               }
                                               failureBlock(error);
                                           }
                                       }];
    
    [sharedSession flushWithCompletionHandler:^{
        [sharedSession resetWithCompletionHandler:^{
            [loginTask resume];
        }];
    }];
    
}

+(void)verifyLogin:(NSString *)verificationCode
           success:(void (^)())successBlock
           failure:(void (^)(NSError *error))failureBlock
{
    // Make URL
    NSString *orgName = [Environment.getCurrent.ccsmStorage getOrgName];
    NSString *userName = [Environment.getCurrent.ccsmStorage getUserName];
    NSString *urlString = [NSString stringWithFormat:@"%@/v1/login/authtoken/", FLHomeURL];
    NSURL *url = [NSURL URLWithString:[urlString stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding]];
    
    // Make Request
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    [request setHTTPMethod:@"POST"];
    [request setValue:@"application/json" forHTTPHeaderField:@"Accept"];
    NSString *bodyString = [NSString stringWithFormat:@"authtoken=%@:%@:%@", orgName, userName, verificationCode];
    [request setHTTPBody:[bodyString dataUsingEncoding:NSUTF8StringEncoding]];
    
    // Make session/session task
    NSURLSession *sharedSession = NSURLSession.sharedSession;
    NSURLSessionTask *validationTask = [sharedSession dataTaskWithRequest:request
                                                        completionHandler:^(NSData * _Nullable data,
                                                                            NSURLResponse * _Nullable response,
                                                                            NSError * _Nullable connectionError) {
                                                            NSHTTPURLResponse *HTTPresponse = (NSHTTPURLResponse *)response;
                                                            DDLogDebug(@"Verify Login - Server response code: %ld", (long)HTTPresponse.statusCode);
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
                                                                [self storeLocalUserDataWithPayload:result];
                                                                
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
    
    [sharedSession flushWithCompletionHandler:^{
        [sharedSession resetWithCompletionHandler:^{
            [validationTask resume];
        }];
    }];
    
}


+(void)refreshSessionTokenSynchronousSuccess:(void (^)())successBlock
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
    
    NSData *data = [self sendSynchronousRequest:request
                              returningResponse:&HTTPresponse
                                          error:&connectionError];
    
    DDLogDebug(@"Refresh Token - Server response code: %ld", (long)HTTPresponse.statusCode);
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
        [self storeLocalUserDataWithPayload:result];
        
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

+(void)refreshSessionTokenAsynchronousSuccess:(void (^)())successBlock
                                      failure:(void (^)(NSError *error))failureBlock
{
    NSString *sessionToken = [Environment.getCurrent.ccsmStorage getSessionToken];
    NSString *urlString = [NSString stringWithFormat:@"%@/v1/api-token-refresh/", FLHomeURL];
    NSURL *url = [NSURL URLWithString:[urlString stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding]];
    
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    [request setHTTPMethod:@"POST"];
    [request setValue:@"application/json" forHTTPHeaderField:@"Accept"];
    NSString *bodyString = [NSString stringWithFormat:@"token=%@", sessionToken];
    [request setHTTPBody:[bodyString dataUsingEncoding:NSUTF8StringEncoding]];
    
    [[NSURLSession.sharedSession dataTaskWithRequest:request
                                   completionHandler:^(NSData * _Nullable data,
                                                       NSURLResponse * _Nullable response,
                                                       NSError * _Nullable connectionError) {
                                       NSHTTPURLResponse *HTTPresponse = (NSHTTPURLResponse *)response;
                                       DDLogDebug(@"Refresh Session Token - Server response code: %ld", (long)HTTPresponse.statusCode);
                                       DDLogDebug(@"%@",[NSHTTPURLResponse localizedStringForStatusCode:HTTPresponse.statusCode]);
                                       
                                       NSDictionary *result = nil;
                                       if (data) {
                                           result = [NSJSONSerialization JSONObjectWithData:data options:0 error:NULL];
                                       }
                                       
                                       if (connectionError != nil)  // Failed connection
                                       {
                                           failureBlock(connectionError);
                                       }
                                       else if (HTTPresponse.statusCode == 200) // SUCCESS!
                                       {
                                           [self storeLocalUserDataWithPayload:result];
                                           
                                           successBlock();
                                       }
                                       else  // Connection good, error from server
                                       {
                                           NSMutableString *errorMessage = [NSMutableString new];
                                           if (result) {
                                               NSArray *errorMessages = [result objectForKey:@"non_field_errors"];
                                               for (NSString *message in errorMessages) {
                                                   [errorMessage appendString:[NSString stringWithFormat:@"\n%@", message]];
                                               }
                                           }
                                           
                                           NSError *error = nil;
                                           if (errorMessage.length == 0) {
                                               error = [NSError errorWithDomain:NSURLErrorDomain
                                                                           code:HTTPresponse.statusCode
                                                                       userInfo:@{ NSLocalizedDescriptionKey : [NSHTTPURLResponse localizedStringForStatusCode:HTTPresponse.statusCode] }];
                                           } else {
                                               error = [NSError errorWithDomain:NSURLErrorDomain
                                                                           code:HTTPresponse.statusCode
                                                                       userInfo:@{ NSLocalizedDescriptionKey : errorMessage }];
                                           }
                                           
                                           failureBlock(error);
                                       }
                                       
                                   }] resume];
}

+(void)updateAllTheThings:(NSString *)urlString
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

+(void)getPageSynchronous:(NSURL *)url
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
    
    NSData *data = [self sendSynchronousRequest:(NSURLRequest *)request
                              returningResponse:&HTTPresponse
                                          error:&connectionError];
    
    DDLogDebug(@"Get Page - Server response code: %ld", (long)HTTPresponse.statusCode);
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


+(void)getPage:(NSURL *)url
       success:(void (^)(NSDictionary *result))successBlock
       failure:(void (^)(NSError *error))failureBlock
{
    NSString *sessionToken = [[Environment getCurrent].ccsmStorage getSessionToken];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    [request setHTTPMethod:@"GET"];
    [request setValue:@"application/json" forHTTPHeaderField:@"Accept"];
    [request addValue:[NSString stringWithFormat:@"JWT %@", sessionToken] forHTTPHeaderField:@"Authorization"];
    
    [[NSURLSession.sharedSession dataTaskWithRequest:request
                                   completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable connectionError) {
                                       
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
                                   }] resume];
}


+(void)getThing:(NSString *)urlString
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
        NSData *data = [self sendSynchronousRequest:request
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
        [[NSURLSession.sharedSession dataTaskWithRequest:request
                                       completionHandler:^(NSData * _Nullable data,
                                                           NSURLResponse * _Nullable response,
                                                           NSError * _Nullable connectionError) {
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
                                       }] resume];
    }
}

#pragma mark - Refresh methods
+(void)storeLocalUserDataWithPayload:(NSDictionary *)payload
{
    // TODO: Move this to the account manager
    if (payload) {
        NSDictionary *userDict = [payload objectForKey:@"user"];
        NSString *userID = [userDict objectForKey:@"id"];
        // Check to see if user changed.  If so, wiped the database.
        if (TSStorageManager.localNumber.length > 0 && ![TSStorageManager.localNumber isEqualToString:userID]) {
            [Environment wipeCommDatabase];
            [Environment.getCurrent.ccsmStorage setUsers:@{ }];
            [Environment.getCurrent.ccsmStorage setOrgInfo:@{ }];
            [Environment.getCurrent.ccsmStorage setTags:@{ }];
            [TSStorageManager.sharedManager storePhoneNumber:userID];
        }
        [Environment.getCurrent.ccsmStorage setSessionToken:[payload objectForKey:@"token"]];
        
        [Environment.getCurrent.ccsmStorage setUserInfo:userDict];
        [SignalRecipient getOrCreateRecipientWithUserDictionary:userDict];
        [TSAccountManager.sharedInstance myself];
        
        [CrashlyticsKit setUserName:[Environment.getCurrent.ccsmStorage getUserName]];
        
        NSDictionary *orgDict = [userDict objectForKey:@"org"];
        [[Environment getCurrent].ccsmStorage setOrgInfo:orgDict];
        
        NSString *orgUrl = [orgDict objectForKey:@"url"];
        [self processOrgInfoWithURL:orgUrl];
    }
}

+(void)refreshCCSMData
{
    [self refreshCCSMUsers];
    [self refreshCCSMTags];
}

+(void)refreshCCSMUsers
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

+(void)refreshCCSMTags
{
    NSMutableDictionary *tags = [NSMutableDictionary new];
    
    [self updateAllTheThings:[NSString stringWithFormat:@"%@/v1/tag/", FLHomeURL]
                  collection:tags
                 synchronous:YES
                     success:^{
                         NSMutableDictionary *holdingDict = [NSMutableDictionary new];
                         for (NSString *key in [tags allKeys]) {
                             NSDictionary *dict = [tags objectForKey:key];
                             if (![self.controlTags containsObject:[dict objectForKey:@"slug"]]) {
                                 [holdingDict setObject:dict forKey:key];
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

+(void)processOrgInfoWithURL:(NSString *)urlString
{
    if (urlString.length > 0) {
        [self getThing:urlString
           synchronous:NO
               success:^(NSDictionary *org){
                   DDLogDebug(@"Retrieved org info after login validation");
                   [[Environment getCurrent].ccsmStorage setOrgInfo:org];
                   // Extract and save org prefs
                   NSDictionary *prefsDict = [org objectForKey:@"preferences"];
                   if (prefsDict) {
                       // Currently no prefs to process
                   }
                   DDLogDebug(@"Successfully process Org preferences.");
               }
               failure:^(NSError *err){
                   DDLogDebug(@"Failed to retrieve org info after login validation. Error: %@", err.description);
               }];
    }
}

+(void)notifyOfUsersRefresh
{
    [[NSNotificationCenter defaultCenter] postNotificationName:FLCCSMUsersUpdated object:nil];
}

+(void)notifyOfTagsRefresh
{
    [[NSNotificationCenter defaultCenter] postNotificationName:FLCCSMTagsUpdated object:nil];
}

#pragma mark - CCSM proxied TextSecure registration
+(void)registerWithTSSViaCCSMForUserID:(NSString *)userID
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
    
    NSString *name = [NSString stringWithFormat:@"%@ (%@)", [DeviceTypes deviceModelName], [[UIDevice currentDevice] name]];
    [SignalKeyingStorage generateServerAuthPassword];
    NSString *password = [SignalKeyingStorage serverAuthPassword];
    
    NSDictionary *bodyDict = @{ @"signalingKey": signalingKey,
                                @"supportSms" : @NO,
                                @"fetchesMessages" : @YES,
                                @"registrationId" :[NSNumber numberWithUnsignedInteger:[TSAccountManager getOrGenerateRegistrationId]],
                                @"name" : name,
                                @"password" : password
                                };
    
    NSData *bodyData = [NSJSONSerialization dataWithJSONObject:bodyDict options:0 error:nil];
    [request setHTTPBody:bodyData];
    
    [[NSURLSession.sharedSession dataTaskWithRequest:request
                                   completionHandler:^(NSData * _Nullable data,
                                                       NSURLResponse * _Nullable response,
                                                       NSError * _Nullable connectionError) {
                                       NSHTTPURLResponse *HTTPresponse = (NSHTTPURLResponse *)response;
                                       DDLogDebug(@"Register with TSS - Server response code: %ld", (long)HTTPresponse.statusCode);
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
                                               DDLogDebug(@"Results: %@", result);
                                               
                                               [Environment getCurrent].ccsmStorage.textSecureURL = [result objectForKey:@"serverUrl"];
                                               NSNumber *deviceID = [result objectForKey:@"deviceId"];
                                               [[TSStorageManager sharedManager] storeDeviceId:deviceID];
                                               [TSStorageManager storeServerToken:password signalingKey:signalingKey];
                                               [[TSStorageManager sharedManager] storePhoneNumber:userID];
                                               [TSSocketManager becomeActiveFromForeground];
                                               [TSPreKeyManager registerPreKeysWithSuccess:successBlock failure:failureBlock];
                                           }
                                       }
                                       else  // Connection good, error from server
                                       {
                                           NSError *error = [NSError errorWithDomain:NSURLErrorDomain
                                                                                code:HTTPresponse.statusCode
                                                                            userInfo:@{NSLocalizedDescriptionKey:[NSHTTPURLResponse localizedStringForStatusCode:HTTPresponse.statusCode]}];
                                           failureBlock(error);
                                       }
                                   }] resume];
    
}

#pragma mark - Lookup methods
+(SignalRecipient *)recipientFromCCSMWithID:(NSString *)userId
{
    __block SignalRecipient *recipient = nil;
    
    [TSStorageManager.sharedManager.dbConnection readWriteWithBlock:^(YapDatabaseReadWriteTransaction * _Nonnull transaction) {
        recipient = [self recipientFromCCSMWithID:userId transaction:transaction];
    }];
    
    return recipient;
}

+(SignalRecipient *)recipientFromCCSMWithID:(NSString *)userId transaction:(YapDatabaseReadWriteTransaction *)transaction
{
    __block SignalRecipient *recipient = nil;
    
    if (userId) {
        NSString *url = [NSString stringWithFormat:@"%@/v1/directory/user/?id=%@", FLHomeURL, userId];
        [self getThing:url
           synchronous:YES
               success:^(NSDictionary *payload) {
                   NSArray *tmpArray = [payload objectForKey:@"results"];
                   NSDictionary *results = [tmpArray lastObject];
                   recipient = [SignalRecipient getOrCreateRecipientWithUserDictionary:results transaction:transaction];
               }
               failure:^(NSError *error) {
                   DDLogDebug(@"CCSM User lookup failed or returned no results.");
               }];
    }
    return recipient;
}

//+(void)asyncRecipientFromCCSMWithID:(NSString *)userId
//                       success:(void (^)(SignalRecipient *recipient))successBlock
//                       failure:(void (^)(NSError *error))failureBlock
//{
//    if (userId) {
//        NSString *url = [NSString stringWithFormat:@"%@/v1/directory/user/?id=%@", FLHomeURL, userId];
//        [self getThing:url
//           synchronous:NO
//               success:^(NSDictionary *result) {
//                   NSArray *payload = [result objectForKey:@"results"];
//                   NSDictionary *userDict = [payload lastObject];
//                   SignalRecipient *recipient = [SignalRecipient recipientForUserDict:userDict];
//                   successBlock(recipient);
//               }
//               failure:^(NSError *error) {
//                   DDLogDebug(@"CCSM User lookup failed or returned no results.");
//                   failureBlock(error);
//               }];
//    }
//}

#pragma mark - Public account creation
+(void)requestAccountCreationWithUserDict:(NSDictionary *)userDict
                                  success:(void (^)())successBlock
                                  failure:(void (^)(NSError *error))failureBlock
{
    if ([userDict allKeys].count != 4 &&
        ![[userDict allKeys] containsObject:@"first_name"] &&
        ![[userDict allKeys] containsObject:@"last_name"] &&
        ![[userDict allKeys] containsObject:@"phone"] &&
        ![[userDict allKeys] containsObject:@"email"])
    {
        // Bad payload, bounce
        NSError *error = [NSError errorWithDomain:@"CCSM.Invalid.input" code:9001 userInfo:nil];
        failureBlock(error);
    } else {
        
        NSString *path = [[NSBundle mainBundle] pathForResource:@"Forsta-values" ofType:@"plist"];
        NSFileManager *fileManager = [NSFileManager defaultManager];
        
        if (![fileManager fileExistsAtPath: path])
        {
            DDLogDebug(@"Tokens Not Found.");
        }
        
        NSDictionary *tokenDict = [[NSDictionary alloc] initWithContentsOfFile:path];
        NSString *serviceToken = nil;
        
#ifdef PRODUCTION
        serviceToken = [tokenDict objectForKey:@"SERVICE_PROD_TOKEN"];
#elif STAGE
        serviceToken = [tokenDict objectForKey:@"SERVICE_STAGE_TOKEN"];
#else
        serviceToken = [tokenDict objectForKey:@"SERVICE_DEV_TOKEN"];
#endif
        
        NSString *urlString = [NSString stringWithFormat:@"%@/v1/user/?login=true", FLHomeURL];
        NSURL *url = [NSURL URLWithString:[urlString stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding]];
        
        NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
        [request setHTTPMethod:@"POST"];
        [request setValue:@"application/json; charset=utf-8" forHTTPHeaderField:@"Content-Type"];
        
        [request setValue:[NSString stringWithFormat:@"ServiceToken %@", serviceToken] forHTTPHeaderField:@"Authorization"];
        
        NSData *bodyData = [NSJSONSerialization dataWithJSONObject:userDict options:0 error:nil];
        [request setHTTPBody:bodyData];
        
        [[NSURLSession.sharedSession dataTaskWithRequest:request
                                       completionHandler:^(NSData * _Nullable data,
                                                           NSURLResponse * _Nullable response,
                                                           NSError * _Nullable connectionError) {
             NSHTTPURLResponse *HTTPresponse = (NSHTTPURLResponse *)response;
             DDLogDebug(@"Requst Account Creation - Server response code: %ld", (long)HTTPresponse.statusCode);
             DDLogDebug(@"%@",[NSHTTPURLResponse localizedStringForStatusCode:HTTPresponse.statusCode]);
             if (connectionError != nil)  // Failed connection
             {
                 failureBlock(connectionError);
             }
             else if (HTTPresponse.statusCode >= 200 && HTTPresponse.statusCode <= 204) // SUCCESS!
             {
                 NSDictionary *result = nil;
                 if (data.length > 0 && connectionError == nil)
                 {
                     result = [NSJSONSerialization JSONObjectWithData:data
                                                              options:0
                                                                error:NULL];
                     CCSMStorage *ccsmStore = [CCSMStorage new];
                     NSString *userSlug = [result objectForKey:@"username"];
                     NSDictionary *orgDict = [result objectForKey:@"org"];
                     NSString *orgSlug = [orgDict objectForKey:@"slug"];
                     [ccsmStore setOrgName:orgSlug];
                     [ccsmStore setUserName:userSlug];
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
         }] resume];
    }
}

// Source: https://stackoverflow.com/questions/26784315/can-i-somehow-do-a-synchronous-http-request-via-nsurlsession-in-swift#34308158
+ (NSData *)sendSynchronousRequest:(NSURLRequest *)request
                 returningResponse:(__autoreleasing NSURLResponse **)responsePtr
                             error:(__autoreleasing NSError **)errorPtr {
    dispatch_semaphore_t    sem;
    __block NSData *        result;
    
    result = nil;
    
    sem = dispatch_semaphore_create(0);
    
    [[[NSURLSession sharedSession] dataTaskWithRequest:request
                                     completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
                                         if (errorPtr != NULL) {
                                             *errorPtr = error;
                                         }
                                         if (responsePtr != NULL) {
                                             *responsePtr = response;
                                         }
                                         if (error == nil) {
                                             result = data;
                                         }
                                         dispatch_semaphore_signal(sem);
                                     }] resume];
    
    dispatch_semaphore_wait(sem, DISPATCH_TIME_FOREVER);
    
    return result;
}

#pragma mark - Accessors
+(NSArray *)controlTags
{
    return @[ @".", @"role", @"position" ];
}

@end
