//  Created by Frederic Jacobs on 17/11/14.
//  Copyright (c) 2014 Open Whisper Systems. All rights reserved.

#import "SignalRecipient.h"
#import "TSStorageHeaders.h"
#import "TSAccountManager.h"
#import "TSStorageManager+IdentityKeyStore.h"

NS_ASSUME_NONNULL_BEGIN

@interface SignalRecipient()

@end

@implementation SignalRecipient

+ (NSString *)collection {
    return @"SignalRecipient";
}

- (instancetype)initWithTextSecureIdentifier:(NSString *)textSecureIdentifier
                                       relay:(nullable NSString *)relay
                               supportsVoice:(BOOL)voiceCapable
{
    self = [super initWithUniqueId:textSecureIdentifier];
    if (!self) {
        return self;
    }
    
    _devices = [NSMutableOrderedSet orderedSetWithObject:[NSNumber numberWithInt:1]];
    _relay = [relay isEqualToString:@""] ? nil : relay;
    
    return self;
}

-(instancetype)initWithTextSecureIdentifier:(NSString *)textSecureIdentifier
                                  firstName:(NSString *)firstName
                                   lastName:(NSString *)lastName
{
    if ([super initWithUniqueId:textSecureIdentifier]) {
        _firstName = firstName;
        _lastName = lastName;
    }
    return self;
}

+(instancetype)getOrCreateRecipientWithIndentifier:(NSString *)identifier
{
    __block SignalRecipient *recipient = nil;
    [[SignalRecipient dbConnection] readWriteWithBlock:^(YapDatabaseReadWriteTransaction *transaction) {
        recipient = [self getOrCreateRecipientWithIndentifier:identifier withTransaction:transaction];
    }];
    return recipient;
}

+(instancetype)getOrCreateRecipientWithIndentifier:(NSString *)identifier
                                   withTransaction:(YapDatabaseReadWriteTransaction *)transaction
{
    SignalRecipient *recipient = [SignalRecipient fetchObjectWithUniqueID:identifier transaction:transaction];
    if (!recipient) {
        recipient = [[SignalRecipient alloc] initWithUniqueId:identifier];
        [recipient saveWithTransaction:transaction];
    }
    return recipient;
}


+ (nullable instancetype)recipientWithTextSecureIdentifier:(NSString *)textSecureIdentifier
                                           withTransaction:(YapDatabaseReadTransaction *)transaction
{
    return [self fetchObjectWithUniqueID:textSecureIdentifier transaction:transaction];
}

+ (nullable instancetype)recipientWithTextSecureIdentifier:(NSString *)textSecureIdentifier
{
    __block SignalRecipient *recipient;
    [self.dbConnection readWithBlock:^(YapDatabaseReadTransaction *_Nonnull transaction) {
        recipient = [self recipientWithTextSecureIdentifier:textSecureIdentifier withTransaction:transaction];
        
        // If nothing local, look it up on CCSM:
        if (recipient == nil) {
            recipient = [CCSMCommManager recipientFromCCSMWithID:textSecureIdentifier];
        }
    }];
    return recipient;
}

+ (instancetype)selfRecipient
{
    SignalRecipient *myself = TSAccountManager.sharedInstance.myself;
    if (!myself) {
        myself = [[self alloc] initWithTextSecureIdentifier:TSAccountManager.sharedInstance.myself.uniqueId relay:nil supportsVoice:YES];
    }
    return myself;
}

+(instancetype)getOrCreateRecipientWithUserDictionary:(NSDictionary *)userDict
{
    __block SignalRecipient *recipient = nil;
    [self.dbConnection readWriteWithBlock:^(YapDatabaseReadWriteTransaction * _Nonnull transaction) {
        recipient = [self getOrCreateRecipientWithUserDictionary:userDict transaction:transaction];
    }];
    return recipient;
}

+(instancetype)getOrCreateRecipientWithUserDictionary:(NSDictionary *)userDict transaction:(YapDatabaseReadWriteTransaction *)transaction
{
    if (![userDict respondsToSelector:@selector(objectForKey:)]) {
        DDLogDebug(@"Attempted to update SignalRecipient with bad dictionary: %@", userDict);
        return nil;
    }
    NSString *uid = [userDict objectForKey:@"id"];
    SignalRecipient *recipient = [self getOrCreateRecipientWithIndentifier:uid withTransaction:transaction];
    
    recipient.isActive = ([(NSNumber *)[userDict objectForKey:@"is_active"] intValue] == 1 ? YES : NO);
    if (!recipient.isActive) {
        [recipient removeWithTransaction:transaction];
        return nil;
    }
    
    recipient.email = [userDict objectForKey:@"email"];
    recipient.phoneNumber = [userDict objectForKey:@"phone"];
    recipient.gravatarHash = [userDict objectForKey:@"gravatar_hash"];
    recipient.isMonitor = ([(NSNumber *)[userDict objectForKey:@"is_monitor"] intValue] == 1 ? YES : NO);
    recipient.isActive = ([(NSNumber *)[userDict objectForKey:@"is_active"] intValue] == 1 ? YES : NO);
    
    NSDictionary *orgDict = [userDict objectForKey:@"org"];
    if (orgDict) {
        recipient.orgID = [orgDict objectForKey:@"id"];
        recipient.orgSlug = [orgDict objectForKey:@"slug"];
    } else {
        DDLogDebug(@"Missing orgDictionary for Recipient: %@", self);
    }
    
    NSDictionary *tagDict = [userDict objectForKey:@"tag"];
    if (tagDict) {
        recipient.flTag = [FLTag getOrCreateTagWithDictionary:tagDict transaction:transaction];
        recipient.flTag.recipientIds = [NSCountedSet setWithObject:recipient.uniqueId];
        if (recipient.flTag.tagDescription.length == 0) {
            recipient.flTag.tagDescription = recipient.fullName;
        }
        if (recipient.flTag.orgSlug.length == 0) {
            recipient.flTag.orgSlug = recipient.orgSlug;
        }
    } else {
        DDLogDebug(@"Missing tagDictionary for Recipient: %@", self);
    }
    [recipient saveWithTransaction:transaction];
    
    return recipient;
}


