//  Created by Michael Kirk on 9/26/16.
//  Copyright © 2016 Open Whisper Systems. All rights reserved.

#import "OWSGroupAvatarBuilder.h"
#import "TSThread.h"
NS_ASSUME_NONNULL_BEGIN

@interface OWSGroupAvatarBuilder ()

@property (nonatomic, readonly) TSThread *thread;

@end

@implementation OWSGroupAvatarBuilder

- (instancetype)initWithThread:(TSThread *)thread
{
    self = [super init];
    if (!self) {
        return self;
    }

    _thread = thread;

    return self;
}

- (nullable UIImage *)buildSavedImage
{
    return self.thread.image;
}

- (UIImage *)buildDefaultImage
{
    return [UIImage imageNamed:@"empty-group-avatar-gray"];
}

@end

NS_ASSUME_NONNULL_END
