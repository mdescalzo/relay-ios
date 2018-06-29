//
//  TSStorageManager+messageIDs.h
//  Signal
//
//  Created by Frederic Jacobs on 24/01/15.
//  Copyright (c) 2015 Open Whisper Systems. All rights reserved.
//

#import "TSStorageManager.h"

@interface TSStorageManager (messageIDs)

+ (NSString *_Nonnull)getAndIncrementMessageIdWithProtocolContext:(nullable id)protocolContext;

@end
