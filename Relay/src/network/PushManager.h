//
//  PushManager.h
//  Signal
//
//  Created by Frederic Jacobs on 31/07/14.
//  Copyright (c) 2014 Open Whisper Systems. All rights reserved.
//

#import <CollapsingFutures.h>
#import <PushKit/PushKit.h>
#import <UIKit/UIApplication.h>

NS_ASSUME_NONNULL_BEGIN

@class UILocalNotification;

#define Forsta_Thread_UserInfo_Key @"Forsta_Thread_Id"
#define Forsta_Message_UserInfo_Key @"Forsta_Message_Id"

#define Forsta_Call_UserInfo_Key @"Forsta_Call_Id"

#define Forsta_Call_Accept_Identifier @"Forsta_Call_Accept"
#define Forsta_Call_Decline_Identifier @"Forsta_Call_Decline"

#define Forsta_CallBack_Identifier @"Forsta_CallBack"

#define Forsta_Call_Category @"Forsta_IncomingCall"
#define Forsta_Full_New_Message_Category @"Forsta_Full_New_Message"
#define Forsta_CallBack_Category @"Forsta_CallBack"

#define Forsta_Message_Reply_Identifier @"Forsta_New_Message_Reply"
#define Forsta_Message_MarkAsRead_Identifier @"Forsta_Message_MarkAsRead"

typedef void (^failedPushRegistrationBlock)(NSError *error);
typedef void (^pushTokensSuccessBlock)(NSString *pushToken, NSString *voipToken);

/**
 *  The Push Manager is responsible for registering the device for Signal push notifications.
 */

@interface PushManager : NSObject <PKPushRegistryDelegate>

+ (PushManager *)sharedManager;

/**
 *  Returns the Push Notification Token of this device
 *
 *  @param success Completion block that is passed the token as a parameter
 *  @param failure Failure block, executed when failed to get push token
 */
- (void)requestPushTokenWithSuccess:(pushTokensSuccessBlock)success failure:(void (^)(NSError *))failure;

/**
 *  Registers for Users Notifications. By doing this on launch, we are sure that the correct categories of user
 * notifications is registered.
 */
- (void)validateUserNotificationSettings;

/**
 *  The pushNotification and userNotificationFutureSource are accessed by the App Delegate after requested permissions.
 */
@property (nullable, atomic, readwrite, strong) TOCFutureSource *pushNotificationFutureSource;
@property (nullable, atomic, readwrite, strong) TOCFutureSource *userNotificationFutureSource;
@property (nullable, atomic, readwrite, strong) TOCFutureSource *pushKitNotificationFutureSource;

- (TOCFuture *)registerPushKitNotificationFuture;
- (BOOL)supportsVOIPPush;
- (UILocalNotification *)closeVOIPBackgroundTask;
- (void)presentNotification:(UILocalNotification *)notification;
- (void)cancelNotificationsWithThreadId:(NSString *)threadId;

#pragma mark Push Notifications Delegate Methods

- (void)application:(UIApplication *)application didReceiveRemoteNotification:(NSDictionary *)userInfo;
- (void)application:(UIApplication *)application
    didReceiveRemoteNotification:(NSDictionary *)userInfo
          fetchCompletionHandler:(void (^)(UIBackgroundFetchResult))completionHandler;
- (void)application:(UIApplication *)application
    handleActionWithIdentifier:(NSString *)identifier
          forLocalNotification:(UILocalNotification *)notification
             completionHandler:(void (^)())completionHandler;
- (void)application:(UIApplication *)application didReceiveLocalNotification:(UILocalNotification *)notification;
- (void)application:(UIApplication *)application
    handleActionWithIdentifier:(NSString *)identifier
          forLocalNotification:(UILocalNotification *)notification
              withResponseInfo:(NSDictionary *)responseInfo
             completionHandler:(void (^)())completionHandler;

@end

NS_ASSUME_NONNULL_END
