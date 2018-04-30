//
//  TSDatabaseView.m
//  TextSecureKit
//
//  Created by Frederic Jacobs on 17/11/14.
//  Copyright (c) 2014 Open Whisper Systems. All rights reserved.
//

#import "TSDatabaseView.h"

#import <YapDatabase/YapDatabaseAutoView.h>
#import <YapDatabase/YapDatabaseViewTypes.h>
#import <YapDatabase/YapDatabaseView.h>
#import <YapDatabase/YapDatabaseFilteredView.h>

#import "OWSDevice.h"
#import "TSIncomingMessage.h"
#import "TSOutgoingMessage.h"
#import "TSStorageManager.h"
#import "TSThread.h"

NSString *TSInboxGroup   = @"TSInboxGroup";
NSString *FLAnnouncementsGroup = @"FLAnnouncementsGroup";
NSString *TSArchiveGroup = @"TSArchiveGroup";
NSString *TSPinnedGroup  = @"TSPinnedGroup";
NSString *FLActiveTagsGroup = @"FLActiveTagsGroup";
NSString *FLVisibleRecipientGroup = @"FLVisibleRecipientGroup";
NSString *FLHiddenContactsGroup = @"FLHiddenContactsGroup";
NSString *FLMonitorGroup = @"FLMonitorGroup";
//NSString *FLSearchTagsGroup = @"FLSearchTagsGroup";


NSString *TSUnreadIncomingMessagesGroup = @"TSUnreadIncomingMessagesGroup";
NSString *TSSecondaryDevicesGroup = @"TSSecondaryDevicesGroup";

NSString *TSThreadDatabaseViewExtensionName  = @"TSThreadDatabaseViewExtensionName";
NSString *TSMessageDatabaseViewExtensionName = @"TSMessageDatabaseViewExtensionName";
NSString *TSUnreadDatabaseViewExtensionName  = @"TSUnreadDatabaseViewExtensionName";
NSString *TSSecondaryDevicesDatabaseViewExtensionName = @"TSSecondaryDevicesDatabaseViewExtensionName";
NSString *FLTagDatabaseViewExtensionName = @"FLTagDatabaseViewExtensionName";
NSString *FLFilteredTagDatabaseViewExtensionName = @"FLFilteredTagDatabaseViewExtensionName";
NSString *FLTagFullTextSearch = @"FLTagFullTextSearch";

@implementation TSDatabaseView

+ (BOOL)registerUnreadDatabaseView {
    YapDatabaseView *unreadView =
    [[TSStorageManager sharedManager].database registeredExtension:TSUnreadDatabaseViewExtensionName];
    if (unreadView) {
        return YES;
    }
    
    YapDatabaseViewGrouping *viewGrouping = [YapDatabaseViewGrouping
                                             withObjectBlock:^NSString *(
                                                                         YapDatabaseReadTransaction *transaction, NSString *collection, NSString *key, id object) {
                                                 if ([object isKindOfClass:[TSIncomingMessage class]]) {
                                                     TSIncomingMessage *message = (TSIncomingMessage *)object;
                                                     if (message.read == NO) {
                                                         return message.uniqueThreadId;
                                                     }
                                                 }
                                                 return nil;
                                             }];
    
    YapDatabaseViewSorting *viewSorting = [self messagesSorting];
    
    YapDatabaseViewOptions *options = [[YapDatabaseViewOptions alloc] init];
    options.isPersistent            = YES;
    options.allowedCollections =
    [[YapWhitelistBlacklist alloc] initWithWhitelist:[NSSet setWithObject:[TSInteraction collection]]];
    
    YapDatabaseView *view =
    [[YapDatabaseAutoView alloc] initWithGrouping:viewGrouping sorting:viewSorting versionTag:@"1" options:options];
    
    return
    [[TSStorageManager sharedManager].database registerExtension:view withName:TSUnreadDatabaseViewExtensionName];
}

