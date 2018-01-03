#import "PropertyListPreferences.h"
#import "Constraints.h"
#import "TSStorageHeaders.h"
#import "TSPrivacyPreferences.h"

NS_ASSUME_NONNULL_BEGIN

double const PropertyListPreferencesDefaultCallStreamDESBufferLevel = 0.5;
NSString *const PropertyListPreferencesSignalDatabaseCollection = @"SignalPreferences";

NSString *const PropertyListPreferencesKeyCallStreamDESBufferLevel = @"CallStreamDesiredBufferLevel";
NSString *const PropertyListPreferencesKeyScreenSecurity = @"Screen Security Key";
NSString *const PropertyListPreferencesKeyEnableDebugLog = @"Debugging Log Enabled Key";
NSString *const PropertyListPreferencesKeyNotificationPreviewType = @"Notification Preview Type Key";
NSString *const PropertyListPreferencesKeyHasSentAMessage = @"User has sent a message";
NSString *const PropertyListPreferencesKeyHasArchivedAMessage = @"User archived a message";
NSString *const PropertyListPreferencesKeyLastRunSignalVersion = @"SignalUpdateVersionKey";
NSString *const PropertyListPreferencesKeyPlaySoundInForeground = @"NotificationSoundInForeground";
NSString *const PropertyListPreferencesKeyPlaySoundInBackground = @"NotificationSoundInBackground";
NSString *const PropertyListPreferencesKeyHasRegisteredVoipPush = @"VOIPPushEnabled";
NSString *const PropertyListPreferencesKeyLastRecordedPushToken = @"LastRecordedPushToken";
NSString *const PropertyListPreferencesKeyLastRecordedVoipToken = @"LastRecordedVoipToken";
NSString *const PropertyListPreferencesKeyUseGravatars = @"UseGravatars";
NSString *const PropertyListPreferencesKeyRequirePINAccess = @"RequirePINAccess";
NSString *const PropertyListPreferencesKeyPINLength = @"PINLength";
NSString *const PropertyListPreferencesKeyOutgoingBubbleColorKey = @"OutgoingBubbleColorKey";
NSString *const PropertyListPreferencesKeyIncomingBubbleColorKey = @"IncomingBubbleColorKey";

@interface PropertyListPreferences()

@property (atomic, strong) NSCache *prefsCache;

@end


@implementation PropertyListPreferences

+ (instancetype)sharedInstance
{
    static PropertyListPreferences *sharedInstance;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        if (!sharedInstance) {
            sharedInstance = [[self alloc] init];
        }
    });
    
    return sharedInstance;
}

-(instancetype)init
{
    if (self = [super init]) {
        _prefsCache = [NSCache new];
        // Preload the cache
        [TSStorageManager.sharedManager.dbConnection readWithBlock:^(YapDatabaseReadTransaction * _Nonnull transaction) {
            [transaction enumerateKeysAndObjectsInCollection:PropertyListPreferencesSignalDatabaseCollection
                                                  usingBlock:^(NSString * _Nonnull key, id  _Nonnull object, BOOL * _Nonnull stop) {
                                                      [_prefsCache setObject:object forKey:key];
                                                  }];
        }];
    }
    return self;
}

#pragma mark - Helpers

- (void)clear {
    @synchronized(self) {
        NSString *appDomain = NSBundle.mainBundle.bundleIdentifier;
        [NSUserDefaults.standardUserDefaults removePersistentDomainForName:appDomain];
    }
}

- (nullable id)tryGetValueForKey:(NSString *)key
{
    ows_require(key != nil);
    
    id object = [self.prefsCache objectForKey:key];
    
    if (object) {
        return object;
    } else {
        object = [TSStorageManager.sharedManager objectForKey:key inCollection:PropertyListPreferencesSignalDatabaseCollection];
        if (object) {
            [self.prefsCache setObject:object forKey:key];
        }
        return object;
        
    }
}

- (void)setValueForKey:(NSString *)key toValue:(nullable id)value
{
    ows_require(key != nil);
    
    id oldObject = [self.prefsCache objectForKey:key];
    if (![oldObject isEqual:value]) {
        [self.prefsCache setObject:value forKey:key];
        [TSStorageManager.sharedManager setObject:value
                                           forKey:key
                                     inCollection:PropertyListPreferencesSignalDatabaseCollection];
    }
}

