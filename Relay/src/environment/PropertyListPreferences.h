#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSUInteger, NotificationType) {
    NotificationNoNameNoPreview,
    NotificationNameNoPreview,
    NotificationNamePreview,
};

typedef NS_ENUM(NSUInteger, TSImageQuality) {
    TSImageQualityUncropped = 1,
    TSImageQualityHigh = 2,
    TSImageQualityMedium = 3,
    TSImageQualityLow = 4
};

@interface PropertyListPreferences : NSObject

+ (instancetype)sharedInstance;

#pragma mark - Helpers

- (nullable id)tryGetValueForKey:(NSString *)key;
- (void)setValueForKey:(NSString *)key toValue:(nullable id)value;
- (void)clear;

#pragma mark - Specific Preferences

- (NSTimeInterval)getCachedOrDefaultDesiredBufferDepth;
- (void)setCachedDesiredBufferDepth:(double)value;

- (BOOL)getHasSentAMessage;
- (void)setHasSentAMessage:(BOOL)enabled;

- (BOOL)getHasArchivedAMessage;
- (void)setHasArchivedAMessage:(BOOL)enabled;

- (BOOL)loggingIsEnabled;
- (void)setLoggingEnabled:(BOOL)flag;

- (BOOL)screenSecurityIsEnabled;
- (void)setScreenSecurity:(BOOL)flag;

- (NotificationType)notificationPreviewType;
- (void)setNotificationPreviewType:(NotificationType)type;
- (NSString *)nameForNotificationPreviewType:(NotificationType)notificationType;

- (BOOL)soundInForeground;
- (void)setSoundInForeground:(BOOL)enabled;

- (BOOL)soundInBackground;
- (void)setSoundInBackground:(BOOL)enabled;

- (BOOL)hasRegisteredVOIPPush;
- (void)setHasRegisteredVOIPPush:(BOOL)enabled;

- (TSImageQuality)imageUploadQuality;

- (nullable NSString *)lastRanVersion;
- (NSString *)setAndGetCurrentVersion;

@property (assign) BOOL useGravatars;
@property (assign) BOOL requirePINAccess;
@property (assign) BOOL passwordAuth;
@property (assign) NSInteger PINLength;
@property (strong) NSString *outgoingBubbleColorKey;
@property (strong) NSString *incomingBubbleColorKey;

#pragma mark - Block on Identity Change

- (BOOL)shouldBlockOnIdentityChange;
- (void)setShouldBlockOnIdentityChange:(BOOL)value;

#pragma mark - Push Tokens

- (void)setPushToken:(NSString *)value;
- (nullable NSString *)getPushToken;

- (void)setVoipToken:(NSString *)value;
- (nullable NSString *)getVoipToken;

@end

NS_ASSUME_NONNULL_END
