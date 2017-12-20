//  Created by Frederic Jacobs on 17/11/14.
//  Copyright (c) 2014 Open Whisper Systems. All rights reserved.

#import "TSYapDatabaseObject.h"
#import "FLTag.h"

NS_ASSUME_NONNULL_BEGIN

@interface SignalRecipient : TSYapDatabaseObject

- (instancetype)initWithTextSecureIdentifier:(NSString *)textSecureIdentifier
                                       relay:(nullable NSString *)relay
                               supportsVoice:(BOOL)voiceCapable;

-(instancetype)initWithTextSecureIdentifier:(NSString *)textSecureIdentifier
                                  firstName:(NSString *)firstName
                                   lastName:(NSString *)lastName;

+ (instancetype)selfRecipient;
+ (nullable instancetype)recipientWithTextSecureIdentifier:(NSString *)textSecureIdentifier;
+ (nullable instancetype)recipientWithTextSecureIdentifier:(NSString *)textSecureIdentifier
                                           withTransaction:(YapDatabaseReadTransaction *)transaction;

+(instancetype)getOrCreateRecipientWithIndentifier:(NSString *)identifier;
+(instancetype)getOrCreateRecipientWithIndentifier:(NSString *)identifier
                                   withTransaction:(YapDatabaseReadWriteTransaction *)transaction;

+(instancetype)recipientForUserDict:(NSDictionary *)userDict;

- (void)addDevices:(NSSet *)set;

- (void)removeDevices:(NSSet *)set;

@property (nonatomic, nullable) NSString *relay;
@property (nonatomic, strong) NSMutableOrderedSet *devices;
@property (readonly) BOOL supportsVoice;

// Forsta additions - departure from Contact usage
@property (strong, nonatomic) NSString *firstName;
@property (strong, nonatomic) NSString *lastName;
@property (strong, nonatomic) NSString *phoneNumber;
@property (strong, nonatomic) NSString *email;
@property (strong, nonatomic) NSString *notes;

@property (nonatomic, readonly) NSString *fullName;
@property (nonatomic, strong) FLTag *flTag;
//@property (nonatomic, strong) NSString *tagSlug;
//@property (nonatomic, strong) NSString *tagID;
//@property (nonatomic, strong) NSString *textSecureIdentifier;
@property (nonatomic, strong) UIImage *avatar;
@property (nonatomic, strong) NSString *orgSlug;
@property (nonatomic, strong) NSString *orgID;
@property (nonatomic, strong) NSString *gravatarHash;
@property (nonatomic, strong) UIImage *gravatarImage;

@property BOOL isMonitor;
@property BOOL isActive;


@end

NS_ASSUME_NONNULL_END
