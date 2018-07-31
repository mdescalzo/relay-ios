//
//  Copyright (c) 2018 Open Whisper Systems. All rights reserved.
//

#import "TSCall.h"
#import "TSThread.h"
#import <YapDatabase/YapDatabaseConnection.h>
#import <YapDatabase/YapDatabaseTransaction.h>

NS_ASSUME_NONNULL_BEGIN

NSString *NSStringFromCallType(RPRecentCallType callType)
{
    switch (callType) {
            case RPRecentCallTypeIncoming:
            return @"RPRecentCallTypeIncoming";
            case RPRecentCallTypeOutgoing:
            return @"RPRecentCallTypeOutgoing";
            case RPRecentCallTypeIncomingMissed:
            return @"RPRecentCallTypeIncomingMissed";
            case RPRecentCallTypeOutgoingIncomplete:
            return @"RPRecentCallTypeOutgoingIncomplete";
            case RPRecentCallTypeIncomingIncomplete:
            return @"RPRecentCallTypeIncomingIncomplete";
            case RPRecentCallTypeIncomingMissedBecauseOfChangedIdentity:
            return @"RPRecentCallTypeIncomingMissedBecauseOfChangedIdentity";
            case RPRecentCallTypeIncomingDeclined:
            return @"RPRecentCallTypeIncomingDeclined";
            case RPRecentCallTypeOutgoingMissed:
            return @"RPRecentCallTypeOutgoingMissed";
    }
}

NSUInteger TSCallCurrentSchemaVersion = 1;

@interface TSCall ()

@property (nonatomic, getter=wasRead) BOOL read;

@property (nonatomic, readonly) NSUInteger callSchemaVersion;

@end

#pragma mark -

@implementation TSCall

- (instancetype)initWithTimestamp:(uint64_t)timestamp
                       withCallId:(NSString *)contactNumber
                         callType:(RPRecentCallType)callType
//                         inThread:(TSThread *)thread
{
    // TODO: Implement thread association
    self = [super initWithTimestamp:timestamp inThread:nil];
//    self = [super initInteractionWithTimestamp:timestamp inThread:nil];
    
    if (!self) {
        return self;
    }
    
    _callSchemaVersion = TSCallCurrentSchemaVersion;
    _callType = callType;
    
    // Ensure users are notified of missed calls.
    BOOL isIncomingMissed = (_callType == RPRecentCallTypeIncomingMissed
                             || _callType == RPRecentCallTypeIncomingMissedBecauseOfChangedIdentity);
    if (isIncomingMissed) {
        _read = NO;
    } else {
        _read = YES;
    }
    
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    self = [super initWithCoder:coder];
    if (!self) {
        return self;
    }
    
    if (self.callSchemaVersion < 1) {
        // Assume user has already seen any call that predate read-tracking
        _read = YES;
    }
    
    _callSchemaVersion = TSCallCurrentSchemaVersion;
    
    return self;
}

//- (OWSInteractionType)interactionType
//{
//    return OWSInteractionType_Call;
//}

- (NSString *)previewTextWithTransaction:(YapDatabaseReadTransaction *)transaction
{
    // We don't actually use the `transaction` but other sibling classes do.
    switch (_callType) {
            case RPRecentCallTypeIncoming:
            return NSLocalizedString(@"INCOMING_CALL", @"");
            case RPRecentCallTypeOutgoing:
            return NSLocalizedString(@"OUTGOING_CALL", @"");
            case RPRecentCallTypeIncomingMissed:
            return NSLocalizedString(@"MISSED_CALL", @"");
            case RPRecentCallTypeOutgoingIncomplete:
            return NSLocalizedString(@"OUTGOING_INCOMPLETE_CALL", @"");
            case RPRecentCallTypeIncomingIncomplete:
            return NSLocalizedString(@"INCOMING_INCOMPLETE_CALL", @"");
            case RPRecentCallTypeIncomingMissedBecauseOfChangedIdentity:
            return NSLocalizedString(@"INFO_MESSAGE_MISSED_CALL_DUE_TO_CHANGED_IDENITY", @"info message text shown in conversation view");
            case RPRecentCallTypeIncomingDeclined:
            return NSLocalizedString(@"INCOMING_DECLINED_CALL",
                                     @"info message recorded in conversation history when local user declined a call");
            case RPRecentCallTypeOutgoingMissed:
            return NSLocalizedString(@"OUTGOING_MISSED_CALL",
                                     @"info message recorded in conversation history when local user tries and fails to call another user.");
    }
}

#pragma mark - OWSReadTracking

- (uint64_t)expireStartedAt
{
    return 0;
}

- (BOOL)shouldAffectUnreadCounts
{
    return YES;
}

- (void)markAsReadAtTimestamp:(uint64_t)readTimestamp
              sendReadReceipt:(BOOL)sendReadReceipt
                  transaction:(YapDatabaseReadWriteTransaction *)transaction
{
    if (_read) {
        return;
    }
    
    DDLogDebug(
               @"%@ marking as read uniqueId: %@ which has timestamp: %llu", self.logTag, self.uniqueId, self.timestamp);
    _read = YES;
    
    if (transaction == nil) {
        [self save];
//         [self.thread touch];
    } else {
    [self saveWithTransaction:transaction];
//    [self.thread touchWithTransaction:transaction];
    }
    
    // Ignore sendReadReceipt - it doesn't apply to calls.
}

#pragma mark - Methods

- (void)updateCallType:(RPRecentCallType)callType
{
    [TSStorageManager.sharedManager.writeDbConnection readWriteWithBlock:^(YapDatabaseReadWriteTransaction *transaction) {
        [self updateCallType:callType transaction:transaction];
    }];
}

- (void)updateCallType:(RPRecentCallType)callType transaction:(YapDatabaseReadWriteTransaction *)transaction
{
    DDLogInfo(@"%@ updating call type of call: %@ -> %@ with uniqueId: %@ which has timestamp: %llu",
              self.logTag,
              NSStringFromCallType(_callType),
              NSStringFromCallType(callType),
              self.uniqueId,
              self.timestamp);
    
    _callType = callType;
    
    [self saveWithTransaction:transaction];
    
    // redraw any thread-related unread count UI.
    //    [self.thread touchWithTransaction:transaction];
}

@end

NS_ASSUME_NONNULL_END
