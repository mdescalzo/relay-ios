//
//  TSStorageManager+messageIDs.m
//  Signal
//
//  Created by Frederic Jacobs on 24/01/15.
//  Copyright (c) 2015 Open Whisper Systems. All rights reserved.
//

#import "TSStorageManager+messageIDs.h"

#define TSStorageParametersCollection @"TSStorageParametersCollection"
#define TSMessagesLatestId @"TSMessagesLatestId"

@implementation TSStorageManager (messageIDs)

+(NSString *)getAndIncrementMessageIdWithProtocolContext:(id)protocolContext
{
    __block NSString *messageId = nil;
    if (protocolContext == nil) {
        [TSStorageManager.sharedManager.dbConnection readWriteWithBlock:^(YapDatabaseReadWriteTransaction * _Nonnull transaction) {
            messageId = [self getAndIncrementMessageIdWithTransaction:transaction];
        }];
    } else {
        NSAssert([protocolContext class] == [YapDatabaseReadWriteTransaction class], @"protocolContext must be a YapDatabaseReadWriteTransaction");
        YapDatabaseReadWriteTransaction *transaction = (YapDatabaseReadWriteTransaction *)protocolContext;
        messageId = [self getAndIncrementMessageIdWithTransaction:transaction];
    }
    return messageId;
}

+ (NSString *)getAndIncrementMessageIdWithTransaction:(YapDatabaseReadWriteTransaction *)transaction {
    NSString *messageId = [transaction objectForKey:TSMessagesLatestId inCollection:TSStorageParametersCollection];
    if (!messageId) {
        messageId = @"0";
    }

    NSNumberFormatter *numberFormatter = [[NSNumberFormatter alloc] init];
    numberFormatter.numberStyle        = NSNumberFormatterDecimalStyle;
    NSNumber *myNumber                 = [numberFormatter numberFromString:messageId];

    unsigned long long nextMessageId = [myNumber unsignedLongLongValue];
    nextMessageId++;

    NSString *nextMessageIdString = [[NSNumber numberWithUnsignedLongLong:nextMessageId] stringValue];

    [transaction setObject:nextMessageIdString forKey:TSMessagesLatestId inCollection:TSStorageParametersCollection];

    return messageId;
}

@end
