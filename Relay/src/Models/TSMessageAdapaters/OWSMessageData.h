//  Created by Michael Kirk on 9/26/16.
//  Copyright © 2016 Open Whisper Systems. All rights reserved.

#import "OWSMessageEditing.h"
#import <JSQMessagesViewController/JSQMessageData.h>
#import <JSQMessagesViewController/JSQMessageAttributedData.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, TSMessageAdapterType) {
    TSIncomingMessageAdapter,
    TSOutgoingMessageAdapter,
    TSCallAdapter,
    TSInfoMessageAdapter,
    TSErrorMessageAdapter,
    TSMediaAttachmentAdapter,
    TSGenericTextMessageAdapter, // Used when message direction is unknown (outgoing or incoming)
    FLDocumentAttachmentAdapter,
};

@protocol OWSMessageData <JSQMessageAttributedData, OWSMessageEditing>

@property (nonatomic, readonly) TSMessageAdapterType messageType;
@property (nonatomic, readonly) TSInteraction *interaction;
@property (nonatomic, readonly) BOOL isExpiringMessage;
@property (nonatomic, readonly) BOOL isOutgoingAndDelivered;
@property (nonatomic, readonly) BOOL shouldStartExpireTimer;
@property (nonatomic, readonly) uint64_t expiresAtSeconds;
@property (nonatomic, readonly) uint32_t expiresInSeconds;

@end

NS_ASSUME_NONNULL_END
