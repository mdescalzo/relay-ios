//
//  FLMessageSender.h
//  Forsta
//
//  Created by Mark on 6/15/17.
//  Copyright © 2017 Forsta. All rights reserved.
//

#import "OWSMessageSender.h"

@class OutgoingControlMessage;

@interface FLMessageSender : OWSMessageSender

-(void)sendControlMessage:(OutgoingControlMessage *)message
             toRecipients:(NSCountedSet<NSString *> *)recipientIds
                  success:(void (^)())successHandler
                  failure:(void (^)(NSError *error))failureHandler;

- (void)sendSyncTranscriptForMessage:(TSOutgoingMessage *)message;

@end
