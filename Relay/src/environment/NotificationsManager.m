//
//  NotificationsManager.m
//  Signal
//
//  Created by Frederic Jacobs on 22/12/15.
//  Copyright © 2015 Open Whisper Systems. All rights reserved.
//

#import "NotificationsManager.h"
#import "TSMessagesManager.h"
#import "Environment.h"
#import "PropertyListPreferences.h"
#import "PushManager.h"
#import <AudioToolbox/AudioServices.h>
#import "TSCall.h"
#import "TSThread.h"
#import "TSErrorMessage.h"
#import "TSIncomingMessage.h"
#import "TextSecureKitEnv.h"

static const NSTimeInterval silenceWindow = 1.0;  // seconds

@interface NotificationsManager ()

@property SystemSoundID newMessageSound;
@property (nonatomic, readonly) id<ContactsManagerProtocol> contactsManager;
@property (nonatomic, strong) NSDate *lastNotificationDate;

@end

@implementation NotificationsManager

- (instancetype)init
{
    self = [super init];

    if (!self) {
        return self;
    }

    _contactsManager = [TextSecureKitEnv sharedEnv].contactsManager;

    NSURL *newMessageURL = [[NSBundle mainBundle] URLForResource:@"NewMessage" withExtension:@"aifc"];
    AudioServicesCreateSystemSoundID((__bridge CFURLRef)newMessageURL, &_newMessageSound);

    return self;
}

- (void)notifyUserForCall:(TSCall *)call inThread:(TSThread *)thread {
    DDLogDebug(@"Call notification called! VOIP NOT IMPLEMENTED!");
//    if ([UIApplication sharedApplication].applicationState != UIApplicationStateActive) {
//        // Remove previous notification of call and show missed notification.
//        UILocalNotification *notif = [[PushManager sharedManager] closeVOIPBackgroundTask];
//        TSContactThread *cThread   = (TSContactThread *)thread;
//
//        if (call.callType == RPRecentCallTypeMissed) {
//            if (notif) {
//                [[UIApplication sharedApplication] cancelLocalNotification:notif];
//            }
//
//            UILocalNotification *notification = [[UILocalNotification alloc] init];
//            notification.soundName            = @"NewMessage.aifc";
//            if ([[Environment preferences] notificationPreviewType] == NotificationNoNameNoPreview) {
//                notification.alertBody = [NSString stringWithFormat:NSLocalizedString(@"MISSED_CALL", nil)];
//            } else {
//                notification.userInfo = @{Signal_Call_UserInfo_Key : cThread.contactIdentifier};
//                notification.category = Signal_CallBack_Category;
//                notification.alertBody =
//                    [NSString stringWithFormat:NSLocalizedString(@"MSGVIEW_MISSED_CALL", nil), [thread name]];
//            }
//
//            [[PushManager sharedManager] presentNotification:notification];
//        }
//    }
}

- (void)notifyUserForErrorMessage:(TSErrorMessage *)message inThread:(TSThread *)thread {
    NSString *messageDescription = message.description;

    if (([UIApplication sharedApplication].applicationState != UIApplicationStateActive) && messageDescription) {
        UILocalNotification *notification = [[UILocalNotification alloc] init];
        notification.userInfo             = @{Signal_Thread_UserInfo_Key : thread.uniqueId};
        if ([Environment.preferences soundInBackground] &&
            [[NSDate date] timeIntervalSinceDate:self.lastNotificationDate ] > silenceWindow) {
            notification.soundName = @"NewMessage.aifc";
        } else {
            notification.soundName = nil;
        }
        
        NSString *alertBodyString = @"";

        NSString *authorName = thread.displayName;
        if (authorName.length > 15) {
            authorName = [[thread.displayName substringToIndex:12] stringByAppendingString:@"..."];
        }
        switch ([[Environment preferences] notificationPreviewType]) {
            case NotificationNamePreview:
            case NotificationNameNoPreview:
                alertBodyString = [NSString stringWithFormat:@"%@: %@", authorName, messageDescription];
                break;
            case NotificationNoNameNoPreview:
                alertBodyString = messageDescription;
                break;
        }
        notification.alertBody = alertBodyString;

        [[PushManager sharedManager] presentNotification:notification];
    } else {
        if ([Environment.preferences soundInForeground]) {
            AudioServicesPlayAlertSound(_newMessageSound);
        }
    }
    self.lastNotificationDate = [NSDate date];
}

- (void)notifyUserForIncomingMessage:(TSIncomingMessage *)message from:(NSString *)name inThread:(TSThread *)thread {
    NSString *messageDescription = message.description;
    
    if ([UIApplication sharedApplication].applicationState != UIApplicationStateActive && messageDescription) {
        UILocalNotification *notification = [[UILocalNotification alloc] init];
        if ([Environment.preferences soundInBackground] &&
            [[NSDate date] timeIntervalSinceDate:self.lastNotificationDate ] > silenceWindow) {
            notification.soundName = @"NewMessage.aifc";
        } else {
            notification.soundName = nil;
        }
        
        switch ([[Environment preferences] notificationPreviewType]) {
            case NotificationNamePreview:
                notification.category = Signal_Full_New_Message_Category;
                notification.userInfo =
                @{Signal_Thread_UserInfo_Key : thread.uniqueId, Signal_Message_UserInfo_Key : message.uniqueId};
                
                notification.alertBody = [NSString stringWithFormat:@"%@: %@", name, messageDescription];
                break;
            case NotificationNameNoPreview: {
                notification.userInfo = @{Signal_Thread_UserInfo_Key : thread.uniqueId};
                notification.alertBody =
                [NSString stringWithFormat:@"%@ %@", NSLocalizedString(@"APN_MESSAGE_FROM", nil), name];
                break;
            }
            case NotificationNoNameNoPreview:
                notification.alertBody = NSLocalizedString(@"APN_Message", nil);
                break;
            default:
                notification.alertBody = NSLocalizedString(@"APN_Message", nil);
                break;
        }

        [[PushManager sharedManager] presentNotification:notification];
        
        NSInteger unread = (NSInteger) TSMessagesManager.sharedManager.unreadMessagesCount;
        [[UIApplication sharedApplication] setApplicationIconBadgeNumber:unread];

    } else {
        if ([Environment.preferences soundInForeground] &&
            [[NSDate date] timeIntervalSinceDate:self.lastNotificationDate ] > silenceWindow) {
            AudioServicesPlayAlertSound(_newMessageSound);
        }
    }
    self.lastNotificationDate = [NSDate date];
}

@end
