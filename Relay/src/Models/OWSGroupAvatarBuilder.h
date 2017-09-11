//  Created by Michael Kirk on 9/26/16.
//  Copyright © 2016 Open Whisper Systems. All rights reserved.

#import "OWSAvatarBuilder.h"

NS_ASSUME_NONNULL_BEGIN

@class TSThread;

@interface OWSGroupAvatarBuilder : OWSAvatarBuilder

- (instancetype)initWithThread:(TSThread *)thread;

@end

NS_ASSUME_NONNULL_END
