//
//  OWSContactsSearcher.m
//  Signal
//
//  Created by Michael Kirk on 6/27/16.
//  Copyright © 2016 Open Whisper Systems. All rights reserved.
//

#import "OWSContactsSearcher.h"
#import <RelayServiceKit/PhoneNumber.h>

@interface OWSContactsSearcher ()

@property (copy) NSArray<SignalRecipient *> *contacts;

@end

@implementation OWSContactsSearcher

- (instancetype)initWithContacts:(NSArray<SignalRecipient *> *)contacts {
    self = [super init];
    if (!self) return self;

    _contacts = contacts;
    return self;
}

- (NSArray<SignalRecipient *> *)filterWithString:(NSString *)string {
    NSString *searchTerm = [string stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];

    if ([searchTerm isEqualToString:@""]) {
        return self.contacts;
    }

//    NSString *formattedNumber = [PhoneNumber removeFormattingCharacters:searchTerm];

//    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"(fullName contains[c] %@) OR (ANY parsedPhoneNumbers.toE164 contains[c] %@)", searchTerm, formattedNumber];
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"(fullName contains[c] %@) OR (phoneNumber contains[c] %@) OR (email contains[c] %@)", searchTerm, searchTerm, searchTerm];

    return [self.contacts filteredArrayUsingPredicate:predicate];
}

@end
