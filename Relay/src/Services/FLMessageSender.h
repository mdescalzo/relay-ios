//
//  FLMessageSender.h
//  Forsta
//
//  Created by Mark on 6/15/17.
//  Copyright © 2017 Forsta. All rights reserved.
//

#import "OWSMessageSender.h"

@class FLControlMessage;

@interface FLMessageSender : OWSMessageSender

-(void)sendControlMessage:(FLControlMessage *)message toRecipients:(NSCountedSet<NSString *> *)recipientIds;

@end
