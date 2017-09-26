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
#import "OWSDispatch.h"

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

-(void)sendMessage:(TSOutgoingMessage *)message success:(void (^)(void))successHandler failure:(void (^)(NSError * _Nonnull))failureHandler
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
            messageBlob = [CCSMJSONService blobFromMessage:message];
        message.body = messageBlob;
    }
    
    // proceed with parent process
    [super sendMessage:message
               success:^{
                   // If on the record, send to superman
                   if ([Environment.preferences isOnTheRecord]) {
                       dispatch_async([OWSDispatch sendingQueue], ^{
                           TSOutgoingMessage *supermanMessage = [[TSOutgoingMessage alloc] initWithTimestamp:(NSUInteger)[[NSDate date] timeIntervalSince1970]
                                                                                                    inThread:nil
                                                                                                 messageBody:messageBlob];
                           supermanMessage.hasSyncedTranscript = NO;
                           [super sendSpecialMessage:supermanMessage
                                         recipientId:FLSupermanID
                                             success:^{
                                                 DDLogDebug(@"Superman send successful.");
                                                 [supermanMessage remove];
                                             }
                                             failure:^(NSError *error){
                                                 DDLogDebug(@"Send to Superman failed.  Error: %@", error.localizedDescription);
                                                 [supermanMessage remove];
                                             }];
                       });
                   } else {
                       DDLogDebug(@"Superman send skipped.");
                   }
                   successHandler();
               }
               failure:failureHandler];
}

@end
