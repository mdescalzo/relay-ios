//  Copyright © 2016 Open Whisper Systems. All rights reserved.

#import "OWSChunkedOutputStream.h"

NS_ASSUME_NONNULL_BEGIN

@class SignalRecipient;

@interface OWSContactsOutputStream : OWSChunkedOutputStream

- (void)writeContact:(SignalRecipient *)recipient;

@end

NS_ASSUME_NONNULL_END
