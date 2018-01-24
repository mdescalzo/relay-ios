//  Created by Michael Kirk on 9/24/16.
//  Copyright © 2016 Open Whisper Systems. All rights reserved.

#import "OWSIncomingMessageReadObserver.h"
#import "NSDate+millisecondTimeStamp.h"
#import "OWSDisappearingMessagesConfiguration.h"
#import "OWSDisappearingMessagesJob.h"
#import "OWSSendReadReceiptsJob.h"
#import "TSIncomingMessage.h"

NS_ASSUME_NONNULL_BEGIN

@interface OWSIncomingMessageReadObserver ()

@property BOOL isObserving;
@property (nonatomic, readonly) OWSDisappearingMessagesJob *disappearingMessagesJob;
@property (nonatomic, readonly) OWSSendReadReceiptsJob *sendReadReceiptsJob;

@end

@implementation OWSIncomingMessageReadObserver

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (instancetype)initWithStorageManager:(TSStorageManager *)storageManager
                         messageSender:(OWSMessageSender *)messageSender
{
    self = [super init];
    if (!self) {
        return self;
    }

    _isObserving = NO;
    _disappearingMessagesJob = [[OWSDisappearingMessagesJob alloc] initWithStorageManager:storageManager];
    _sendReadReceiptsJob = [[OWSSendReadReceiptsJob alloc] initWithMessageSender:messageSender];

    return self;
}

- (void)startObserving
{
    if (self.isObserving) {
        return;
    }

    self.isObserving = true;
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(handleLocalReadNotification:)
                                                 name:TSIncomingMessageWasReadOnThisDeviceNotification
                                               object:nil];
}

- (void)handleLocalReadNotification:(NSNotification *)notification
{
    if (![notification.object isKindOfClass:[TSIncomingMessage class]]) {
        DDLogError(@"%@ Read receipt notifier got unexpected object: %@", self.tag, notification.object);
        return;
    }

    TSIncomingMessage *message = (TSIncomingMessage *)notification.object;
    [self.disappearingMessagesJob setExpirationForMessage:message];
    [self.sendReadReceiptsJob runWith:message];
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

NS_ASSUME_NONNULL_END
