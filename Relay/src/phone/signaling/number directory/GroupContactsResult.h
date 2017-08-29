//
//  GroupContactsResult.h
//  Signal
//
//  Created by Frederic Jacobs on 17/02/15.
//  Copyright (c) 2015 Open Whisper Systems. All rights reserved.
//

#import <Foundation/Foundation.h>

@class SignalRecipient;

@interface GroupContactsResult : NSObject

- (instancetype)initWithMembersId:(NSArray *)memberIdentifiers without:(NSArray *)removeIds;

- (NSUInteger)numberOfMembers;

- (BOOL)isContactAtIndexPath:(NSIndexPath *)indexPath;

- (SignalRecipient *)contactForIndexPath:(NSIndexPath *)indexPath;
- (NSString *)identifierForIndexPath:(NSIndexPath *)indexPath;

@end
