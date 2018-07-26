//  Created by Frederic Jacobs on 12/11/14.
//  Copyright (c) 2014 Open Whisper Systems. All rights reserved.

#import "TSInteraction.h"
#import "TSDatabaseSecondaryIndexes.h"
#import "TSStorageManager+messageIDs.h"
#import "TSThread.h"
#import "NSDate+millisecondTimeStamp.h"

@implementation TSInteraction

+ (instancetype)interactionForTimestamp:(uint64_t)timestamp
                        withTransaction:(YapDatabaseReadWriteTransaction *)transaction {
    __block int counter = 0;
    __block TSInteraction *interaction;

    [TSDatabaseSecondaryIndexes
        enumerateMessagesWithTimestamp:timestamp
                             withBlock:^(NSString *collection, NSString *key, BOOL *stop) {

                                 if (counter != 0) {
                                     DDLogWarn(@"The database contains two colliding timestamps at: %lld.", timestamp);
                                     return;
                                 }

                                 interaction = [TSInteraction fetchObjectWithUniqueID:key transaction:transaction];

                                 counter++;
                             }
                      usingTransaction:transaction];

    return interaction;
}

+ (NSString *)collection {
    return @"TSInteraction";
}

- (instancetype)initWithTimestamp:(uint64_t)timestamp inThread:(TSThread *)thread
{
    self = [super initWithUniqueId:nil];

    if (!self) {
        return self;
    }

    _timestamp = timestamp;
    _uniqueThreadId = thread.uniqueId;
    _thread = thread;

    return self;
}


#pragma mark Date operations

- (uint64_t)millisecondsTimestamp {
    return self.timestamp;
}

- (NSDate *)date {
    uint64_t seconds = self.timestamp / 1000;
    return [NSDate dateWithTimeIntervalSince1970:seconds];
}

+ (NSString *)stringFromTimeStamp:(uint64_t)timestamp {
    return [[NSNumber numberWithUnsignedLongLong:timestamp] stringValue];
}

+ (uint64_t)timeStampFromString:(NSString *)string {
    NSNumberFormatter *f = [[NSNumberFormatter alloc] init];
    [f setNumberStyle:NSNumberFormatterNoStyle];
    NSNumber *myNumber = [f numberFromString:string];
    return [myNumber unsignedLongLongValue];
}

- (NSString *)description {
    return @"Interaction description";
}

- (void)saveWithTransaction:(YapDatabaseReadWriteTransaction *)transaction {
    if (!self.uniqueId) {
        self.uniqueId = [TSStorageManager getAndIncrementMessageIdWithProtocolContext:transaction];
    }

    [super saveWithTransaction:transaction];
    [self.thread updateWithLastMessage:self transaction:transaction];
}

-(NSMutableDictionary *)forstaPayload
{
    if (_forstaPayload == nil) {
        _forstaPayload = [NSMutableDictionary new];
    }
    return _forstaPayload;
}

-(NSDate *)sendTime
{
    NSDate *returnDate = nil;
    // FIXME: The formatters in their presenst state don't work.  Falling back on self.timestamp
    if ([self.forstaPayload objectForKey:@"sendTime"]) {
        if ([[[UIDevice currentDevice] systemVersion] floatValue] < 10.0) {
            NSDateFormatter *df = [[NSDateFormatter alloc] init];
            NSLocale *enUSPOSIXLocale = [NSLocale localeWithLocaleIdentifier:@"en_US_POSIX"];
            [df setLocale:enUSPOSIXLocale];
            [df setDateFormat:@"yyyy-MM-dd'T'HH:mm:ssZZZZZ"];
            returnDate = [df dateFromString:[self.forstaPayload objectForKey:@"sendTime"]];
        } else {
            NSISO8601DateFormatter *df = [[NSISO8601DateFormatter alloc] init];
            NSISO8601DateFormatOptions options = NSISO8601DateFormatWithInternetDateTime;
            df.formatOptions = options;
            returnDate = [df dateFromString:[self.forstaPayload objectForKey:@"sendTime"]];
        }
    }
    if (returnDate) {
        return returnDate;
    } else {
        return [NSDate ows_dateWithMillisecondsSince1970:self.timestamp];
    }
}

@end