- (TSPrivacyPreferences *)tsPrivacyPreferences
{
    return [TSPrivacyPreferences sharedInstance];
}

#pragma mark - Specific Preferences

- (NSTimeInterval)getCachedOrDefaultDesiredBufferDepth
{
    id v = [self tryGetValueForKey:PropertyListPreferencesKeyCallStreamDESBufferLevel];
    if (v == nil)
        return PropertyListPreferencesDefaultCallStreamDESBufferLevel;
    return [v doubleValue];
}

- (void)setCachedDesiredBufferDepth:(double)value
{
    ows_require(value >= 0);
    [self setValueForKey:PropertyListPreferencesKeyCallStreamDESBufferLevel toValue:@(value)];
}

- (BOOL)loggingIsEnabled
{
    NSNumber *preference = [self tryGetValueForKey:PropertyListPreferencesKeyEnableDebugLog];
    if (preference) {
        return [preference boolValue];
    } else {
        return YES;
    }
}

- (BOOL)screenSecurityIsEnabled
{
    NSNumber *preference = [self tryGetValueForKey:PropertyListPreferencesKeyScreenSecurity];
    return preference ? [preference boolValue] : YES;
}

- (BOOL)getHasSentAMessage
{
    NSNumber *preference = [self tryGetValueForKey:PropertyListPreferencesKeyHasSentAMessage];
    if (preference) {
        return [preference boolValue];
    } else {
        return NO;
    }
}

- (BOOL)getHasArchivedAMessage
{
    NSNumber *preference = [self tryGetValueForKey:PropertyListPreferencesKeyHasArchivedAMessage];
    if (preference) {
        return [preference boolValue];
    } else {
        return NO;
    }
}

- (BOOL)hasRegisteredVOIPPush
{
    NSNumber *preference = [self tryGetValueForKey:PropertyListPreferencesKeyHasRegisteredVoipPush];
    if (preference) {
        return [preference boolValue];
    } else {
        return YES;
    }
}

- (TSImageQuality)imageUploadQuality
{
    // always return average image quality
    return TSImageQualityMedium;
}

- (void)setScreenSecurity:(BOOL)flag
{
    [self setValueForKey:PropertyListPreferencesKeyScreenSecurity toValue:@(flag)];
}

- (void)setHasRegisteredVOIPPush:(BOOL)enabled
{
    [self setValueForKey:PropertyListPreferencesKeyHasRegisteredVoipPush toValue:@(enabled)];
}

- (void)setLoggingEnabled:(BOOL)flag
{
    [self setValueForKey:PropertyListPreferencesKeyEnableDebugLog toValue:@(flag)];
}

- (nullable NSString *)lastRanVersion
{
    return [NSUserDefaults.standardUserDefaults objectForKey:PropertyListPreferencesKeyLastRunSignalVersion];
}

- (void)setHasSentAMessage:(BOOL)enabled
{
    [self setValueForKey:PropertyListPreferencesKeyHasSentAMessage toValue:@(enabled)];
}

- (void)setHasArchivedAMessage:(BOOL)enabled
{
    [self setValueForKey:PropertyListPreferencesKeyHasArchivedAMessage toValue:@(enabled)];
}

- (NSString *)setAndGetCurrentVersion
{
    NSString *currentVersion =
        [NSString stringWithFormat:@"%@", NSBundle.mainBundle.infoDictionary[@"CFBundleVersion"]];
    [NSUserDefaults.standardUserDefaults setObject:currentVersion
                                            forKey:PropertyListPreferencesKeyLastRunSignalVersion];
    [NSUserDefaults.standardUserDefaults synchronize];
    return currentVersion;
}

#pragma mark Notification Preferences
- (BOOL)soundInForeground
{
    NSNumber *preference = [self tryGetValueForKey:PropertyListPreferencesKeyPlaySoundInForeground];
    if (preference) {
        return [preference boolValue];
    } else {
        return YES;
    }
}

- (void)setSoundInForeground:(BOOL)enabled
{
    [self setValueForKey:PropertyListPreferencesKeyPlaySoundInForeground toValue:@(enabled)];
}

- (BOOL)soundInBackground
{
    NSNumber *preference = [self tryGetValueForKey:PropertyListPreferencesKeyPlaySoundInBackground];
    if (preference) {
        return [preference boolValue];
    } else {
        return YES;
    }
}

