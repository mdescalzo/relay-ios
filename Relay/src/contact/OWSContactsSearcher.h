//
//  OWSContactsSearcher.h
//  Signal
//
//  Created by Michael Kirk on 6/27/16.
//  Copyright © 2016 Open Whisper Systems. All rights reserved.
//

#import "SignalRecipient.h"

@interface OWSContactsSearcher : NSObject

- (instancetype)initWithContacts:(NSArray<SignalRecipient *> *)contacts;
- (NSArray<SignalRecipient *> *)filterWithString:(NSString *)string;

@end
