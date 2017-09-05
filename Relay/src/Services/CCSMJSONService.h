//
//  CCSMJSONService.h
//  Forsta
//
//  Created by Mark on 6/15/17.
//  Copyright © 2017 Forsta. All rights reserved.
//

#import <Foundation/Foundation.h>

@class TSOutgoingMessage;

@interface CCSMJSONService : NSObject

+(NSString *_Nullable)blobFromMessage:(TSOutgoingMessage *_Nonnull)message;
+(nullable NSArray *)arrayFromMessageBody:(NSString *_Nonnull)body;

@end
