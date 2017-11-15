//  Created by Frederic Jacobs on 17/11/14.
//  Copyright (c) 2014 Open Whisper Systems. All rights reserved.

#import "SignalRecipient.h"
#import "TSStorageHeaders.h"
#import "TSAccountManager.h"
#import "TSStorageManager+IdentityKeyStore.h"

NS_ASSUME_NONNULL_BEGIN

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
    //    _supportsVoice = voiceCapable;
    
    return self;
}

-(instancetype)initWithTextSecureIdentifier:(NSString *)textSecureIdentifier
                                  firstName:(NSString *)firstName
                                   lastName:(NSString *)lastName
                                    tagSlug:(NSString *)tagSlug
{
    if ([super initWithUniqueId:textSecureIdentifier]) {
        _firstName = firstName;
        _lastName = lastName;
        _tagSlug = tagSlug;
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
    }];
    return recipient;
}

+ (instancetype)selfRecipient
{
    SignalRecipient *myself = [self recipientWithTextSecureIdentifier:TSAccountManager.sharedInstance.myself.uniqueId];
    if (!myself) {
        myself = [[self alloc] initWithTextSecureIdentifier:TSAccountManager.sharedInstance.myself.uniqueId relay:nil supportsVoice:YES];
    }
    return myself;
}

+(instancetype)recipientForUserDict:(NSDictionary *)userDict;
{
#warning XXX save all the things here
    NSDictionary *tagDict = [userDict objectForKey:@"tag"];
    SignalRecipient *recipient = [[SignalRecipient alloc] initWithTextSecureIdentifier:[userDict objectForKey:@"id"]
                                                                             firstName:[userDict objectForKey:@"first_name"]
                                                                              lastName:[userDict objectForKey:@"last_name"]
                                                                               tagSlug:(tagDict ? [tagDict objectForKey:@"slug"] : nil)];
    recipient.email = [userDict objectForKey:@"email"];
    recipient.phoneNumber = [userDict objectForKey:@"phone"];
    recipient.tagID = (tagDict ? [tagDict objectForKey:@"id"] : nil);
    
    NSDictionary *orgDict = [userDict objectForKey:@"org"];
    if (orgDict) {
        recipient.orgID = [orgDict objectForKey:@"id"];
        recipient.orgSlug = [orgDict objectForKey:@"slug"];
    }
    
    return recipient;
}


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

#pragma mark - getter/setter/lazy instantiation
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
