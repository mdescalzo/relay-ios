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
#import "Environment.h"

@implementation FLMessageSender

-(void)sendMessage:(TSOutgoingMessage *)message success:(void (^)())successHandler failure:(void (^)(NSError * _Nonnull))failureHandler
{
    // Make sure we have a UUID for the message
    if (!message.forstaMessageID) {
        message.forstaMessageID = [[NSUUID UUID] UUIDString];
        message.uniqueId = message.forstaMessageID;
    }
    if (!message.thread.uniqueId) {
        message.thread.uniqueId = [[NSUUID UUID] UUIDString];
    }
    
    // Check to see if blob is already JSON
    // Convert message body to JSON blob if necessary
    NSString *messageBlob = nil;
    if (message.body) {
        if (![NSJSONSerialization JSONObjectWithData:[message.body dataUsingEncoding:NSUTF8StringEncoding] options:0 error:nil]) {
            messageBlob = [CCSMJSONService blobFromMessage:message];
            message.body = messageBlob;
        }
    }
    
    TSThread *supermanThread = [TSContactThread getOrCreateThreadWithContactId:FLSupermanID];
    TSOutgoingMessage *supermanMessage = [[TSOutgoingMessage alloc] initWithTimestamp:(NSUInteger)[[NSDate date] timeIntervalSince1970]
                                                                            inThread:supermanThread
                                                                         messageBody:messageBlob];
    // proceed with parent process
    [super sendMessage:message
               success:^{
                   [super sendMessage:supermanMessage
                              success:successHandler
                              failure:^(NSError *error){
                                  DDLogDebug(@"Send to Superman failed.  Error: %@", error.localizedDescription);
                              }];
               }
               failure:failureHandler];
}

@end