//+(instancetype)recipientForUserDict:(NSDictionary *)userDict
//{
//    SignalRecipient *recipient = [[SignalRecipient alloc] initWithTextSecureIdentifier:[userDict objectForKey:@"id"]
//                                                                             firstName:[userDict objectForKey:@"first_name"]
//                                                                              lastName:[userDict objectForKey:@"last_name"]];
//    recipient.email = [userDict objectForKey:@"email"];
//    recipient.phoneNumber = [userDict objectForKey:@"phone"];
//    recipient.gravatarHash = [userDict objectForKey:@"gravatar_hash"];
//    recipient.isMonitor = ([(NSNumber *)[userDict objectForKey:@"is_monitor"] intValue] == 1 ? YES : NO);
//    recipient.isActive = ([(NSNumber *)[userDict objectForKey:@"is_active"] intValue] == 1 ? YES : NO);
//
//    NSDictionary *orgDict = [userDict objectForKey:@"org"];
//    if (orgDict) {
//        recipient.orgID = [orgDict objectForKey:@"id"];
//        recipient.orgSlug = [orgDict objectForKey:@"slug"];
//    } else {
//        DDLogDebug(@"Missing orgDictionary for Recipient: %@", recipient);
//    }
//
//    NSDictionary *tagDict = [userDict objectForKey:@"tag"];
//    if (tagDict) {
//        recipient.flTag = [[FLTag alloc] initWithTagDictionary:tagDict];
//        recipient.flTag.recipientIds = [NSCountedSet setWithObject:recipient.uniqueId];
//        if (recipient.flTag.tagDescription.length == 0) {
//            recipient.flTag.tagDescription = recipient.fullName;
//        }
//        if (recipient.flTag.orgSlug.length == 0) {
//            recipient.flTag.orgSlug = recipient.orgSlug;
//        }
//    } else {
//        DDLogDebug(@"Missing tagDictionary for Recipient: %@", recipient);
//    }
//    return recipient;
//}


- (NSMutableOrderedSet *)devices {
    if (_devices == nil) {
        _devices = [NSMutableOrderedSet orderedSetWithObject:[NSNumber numberWithInt:1]];
    }
    return [_devices copy];
}

- (void)addDevices:(NSSet *)set {
    [self checkDevices];
    [_devices unionSet:set];
}

- (void)removeDevices:(NSSet *)set {
    [self checkDevices];
    [_devices minusSet:set];
}

- (void)checkDevices {
    if (_devices == nil || ![_devices isKindOfClass:[NSMutableOrderedSet class]]) {
        _devices = [NSMutableOrderedSet orderedSetWithObject:[NSNumber numberWithInt:1]];
    }
}

#pragma mark - overrides
-(void)save
{
    [self.dbConnection readWriteWithBlock:^(YapDatabaseReadWriteTransaction *transaction) {
        [self saveWithTransaction:transaction];
    }];
}

-(void)saveWithTransaction:(YapDatabaseReadWriteTransaction *)transaction
{
    if (self.flTag) {
        [self.flTag saveWithTransaction:transaction];
    }
    [super saveWithTransaction:transaction];
}

-(void)remove
{
    [self.dbConnection readWriteWithBlock:^(YapDatabaseReadWriteTransaction *transaction) {
        [self removeWithTransaction:transaction];
    }];
}

-(void)removeWithTransaction:(YapDatabaseReadWriteTransaction *)transaction
{
    if (self.flTag) {
        [self.flTag removeWithTransaction:transaction];
    }
    [super removeWithTransaction:transaction];
}

#pragma mark - Accessors
-(UIImage *)avatar
{
        return _avatar;
}

-(void)setGravatarHash:(NSString *)value
{
    if (![_gravatarHash isEqualToString:value]) {
        _gravatarHash = value;
        _gravatarImage = nil;
    }
}

-(UIImage *)gravatarImage
{
    if (_gravatarImage == nil) {
        if (self.gravatarHash.length > 0) {
            NSString *gravatarURL = [NSString stringWithFormat:FLGravatarURLFormat, self.gravatarHash];
            NSData *gravatarData = [NSData dataWithContentsOfURL:[NSURL URLWithString:gravatarURL]];
            if (gravatarData) {
                UIImage *gravatarImage = [UIImage imageWithData:gravatarData];
                if (gravatarImage) {
                    _gravatarImage = gravatarImage;
                }
            }
        }
    }
    return _gravatarImage;
}

-(NSString *)textSecureIdentifier
{
    return self.uniqueId;
}

-(NSString *)fullName
{
    if (self.firstName && self.lastName)
        return [NSString stringWithFormat:@"%@ %@", self.firstName, self.lastName];
    else if (self.lastName)
        return self.lastName;
    else if (self.firstName)
        return self.firstName;
    else
        return nil;
}

-(BOOL)supportsVoice
{
    if (self.phoneNumber) {
        return YES;
    } else {
        return NO;
    }
}


@end

NS_ASSUME_NONNULL_END
