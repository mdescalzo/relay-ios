//
//  FLMessageSender.m
//  Forsta
//
//  Created by Mark on 6/15/17.
//  Copyright © 2017 Forsta. All rights reserved.
//

#import "FLMessageSender.h"
#import "CCSMJSONService.h"
#import "CCSMStorage.h"
#import "TSOutgoingMessage.h"
#import "TSContactThread.h"

@implementation FLMessageSender

-(void)sendMessage:(TSOutgoingMessage *)message success:(void (^)())successHandler failure:(void (^)(NSError * _Nonnull))failureHandler
{
    // send a copy to superman
    /*
        1) bust open the message
        2) make/get thread for Superman
        3) build/get JSON blob to act the messageBody
        4) build new TSOutgoingMessage
        5) send new TSOutgoinMessage
     */

    // Make sure we have a UUID for the message
    if (!message.uniqueId) {
        message.uniqueId = [[NSUUID UUID] UUIDString];
    }

    // Convert message body to JSON blob
    NSString *messageBlob = [CCSMJSONService blobFromMessage:message];
    message.body = messageBlob;
    
    TSThread *supermanThread = [TSContactThread getOrCreateThreadWithContactId:[[CCSMStorage new] supermanId]];
    
    TSOutgoingMessage *supermanMessage = [[TSOutgoingMessage alloc] initWithTimestamp:(NSUInteger)[[NSDate date] timeIntervalSince1970]
                                                                            inThread:supermanThread
                                                                         messageBody:messageBlob];

//    if (!supermanMessage.uniqueId) {
//        supermanMessage.uniqueId = message.uniqueId;
//    }
    
    // send to Superman
#warning Need alternative handlers for the Superman send
    [super sendMessage:supermanMessage success:successHandler failure:failureHandler];
    
    // proceed with parent process
    
    [super sendMessage:message success:successHandler failure:failureHandler];
}

@end
