//
//  CCSMStorage.m
//  Forsta
//
//  Created by Greg Perkins on 5/27/17.
//  Copyright © 2017 Forsta. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "CCSMStorage.h"
#import "Constraints.h"
#import "TSStorageHeaders.h"

NSDictionary *extractTagsForUsers(NSMutableDictionary *users) {
    NSMutableDictionary *tags = [NSMutableDictionary new];
    for (id userId in users) {
        NSMutableDictionary *user = [users objectForKey:userId];
        for (id usertag in [user objectForKey:@"tags"]) {
            NSString *associationType = [usertag objectForKey:@"association_type"];
            if (![associationType isEqualToString:@"REPORTSTO"]) {
                NSMutableDictionary *tag = [usertag objectForKey:@"tag"];
                NSString *slug = [tag objectForKey:@"slug"];
                if ([tags objectForKey:slug] == nil) {
                    [tags setValue:[NSMutableDictionary new] forKey:slug];
                }
                [[tags objectForKey:slug] setValue:user forKey:userId];
            }
        }
    }
    
    return tags;
}

@implementation CCSMStorage

NSString *const CCSMStorageDatabaseCollection = @"CCSMInformation";

NSString *const CCSMStorageKeyOrgName = @"Organization Name";
NSString *const CCSMStorageKeyUserName = @"User Name";
NSString *const CCSMStorageKeySessionToken = @"Session Token";
NSString *const CCSMStorageKeyUserInfo = @"User Info";
NSString *const CCSMStorageKeyOrgInfo = @"Org Info";
NSString *const CCSMStorageKeyUsers = @"Users";
NSString *const CCSMStorageKeyTags = @"Tags";

- (nullable id)tryGetValueForKey:(NSString *)key
{
    ows_require(key != nil);
    return
    [TSStorageManager.sharedManager objectForKey:key inCollection:CCSMStorageDatabaseCollection];
}

- (void)setValueForKey:(NSString *)key toValue:(nullable id)value
{
    ows_require(key != nil);
    
    [TSStorageManager.sharedManager setObject:value
                                       forKey:key
                                 inCollection:CCSMStorageDatabaseCollection];
}


- (void)setUserName:(NSString *)value
{
    [self setValueForKey:CCSMStorageKeyUserName toValue:value];
}

- (nullable NSString *)getUserName
{
    return [self tryGetValueForKey:CCSMStorageKeyUserName];
}


- (void)setOrgName:(NSString *)value
{
    [self setValueForKey:CCSMStorageKeyOrgName toValue:value];
}

- (nullable NSString *)getOrgName
{
    return [self tryGetValueForKey:CCSMStorageKeyOrgName];
}


- (void)setSessionToken:(NSString *)value
{
    [self setValueForKey:CCSMStorageKeySessionToken toValue:value];
}

- (nullable NSString *)getSessionToken
{
    return [self tryGetValueForKey:CCSMStorageKeySessionToken];
}


- (void)setUserInfo:(NSDictionary *)value
{
    [self setValueForKey:CCSMStorageKeyUserInfo toValue:value];
}

- (nullable NSDictionary *)getUserInfo
{
    return [self tryGetValueForKey:CCSMStorageKeyUserInfo];
}


- (void)setOrgInfo:(NSDictionary *)value
{
    [self setValueForKey:CCSMStorageKeyOrgInfo toValue:value];
}

- (nullable NSDictionary *)getOrgInfo
{
    return [self tryGetValueForKey:CCSMStorageKeyOrgInfo];
}


- (void)setUsers:(NSMutableDictionary *)value
{
    [self setValueForKey:CCSMStorageKeyUsers toValue:value];
    NSDictionary * tags = extractTagsForUsers(value);
    [self setTags:tags];
}

- (nullable NSMutableDictionary *)getUsers
{
    return [self tryGetValueForKey:CCSMStorageKeyUsers];
}


- (void)setTags:(NSDictionary *)value
{
    [self setValueForKey:CCSMStorageKeyTags toValue:value];
}

- (nullable NSDictionary *)getTags
{
    return [self tryGetValueForKey:CCSMStorageKeyTags];
}

@end
