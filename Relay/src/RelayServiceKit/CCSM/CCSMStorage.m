//
//  CCSMStorage.m
//  Forsta
//
//  Created by Greg Perkins on 5/27/17.
//  Copyright © 2017 Forsta. All rights reserved.
//

#import "CCSMStorage.h"
#import "Constraints.h"
#import "TSStorageHeaders.h"

#import <Foundation/Foundation.h>

//NSDictionary *extractTagsForUsers(NSMutableDictionary *users) {
//    NSMutableDictionary *tags = [NSMutableDictionary new];
//    for (id userId in users) {
//        NSMutableDictionary *user = [users objectForKey:userId];
//        for (id usertag in [user objectForKey:@"tags"]) {
//            NSString *associationType = [usertag objectForKey:@"association_type"];
//            if (![associationType isEqualToString:@"REPORTSTO"]) {
//                NSMutableDictionary *tag = [usertag objectForKey:@"tag"];
//                NSString *slug = [tag objectForKey:@"slug"];
//                if ([tags objectForKey:slug] == nil) {
//                    [tags setValue:[NSMutableDictionary new] forKey:slug];
//                }
//                [[tags objectForKey:slug] setValue:user forKey:userId];
//            }
//        }
//    }
//    
//    return [NSDictionary dictionaryWithDictionary:tags];
//}

@interface CCSMStorage()

@property (strong) YapDatabaseConnection *dbConnection;

@end

@implementation CCSMStorage

@synthesize textSecureURL = _textSecureURL;
@synthesize dbConnection = _dbConnection;


NSString *const CCSMStorageDatabaseCollection = @"CCSMInformation";

NSString *const CCSMStorageKeyOrgName = @"Organization Name";
NSString *const CCSMStorageKeyUserName = @"User Name";
NSString *const CCSMStorageKeySessionToken = @"Session Token";
NSString *const CCSMStorageKeyUserInfo = @"User Info";
NSString *const CCSMStorageKeyOrgInfo = @"Org Info";
NSString *const CCSMStorageKeyUsers = @"Users";
NSString *const CCSMStorageKeyTags = @"Tags";
NSString *const CCSMStorageKeyTSServerURL = @"TSServerURL";

-(instancetype)init
{
    if (self = [super init]) {
        _dbConnection = [TSStorageManager.sharedManager newDatabaseConnection];
    }
    return self;
}

- (nullable id)tryGetValueForKey:(NSString *_Nonnull)key
{
//    return [TSStorageManager.sharedManager objectForKey:key inCollection:CCSMStorageDatabaseCollection];
    __block id returnVal = nil;
    [self.dbConnection readWithBlock:^(YapDatabaseReadTransaction *transaction) {
        returnVal = [transaction objectForKey:key inCollection:CCSMStorageDatabaseCollection];
    }];
    return returnVal;
}

- (void)setValueForKey:(NSString *)key toValue:(nullable id)value
{
    ows_require(key != nil);
    
    [self.dbConnection readWriteWithBlock:^(YapDatabaseReadWriteTransaction *transaction) {
        [transaction setObject:value forKey:key inCollection:CCSMStorageDatabaseCollection];
    }];
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

-(void)removeSessionToken
{
    [self.dbConnection readWriteWithBlock:^(YapDatabaseReadWriteTransaction *transaction) {
        [transaction objectForKey:CCSMStorageKeySessionToken inCollection:CCSMStorageDatabaseCollection];
    }];
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
//    NSDictionary * tags = [self extractTagsForUsers:value];
//    [self setTags:tags];
}

- (nullable NSMutableDictionary *)getUsers
{
    return [self tryGetValueForKey:CCSMStorageKeyUsers];
}


- (void)setTags:(NSDictionary *)value
{
    [self setValueForKey:CCSMStorageKeyTags toValue:value];
    // Process the newly received blob
    //    NSDictionary *tagBlob = [Environment.getCurrent.ccsmStorage getTags];
    [self.dbConnection asyncReadWriteWithBlock:^(YapDatabaseReadWriteTransaction * _Nonnull transaction) {
        [[value allValues] enumerateObjectsUsingBlock:^(id  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
            NSDictionary *tagDict = (NSDictionary *)obj;
            FLTag *aTag = [FLTag getOrCreateTagWithDictionary:tagDict transaction:transaction];
            if (aTag.recipientIds.count == 0) {
                [aTag removeWithTransaction:transaction];
            }
        }];
    }];
}

- (nullable NSDictionary *)getTags
{
    return [self tryGetValueForKey:CCSMStorageKeyTags];
}

-(NSString *)textSecureURL
{
    if (_textSecureURL == nil) {
        _textSecureURL = [self tryGetValueForKey:CCSMStorageKeyTSServerURL];
    }
    return _textSecureURL;
}

-(void)setTextSecureURL:(NSString *)value
{
    if (![_textSecureURL isEqualToString:value]) {
        _textSecureURL = [value copy];
        [self setValueForKey:CCSMStorageKeyTSServerURL toValue:value];
    }
}

-(NSDictionary *)extractTagsForUsers:(NSDictionary *) users
{
    NSMutableDictionary *tags = [NSMutableDictionary new];
    
    for (NSString *key in users.allKeys) {
        NSDictionary *userDict = [users objectForKey:key];
        NSDictionary *tagDict = [userDict objectForKey:@"tag"];
        NSString *slug = [tagDict objectForKey:@"slug"];
        if (slug) {
            [tags setObject:key forKey:slug];
        }
    }
    
    return [NSDictionary dictionaryWithDictionary:tags];
}

@end