+(BOOL)registerTagDatabaseView
{
    YapDatabaseView *tagView = [TSStorageManager.sharedManager.database registeredExtension:FLTagDatabaseViewExtensionName];
    if (tagView) {
        return YES;
    }
    
    YapDatabaseViewGrouping *viewGrouping = [YapDatabaseViewGrouping
                                             withObjectBlock:^NSString *(YapDatabaseReadTransaction *transaction, NSString *collection, NSString *key, id object) {
                                                 if ([collection isEqualToString:[FLTag collection]]) {
                                                     FLTag *aTag = (FLTag *)object;
                                                     if (aTag.recipientIds.count > 1) {
                                                         if (aTag.hiddenDate) {
                                                             return FLHiddenContactsGroup;
                                                         } else {
                                                             return FLActiveTagsGroup;
                                                         }
                                                     }
                                                 } else if ([collection isEqualToString:[SignalRecipient collection]]) {
                                                     SignalRecipient *recipient = (SignalRecipient *)object;
                                                     if (recipient.isMonitor) {
                                                         return FLMonitorGroup;
                                                         // Removing hide/unhide per request.
//                                                     } else if (recipient.hiddenDate) {
//                                                         return FLHiddenContactsGroup;
                                                     } else {
                                                         return FLVisibleRecipientGroup;
                                                     }
                                                 }
                                                 return nil;
                                             }];
    YapDatabaseViewSorting *viewSorting = [self tagSorting];
    
    YapDatabaseViewOptions *options = [[YapDatabaseViewOptions alloc] init];
    options.isPersistent = NO;
    options.allowedCollections = [[YapWhitelistBlacklist alloc] initWithWhitelist:[NSSet setWithObjects:[SignalRecipient collection],[FLTag collection], nil]];
    
    YapDatabaseView *databaseView =
    [[YapDatabaseAutoView alloc] initWithGrouping:viewGrouping
                                      sorting:viewSorting
                                   versionTag:@"1" options:options];
    
    return [TSStorageManager.sharedManager.database registerExtension:databaseView
                                                             withName:FLTagDatabaseViewExtensionName];
}

+(BOOL)registerFilteredTagDatabaseView
{
    YapDatabaseFilteredView *filteredView = [TSStorageManager.sharedManager.database registeredExtension:FLFilteredTagDatabaseViewExtensionName];
    if (filteredView) {
        return YES;
    }

    YapDatabaseViewFiltering *filtering = [YapDatabaseViewFiltering withObjectBlock:^BOOL(YapDatabaseReadTransaction * _Nonnull transaction,
                                                                                          NSString * _Nonnull group,
                                                                                          NSString * _Nonnull collection,
                                                                                          NSString * _Nonnull key,
                                                                                          id  _Nonnull object) {
        return YES;
    }];
    
    filteredView = [[YapDatabaseFilteredView alloc] initWithParentViewName:FLTagDatabaseViewExtensionName filtering:filtering];
    
    return [TSStorageManager.sharedManager.database registerExtension:filteredView
                                                             withName:FLFilteredTagDatabaseViewExtensionName];
}

+ (BOOL)registerThreadDatabaseView {
    YapDatabaseView *threadView =
    [[TSStorageManager sharedManager].database registeredExtension:TSThreadDatabaseViewExtensionName];
    if (threadView) {
        return YES;
    }
    
    YapDatabaseViewGrouping *viewGrouping = [YapDatabaseViewGrouping
                                             withObjectBlock:^NSString *(YapDatabaseReadTransaction *transaction, NSString *collection, NSString *key, id object) {
                                                 if ([object isKindOfClass:[TSThread class]]) {
                                                     TSThread *thread = (TSThread *)object;
                                                     if (thread.archivalDate && ![self threadShouldBeInInbox:thread]) {
                                                         return TSArchiveGroup;
                                                     } else if (([thread.type isEqualToString:@"announcement"])) {
                                                         return FLAnnouncementsGroup;
                                                     } else if ([thread.type isEqualToString:@"conversation"]) {
                                                         if (thread.pinPosition) {
                                                             return TSPinnedGroup;
                                                         } else {
                                                             return TSInboxGroup;
                                                         }
                                                     }
                                                 }
                                                 return nil;
                                             }];
    
    YapDatabaseViewSorting *viewSorting = [self threadSorting];
    
    YapDatabaseViewOptions *options = [[YapDatabaseViewOptions alloc] init];
    options.isPersistent            = NO;
    options.allowedCollections =
    [[YapWhitelistBlacklist alloc] initWithWhitelist:[NSSet setWithObject:[TSThread collection]]];
    
    YapDatabaseView *databaseView =
    [[YapDatabaseAutoView alloc] initWithGrouping:viewGrouping sorting:viewSorting versionTag:@"1" options:options];
    
    return [[TSStorageManager sharedManager]
            .database registerExtension:databaseView
            withName:TSThreadDatabaseViewExtensionName];
}

