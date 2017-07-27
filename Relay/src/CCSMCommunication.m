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
             [Environment.ccsmStorage setOrgName:orgName];
             [Environment.ccsmStorage setUserName:userName];
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
    NSString *orgName = [Environment.ccsmStorage getOrgName];
    NSString *userName = [Environment.ccsmStorage getUserName];
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
    NSString *sessionToken = [Environment.ccsmStorage getSessionToken];
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


- (void)getThing:(NSString *)urlString
         success:(void (^)(NSDictionary *))successBlock
         failure:(void (^)(NSError *error))failureBlock;
{
    NSURL *url = [NSURL URLWithString:[urlString stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding]];
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

-(void)refreshCCSMData
{
    [self refreshCCSMUsers];
//    [self refreshCCSMtags];
}

-(void)refreshCCSMUsers
{
    
    NSMutableDictionary *users = [NSMutableDictionary new];
    
    [self updateAllTheThings:[NSString stringWithFormat:@"%@/v1/user/", FLHomeURL]
                  collection:users
                 synchronous:YES
                     success:^{
                         DDLogDebug(@"Refreshed all users.");
                         [Environment.ccsmStorage setUsers:[NSDictionary dictionaryWithDictionary:users]];
                         [self notifyOfUsersRefresh];
#warning Tags notification needs to leave here when group tags are implemented
                         [self notifyOfTagsRefresh];
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
                         DDLogDebug(@"Refreshed all tags.");
                         [Environment.ccsmStorage setTags:[NSDictionary dictionaryWithDictionary:tags]];
                         [self notifyOfTagsRefresh];
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

@end
