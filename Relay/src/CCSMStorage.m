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

@implementation CCSMStorage

NSString *const CCSMStorageDatabaseCollection = @"CCSMInformation";

NSString *const CCSMStorageKeyOrgName = @"Organization Name";
NSString *const CCSMStorageKeyUserName = @"User Name";
NSString *const CCSMStorageKeySessionToken = @"Session Token";
NSString *const CCSMStorageKeyUserInfo = @"User Info";

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



@end