+ (BOOL)registerBuddyConversationDatabaseView {
    if ([[TSStorageManager sharedManager].database registeredExtension:TSMessageDatabaseViewExtensionName]) {
        return YES;
    }
    
    YapDatabaseViewGrouping *viewGrouping = [YapDatabaseViewGrouping
                                             withObjectBlock:^NSString *(
                                                                         YapDatabaseReadTransaction *transaction, NSString *collection, NSString *key, id object) {
                                                 if ([object isKindOfClass:[TSInteraction class]]) {
                                                     
                                                     // TODO: Remove once upvotes are supported on iOS client
                                                     if ([object isKindOfClass:[TSIncomingMessage class]] || [object isKindOfClass:[TSOutgoingMessage class]]) {
                                                         TSMessage *message = (TSMessage *)object;
                                                         if (message.plainTextBody.length == 0 && message.attributedTextBody.length == 0 && !message.hasAttachments && !message.isGiphy) {
                                                             return nil;
                                                         }
                                                     }
                                                     //////////
                                                     
                                                     return ((TSInteraction *)object).uniqueThreadId;
                                                 }
                                                 return nil;
                                             }];
    
    YapDatabaseViewSorting *viewSorting = [self messagesSorting];
    
    YapDatabaseViewOptions *options = [[YapDatabaseViewOptions alloc] init];
    options.isPersistent            = YES;
    options.allowedCollections =
    [[YapWhitelistBlacklist alloc] initWithWhitelist:[NSSet setWithObject:[TSInteraction collection]]];
    
    YapDatabaseView *view =
    [[YapDatabaseAutoView alloc] initWithGrouping:viewGrouping sorting:viewSorting versionTag:@"1" options:options];
    
    return
    [[TSStorageManager sharedManager].database registerExtension:view withName:TSMessageDatabaseViewExtensionName];
}


/**
 *  Determines whether a thread belongs to the archive or inbox
 *
 *  @param thread TSThread
 *
 *  @return Inbox if true, Archive if false
 */

+ (BOOL)threadShouldBeInInbox:(TSThread *)thread {
    NSDate *lastMessageDate = thread.lastMessageDate;
    NSDate *archivalDate    = thread.archivalDate;
    if (lastMessageDate && archivalDate) { // this is what is called
        return ([lastMessageDate timeIntervalSinceDate:archivalDate] > 0)
        ? YES
        : NO; // if there hasn't been a new message since the archive date, it's in the archive. an issue is
        // that empty threads are always given with a lastmessage date of the present on every launch
    } else if (archivalDate) {
        return NO;
    }
    
    return YES;
}

+(YapDatabaseViewSorting *)recipientSorting
{
    return [YapDatabaseViewSorting withObjectBlock:^NSComparisonResult(YapDatabaseReadTransaction * _Nonnull transaction,
                                                                       NSString * _Nonnull group,
                                                                       NSString * _Nonnull collection1,
                                                                       NSString * _Nonnull key1,
                                                                       id  _Nonnull object1,
                                                                       NSString * _Nonnull collection2,
                                                                       NSString * _Nonnull key2,
                                                                       id  _Nonnull object2) {
        if ([group isEqualToString:FLVisibleRecipientGroup]) {
            if ([object1 isKindOfClass:[SignalRecipient class]] && [object2 isKindOfClass:[SignalRecipient class]]) {
                SignalRecipient *recipient1 = (SignalRecipient *)object1;
                SignalRecipient *recipient2 = (SignalRecipient *)object2;
                
                NSComparisonResult result = [recipient1.lastName compare:recipient2.lastName];
                if (result == NSOrderedSame) {
                    return [recipient1.firstName compare:recipient2.firstName];
                } else {
                    return result;
                }
                
            }
        }
        return NSOrderedSame;
    }];
}

