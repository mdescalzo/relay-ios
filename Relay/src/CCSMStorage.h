//
//  CCSMStorage.h
//  Forsta
//
//  Created by Greg Perkins on 5/27/17.
//  Copyright © 2017 Forsta. All rights reserved.
//

#ifndef CCSMStorage_h
#define CCSMStorage_h

@interface CCSMStorage : NSObject

- (NSString *)getOrgName;
- (void)setOrgName:(NSString *)value;

- (NSString *)getUserName;
- (void)setUserName:(NSString *)value;

- (NSString *)getSessionToken;
- (void)setSessionToken:(NSString *)value;

- (NSDictionary *)getUserInfo;
- (void)setUserInfo:(NSDictionary *)value;

@end

#endif /* Storage_h */

/*
 example:
    DDLogInfo(@"user name: %@", [Environment.ccsmStorage getUserName]);
    [Environment.ccsmStorage setUserName:@"gregperk"];
*/
