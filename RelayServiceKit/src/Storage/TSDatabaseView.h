//
//  TSDatabaseView.h
//  TextSecureKit
//
//  Created by Frederic Jacobs on 17/11/14.
//  Copyright (c) 2014 Open Whisper Systems. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <YapDatabase/YapDatabaseViewTransaction.h>

@interface TSDatabaseView : NSObject

extern NSString *TSInboxGroup;
extern NSString *TSArchiveGroup;
extern NSString *TSPinnedGroup;
extern NSString *FLActiveTagsGroup;
extern NSString *FLVisibleRecipientGroup;
extern NSString *FLAnnouncementsGroup;
extern NSString *FLHiddenContactsGroup;
extern NSString *FLMonitorGroup;
//extern NSString *FLSearchTagsGroup;

extern NSString *TSSecondaryDevicesGroup;

extern NSString *TSThreadDatabaseViewExtensionName;
extern NSString *TSMessageDatabaseViewExtensionName;
extern NSString *TSUnreadDatabaseViewExtensionName;
extern NSString *TSSecondaryDevicesDatabaseViewExtensionName;
extern NSString *FLTagDatabaseViewExtensionName;
extern NSString *FLFilteredTagDatabaseViewExtensionName;
//extern NSString *FLTagFullTextSearch;

+ (BOOL)registerThreadDatabaseView;
+ (BOOL)registerBuddyConversationDatabaseView;
+ (BOOL)registerUnreadDatabaseView;
+(BOOL)registerTagDatabaseView;
+(BOOL)registerFilteredTagDatabaseView;
+ (void)asyncRegisterSecondaryDevicesDatabaseView;

@end
