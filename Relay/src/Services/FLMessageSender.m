//
//  FLMessageSender.m
//  Forsta
//
//  Created by Mark on 6/15/17.
//  Copyright © 2017 Forsta. All rights reserved.
//

#import "FLMessageSender.h"
#import "CCSMJSONService.h"

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
    
    // proceed with parent process
    
    [super sendMessage:message success:successHandler failure:failureHandler];
}

@end
