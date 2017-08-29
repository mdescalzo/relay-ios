//
//  FLTagMathService.m
//
//  Created by Mark on 8/28/17.
//  Copyright © 2017 Mark. All rights reserved.
//

#import "FLTagMathService.h"
#import "Environment.h"

#define FLTagMathPath @"/v1/directory/user/"

@interface FLTagMathService()

@end

@implementation FLTagMathService

-(void)tagLookupWithString:(NSString *)lookupString
{
    NSString *sessionToken = [[Environment getCurrent].ccsmStorage getSessionToken];

    NSString *urlString = [NSString stringWithFormat:@"%@%@?expression=%@", FLHomeURL, FLTagMathPath, lookupString];
    NSURL *url = [NSURL URLWithString:[urlString stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding]];
    
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    [request setHTTPMethod:@"GET"];
    [request setValue:@"application/json" forHTTPHeaderField:@"Accept"];
    [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    [request addValue:[NSString stringWithFormat:@"JWT %@", sessionToken] forHTTPHeaderField:@"Authorization"];
    
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
             [self.delegate failedLookupWithError:connectionError];
         }
         else if (HTTPresponse.statusCode == 200) // SUCCESS!
         {
             NSDictionary *result = [NSJSONSerialization JSONObjectWithData:data
                                                                    options:0
                                                                      error:NULL];
             [self.delegate successfulLookupWithResults:result];
         }
         else  // Connection good, error from server
         {
             NSError *error = [NSError errorWithDomain:NSURLErrorDomain
                                                  code:HTTPresponse.statusCode
                                              userInfo:@{NSLocalizedDescriptionKey:[NSHTTPURLResponse localizedStringForStatusCode:HTTPresponse.statusCode]}];
             [self.delegate failedLookupWithError:error];
         }
     }];
}

@end
