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

@property (strong) NSString *textSecureURL;

+ (instancetype)sharedInstance;

- (NSString *)getOrgName;
- (void)setOrgName:(NSString *)value;

- (NSString *)getUserName;
- (void)setUserName:(NSString *)value;

- (NSString *)getSessionToken;
- (void)setSessionToken:(NSString *)value;
-(void)removeSessionToken;

- (NSDictionary *)getUserInfo;
- (void)setUserInfo:(NSDictionary *)value;

- (NSDictionary *)getOrgInfo;
- (void)setOrgInfo:(NSDictionary *)value;

- (NSDictionary *)getUsers;
- (void)setUsers:(NSDictionary *)value;

- (NSDictionary *)getTags;
-(void)setTags:(NSDictionary *)value;

@end

#endif /* Storage_h */

/*
 example:
    DDLogInfo(@"user name: %@", [Environment.ccsmStorage getUserName]);
    [Environment.ccsmStorage setUserName:@"gregperk"];
*/
