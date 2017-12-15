//
//  FLControlMessage.m
//  
//
//  Created by Mark on 10/18/17.
//

#import "FLControlMessage.h"
#import "NSDate+millisecondTimeStamp.h"
#import "FLCCSMJSONService.h"

@implementation FLControlMessage

-(instancetype _Nonnull)initControlMessageForThread:(TSThread *_Nonnull)thread ofType:(NSString *)controlType;
{
    if (self = (FLControlMessage *)[super initWithTimestamp:[NSDate ows_millisecondTimeStamp]
                                                   inThread:thread messageBody:nil
                                              attachmentIds:[NSMutableArray new]]) {;
        self.messageType = @"control";
        self.uniqueId = [[NSUUID UUID] UUIDString];
        _controlMessageType = controlType;
        self.body = [FLCCSMJSONService blobFromMessage:self];
    }
    return self;
}

-(NSString *)plainTextBody
{
    return nil;
}

-(NSAttributedString *)attributedTextBody
{
    return nil;
}

-(void)save
{
    // never save control messages
    return;
}

-(void)saveWithTransaction:(YapDatabaseReadWriteTransaction *)transaction
{
    // never save control messages
    return;
}

@end