- (void)setSoundInBackground:(BOOL)enabled
{
    [self setValueForKey:PropertyListPreferencesKeyPlaySoundInBackground toValue:@(enabled)];
}

- (void)setNotificationPreviewType:(NotificationType)type
{
    [self setValueForKey:PropertyListPreferencesKeyNotificationPreviewType toValue:@(type)];
}

- (NotificationType)notificationPreviewType
{
    NSNumber *preference = [self tryGetValueForKey:PropertyListPreferencesKeyNotificationPreviewType];

    if (preference) {
        return [preference unsignedIntegerValue];
    } else {
        return NotificationNamePreview;
    }
}

- (NSString *)nameForNotificationPreviewType:(NotificationType)notificationType
{
    switch (notificationType) {
        case NotificationNamePreview:
            return NSLocalizedString(@"NOTIFICATIONS_SENDER_AND_MESSAGE", nil);
        case NotificationNameNoPreview:
            return NSLocalizedString(@"NOTIFICATIONS_SENDER_ONLY", nil);
        case NotificationNoNameNoPreview:
            return NSLocalizedString(@"NOTIFICATIONS_NONE", nil);
        default:
            DDLogWarn(@"Undefined NotificationType in Settings");
            return @"";
    }
}

#pragma mark - Block on Identity Change

- (BOOL)shouldBlockOnIdentityChange
{
    return NO;
//    return self.tsPrivacyPreferences.shouldBlockOnIdentityChange;
}

- (void)setShouldBlockOnIdentityChange:(BOOL)value
{
    self.tsPrivacyPreferences.shouldBlockOnIdentityChange = value;
    [self.tsPrivacyPreferences save];
}

#pragma mark - Push Tokens

- (void)setPushToken:(NSString *)value
{
    [self setValueForKey:PropertyListPreferencesKeyLastRecordedPushToken toValue:value];
}

- (nullable NSString *)getPushToken
{
    return [self tryGetValueForKey:PropertyListPreferencesKeyLastRecordedPushToken];
}

- (void)setVoipToken:(NSString *)value
{
    [self setValueForKey:PropertyListPreferencesKeyLastRecordedVoipToken toValue:value];
}

- (nullable NSString *)getVoipToken
{
    return [self tryGetValueForKey:PropertyListPreferencesKeyLastRecordedVoipToken];
}

-(void)setUseGravatars:(BOOL)value
{
    [self setValueForKey:PropertyListPreferencesKeyUseGravatars toValue:@(value)];
}

-(BOOL)useGravatars
{
    return [[self tryGetValueForKey:PropertyListPreferencesKeyUseGravatars] boolValue];
}

-(void)setRequirePINAccess:(BOOL)value
{
    [self setValueForKey:PropertyListPreferencesKeyRequirePINAccess toValue:@(value)];
}

-(BOOL)requirePINAccess
{
    return [[self tryGetValueForKey:PropertyListPreferencesKeyRequirePINAccess] boolValue];
}

-(void)setPINLength:(NSInteger)value
{
    [self setValueForKey:PropertyListPreferencesKeyPINLength toValue:@(value)];
}

-(NSInteger)PINLength
{
    NSInteger value = [[self tryGetValueForKey:PropertyListPreferencesKeyPINLength] integerValue];
    if (value == 0) {
        value = 4;
    }
    return value;
}

-(void)setOutgoingBubbleColorKey:(NSString *)value
{
    [self setValueForKey:PropertyListPreferencesKeyOutgoingBubbleColorKey toValue:value];
}

-(NSString *)outgoingBubbleColorKey
{
    NSString *aKey = [self tryGetValueForKey:PropertyListPreferencesKeyOutgoingBubbleColorKey];
    if (aKey) {
        return aKey;
    } else {
        return @"Black";
    }
}

-(void)setIncomingBubbleColorKey:(NSString *)value
{
    [self setValueForKey:PropertyListPreferencesKeyIncomingBubbleColorKey toValue:value];
}

-(NSString *)incomingBubbleColorKey
{
    NSString *aKey = [self tryGetValueForKey:PropertyListPreferencesKeyIncomingBubbleColorKey];
    if (aKey) {
        return aKey;
    } else {
        return @"Gray";
    }
}
@end

NS_ASSUME_NONNULL_END
