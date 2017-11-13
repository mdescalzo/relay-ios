//
//  FLTagMathService.m
//
//  Created by Mark on 8/28/17.
//  Copyright © 2017 Mark. All rights reserved.
//



#import "FLTagMathService.h"
#import "CCSMStorage.h"

#define FLTagMathPath @"/v1/directory/user/"

@interface FLTagMathService()

@property (nonatomic, strong) NSCache *cache;

@end

@implementation FLTagMathService

+(void)asyncTagLookupWithString:(NSString *_Nonnull)lookupString
                        success:(void (^_Nonnull)(NSDictionary *_Nonnull))successBlock
                        failure:(void (^_Nonnull)(NSError *_Nonnull))failureBlock;
{
    NSMutableURLRequest *request = [self requestForString:lookupString];
    
    [NSURLConnection sendAsynchronousRequest:request
                                       queue:[[NSOperationQueue alloc] init]
                           completionHandler:^(NSURLResponse *response,
                                               NSData *data, NSError *connectionError)
     {
         NSHTTPURLResponse *HTTPresponse = (NSHTTPURLResponse *)response;
         DDLogDebug(@"Tag Math. Server response code: %ld", (long)HTTPresponse.statusCode);
         DDLogDebug(@"%@",[NSHTTPURLResponse localizedStringForStatusCode:HTTPresponse.statusCode]);

         if (connectionError != nil)  // Failed connection
         {
             DDLogDebug(@"Tag Math.  Error: %@", connectionError);
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
     }];
}

+(NSDictionary *_Nullable)syncTagLookupWithString:(NSString *_Nonnull)lookupString
{
    NSMutableURLRequest *request = [self requestForString:lookupString];
    
    NSHTTPURLResponse *HTTPresponse;
    NSError *connectionError;
    NSData *data = [NSURLConnection sendSynchronousRequest:request
                                         returningResponse:&HTTPresponse
                                                     error:&connectionError];
    
    DDLogDebug(@"Server response code: %ld", (long)HTTPresponse.statusCode);
    DDLogDebug(@"%@",[NSHTTPURLResponse localizedStringForStatusCode:HTTPresponse.statusCode]);
    if (connectionError != nil)  // Failed connection
    {
        DDLogDebug(@"Tag Math.  Error: %@", connectionError);
        return nil;
    }
    else if (HTTPresponse.statusCode == 200) // SUCCESS!
    {
        return [NSJSONSerialization JSONObjectWithData:data
                                                               options:0
                                                                 error:NULL];
    }
    else  // Connection good, error from server
    {
        NSError *error = [NSError errorWithDomain:NSURLErrorDomain
                                             code:HTTPresponse.statusCode
                                         userInfo:@{NSLocalizedDescriptionKey:[NSHTTPURLResponse localizedStringForStatusCode:HTTPresponse.statusCode]}];
        DDLogDebug(@"Tag Math.  Error: %@", error);
        return nil;
    }
}

+(NSMutableURLRequest *)requestForString:(NSString *)lookupString
{
    NSString *sessionToken = [[CCSMStorage new] getSessionToken];
    NSString *homeURL = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CCSM_Home_URL"];
    
    NSString *urlString = [NSString stringWithFormat:@"%@%@?expression=%@", homeURL, FLTagMathPath, lookupString];
    NSURL *url = [NSURL URLWithString:[urlString stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding]];
    
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    [request setHTTPMethod:@"GET"];
    [request setValue:@"application/json" forHTTPHeaderField:@"Accept"];
    [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    [request addValue:[NSString stringWithFormat:@"JWT %@", sessionToken] forHTTPHeaderField:@"Authorization"];
    
    return request;
}
@end