+(YapDatabaseViewSorting *)tagSorting
{
    return [YapDatabaseViewSorting withObjectBlock:^NSComparisonResult(YapDatabaseReadTransaction * _Nonnull transaction,
                                                                       NSString * _Nonnull group,
                                                                       NSString * _Nonnull collection1,
                                                                       NSString * _Nonnull key1,
                                                                       id  _Nonnull object1,
                                                                       NSString * _Nonnull collection2,
                                                                       NSString * _Nonnull key2,
                                                                       id  _Nonnull object2) {
        if ([group isEqualToString:FLActiveTagsGroup]) {
            if ([object1 isKindOfClass:[FLTag class]] && [object2 isKindOfClass:[FLTag class]]) {
                FLTag *aTag1 = (FLTag *)object1;
                FLTag *aTag2 = (FLTag *)object2;
                
                return [aTag1.tagDescription compare:aTag2.tagDescription];
            }
        } else if ([group isEqualToString:FLVisibleRecipientGroup]) {
            if ([object1 isKindOfClass:[SignalRecipient class]] && [object2 isKindOfClass:[SignalRecipient class]]) {
                SignalRecipient *recipient1 = (SignalRecipient *)object1;
                SignalRecipient *recipient2 = (SignalRecipient *)object2;
                
                NSComparisonResult result = [recipient1.lastName compare:recipient2.lastName];
                if (result == NSOrderedSame) {
                    return [recipient1.firstName compare:recipient2.firstName];
                } else {
                    return result;
                }
                
            }
        }
        return NSOrderedSame;
    }];
}

+ (YapDatabaseViewSorting *)threadSorting {
    return [YapDatabaseViewSorting withObjectBlock:^NSComparisonResult(YapDatabaseReadTransaction *transaction,
                                                                       NSString *group,
                                                                       NSString *collection1,
                                                                       NSString *key1,
                                                                       id object1,
                                                                       NSString *collection2,
                                                                       NSString *key2,
                                                                       id object2) {
        if ([group isEqualToString:TSArchiveGroup] || [group isEqualToString:TSInboxGroup]) {
            if ([object1 isKindOfClass:[TSThread class]] && [object2 isKindOfClass:[TSThread class]]) {
                TSThread *thread1 = (TSThread *)object1;
                TSThread *thread2 = (TSThread *)object2;
                
                return [thread1.lastMessageDate compare:thread2.lastMessageDate];
            }
        } else if ([group isEqualToString:TSPinnedGroup]) {
            if ([object1 isKindOfClass:[TSThread class]] && [object2 isKindOfClass:[TSThread class]]) {
                TSThread *thread1 = (TSThread *)object1;
                TSThread *thread2 = (TSThread *)object2;
                
                return [thread1.pinPosition compare:thread2.pinPosition];
            }
        }
        
        return NSOrderedSame;
    }];
}

