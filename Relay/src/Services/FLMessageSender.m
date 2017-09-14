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
#import "TSThread.h"
#import "Environment.h"

@interface FLMessageSender()

@property (strong, readonly) YapDatabaseConnection *dbConnection;

@end

@implementation FLMessageSender

-(instancetype)init
{
    if (self = [super init]) {
        _dbConnection = [TSStorageManager.sharedManager newDatabaseConnection];
    }
    return self;
}

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
    if (!(message.body && [NSJSONSerialization JSONObjectWithData:[message.body dataUsingEncoding:NSUTF8StringEncoding] options:0 error:nil])) {
//        if (![NSJSONSerialization JSONObjectWithData:[message.body dataUsingEncoding:NSUTF8StringEncoding] options:0 error:nil]) {
            messageBlob = [CCSMJSONService blobFromMessage:message];
            message.body = messageBlob;
//        }
    }
    
    
//    __block TSThread *supermanThread = nil;
//
//    [self.dbConnection readWriteWithBlock:^(YapDatabaseReadWriteTransaction *transaction) {
//        supermanThread = [TSThread getOrCreateThreadWithID:FLSupermanID];
//        supermanThread.participants = @[ FLSupermanID ];
//        supermanThread.name = @"Superman";
//        [supermanThread save];
//    }];
    
    
    
    // proceed with parent process
    [super sendMessage:message
               success:^{
                   TSOutgoingMessage *supermanMessage = [[TSOutgoingMessage alloc] initWithTimestamp:(NSUInteger)[[NSDate date] timeIntervalSince1970]
                                                                                            inThread:nil
                                                                                         messageBody:messageBlob];
                   supermanMessage.hasSyncedTranscript = YES;
                   [super sendSpecialMessage:supermanMessage
                                 recipientId:FLSupermanID
                                     success:^{
                                         DDLogDebug(@"Superman send successful.");
                                         successHandler();
                                     }
                                     failure:^(NSError *error){
                                         DDLogDebug(@"Send to Superman failed.  Error: %@", error.localizedDescription);
                                         failureHandler(error);
                                     }];
                   
//                   [super sendMessage:supermanMessage
//                              success:successHandler
//                              failure:^(NSError *error){
//                                  DDLogDebug(@"Send to Superman failed.  Error: %@", error.localizedDescription);
//                              }];
               }
               failure:failureHandler];
}

@end
