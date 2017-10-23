//
//  FLControlMessage.m
//  
//
//  Created by Mark on 10/18/17.
//

#import "FLControlMessage.h"
#import "NSDate+millisecondTimeStamp.h"

@implementation FLControlMessage

-(instancetype _Nonnull)initThreadUpdateControlMessageForThread:(TSThread *_Nonnull)thread ofType:(NSString *)controlType;
{
    self = (FLControlMessage *)[super initWithTimestamp:[NSDate ows_millisecondTimeStamp] inThread:thread];
    self.messageType = @"control";
    self.uniqueId = [[NSUUID UUID] UUIDString];
    _controlMessageType = controlType;
    
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

@end