+ (YapDatabaseViewSorting *)messagesSorting {
    return [YapDatabaseViewSorting withObjectBlock:^NSComparisonResult(YapDatabaseReadTransaction *transaction,
                                                                       NSString *group,
                                                                       NSString *collection1,
                                                                       NSString *key1,
                                                                       id object1,
                                                                       NSString *collection2,
                                                                       NSString *key2,
                                                                       id object2) {
        if ([object1 isKindOfClass:[TSInteraction class]] && [object2 isKindOfClass:[TSInteraction class]]) {
            TSInteraction *message1 = (TSInteraction *)object1;
            TSInteraction *message2 = (TSInteraction *)object2;
            
            NSDate *date1 = [self localTimeReceiveDateForInteraction:message1];
            NSDate *date2 = [self localTimeReceiveDateForInteraction:message2];
            
            NSComparisonResult result = [date1 compare:date2];
            
            // NSDates are only accurate to the second, we might want finer precision
            if (result != NSOrderedSame) {
                return result;
            }
            
            if (message1.timestamp > message2.timestamp) {
                return NSOrderedDescending;
            } else if (message1.timestamp < message2.timestamp) {
                return NSOrderedAscending;
            } else {
                return NSOrderedSame;
            }
        }
        
        return NSOrderedSame;
    }];
}

+ (void)asyncRegisterSecondaryDevicesDatabaseView
{
    YapDatabaseViewGrouping *viewGrouping =
    [YapDatabaseViewGrouping withObjectBlock:^NSString *_Nullable(YapDatabaseReadTransaction *_Nonnull transaction,
                                                                  NSString *_Nonnull collection,
                                                                  NSString *_Nonnull key,
                                                                  id _Nonnull object) {
        NSInteger currentDeviceId = [[TSStorageManager deviceIdWithTransaction:transaction] integerValue];
        if ([object isKindOfClass:[OWSDevice class]]) {
            OWSDevice *device = (OWSDevice *)object;
            if (!(device.deviceId == currentDeviceId)) {
                return TSSecondaryDevicesGroup;
            }
        }
        return nil;
    }];
    
    YapDatabaseViewSorting *viewSorting =
    [YapDatabaseViewSorting withObjectBlock:^NSComparisonResult(YapDatabaseReadTransaction *_Nonnull transaction,
                                                                NSString *_Nonnull group,
                                                                NSString *_Nonnull collection1,
                                                                NSString *_Nonnull key1,
                                                                id _Nonnull object1,
                                                                NSString *_Nonnull collection2,
                                                                NSString *_Nonnull key2,
                                                                id _Nonnull object2) {
        
        if ([object1 isKindOfClass:[OWSDevice class]] && [object2 isKindOfClass:[OWSDevice class]]) {
            OWSDevice *device1 = (OWSDevice *)object1;
            OWSDevice *device2 = (OWSDevice *)object2;
            
            return [device2.createdAt compare:device1.createdAt];
        }
        
        return NSOrderedSame;
    }];
    
    YapDatabaseViewOptions *options = [YapDatabaseViewOptions new];
    options.isPersistent = YES;
    
    NSSet *deviceCollection = [NSSet setWithObject:[OWSDevice collection]];
    options.allowedCollections = [[YapWhitelistBlacklist alloc] initWithWhitelist:deviceCollection];
    
    YapDatabaseView *view =
    [[YapDatabaseAutoView alloc] initWithGrouping:viewGrouping sorting:viewSorting versionTag:@"3" options:options];
    
    [[TSStorageManager sharedManager].database
     asyncRegisterExtension:view
     withName:TSSecondaryDevicesDatabaseViewExtensionName
     completionBlock:^(BOOL ready) {
         if (ready) {
             DDLogDebug(@"%@ Successfully set up extension: %@", self.tag, TSSecondaryDevicesGroup);
         } else {
             DDLogError(@"%@ Unable to setup extension: %@", self.tag, TSSecondaryDevicesGroup);
         }
     }];
}

+ (NSDate *)localTimeReceiveDateForInteraction:(TSInteraction *)interaction {
    NSDate *interactionDate = interaction.date;
    
    if ([interaction isKindOfClass:[TSIncomingMessage class]]) {
        TSIncomingMessage *message = (TSIncomingMessage *)interaction;
        
        if (message.receivedAt) {
            interactionDate = message.receivedAt;
        }
    }
    
    return interactionDate;
}

#pragma mark - Logging

+ (NSString *)tag
{
    return [NSString stringWithFormat:@"[%@]", self.class];
}

- (NSString *)tag
{
    return self.class.tag;
}

@end
