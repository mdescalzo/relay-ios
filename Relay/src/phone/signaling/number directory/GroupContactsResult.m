//
//  GroupContactsResult.m
//  Signal
//
//  Created by Frederic Jacobs on 17/02/15.
//  Copyright (c) 2015 Open Whisper Systems. All rights reserved.
//

#import "GroupContactsResult.h"

#import "TSAccountManager.h"
#import "SignalRecipient.h"
#import "FLContactsManager.h"
#import "Environment.h"
#import "SignalKeyingStorage.h"

@interface GroupContactsResult ()

@property NSMutableArray *unknownNumbers;
@property NSMutableArray *knownNumbers;

@property NSMutableDictionary *associatedContactDict;

@end

@implementation GroupContactsResult

- (instancetype)initWithMembersId:(NSArray *)memberIdentifiers without:(NSArray *)removeIds {
    self = [super init];

    FLContactsManager *manager = [Environment.getCurrent contactsManager];

    NSMutableSet *remainingIdentifiers = [NSMutableSet setWithArray:memberIdentifiers];

    NSMutableArray *knownNumbers       = [NSMutableArray array];
    NSMutableArray *associatedContacts = [NSMutableArray array];

    for (NSString *identifier in memberIdentifiers) {
        if ([identifier isEqualToString:TSAccountManager.sharedInstance.myself.uniqueId]) {
            // remove local number

            [remainingIdentifiers removeObject:identifier];
            continue;
        }

        if (removeIds && [removeIds containsObject:identifier]) {
            // Remove ids
            [remainingIdentifiers removeObject:identifier];
            continue;
        }

        SignalRecipient *contact = [manager recipientWithUserId:identifier];
        
        if (!contact) {
            continue;
        }

        [knownNumbers addObject:identifier];
        [associatedContacts addObject:contact];

        [remainingIdentifiers removeObject:identifier];
    }

    _unknownNumbers = [NSMutableArray arrayWithArray:[remainingIdentifiers allObjects]];
    [_unknownNumbers sortUsingComparator:^NSComparisonResult(id obj1, id obj2) {
      return [obj1 compare:obj2 options:0];
    }];


    // Populate mapping dictionary.
    _associatedContactDict = [NSMutableDictionary dictionary];
    for (NSUInteger i = 0; i < [knownNumbers count]; i++) {
        NSString *identifier = [knownNumbers objectAtIndex:i];
        SignalRecipient *contact     = [associatedContacts objectAtIndex:i];

        [_associatedContactDict setObject:contact forKey:identifier];
    }

    // Known Numbers
    _knownNumbers = [NSMutableArray arrayWithArray:knownNumbers];
    [_knownNumbers sortedArrayUsingComparator:^NSComparisonResult(id obj1, id obj2) {
      SignalRecipient *contact1 = [_associatedContactDict objectForKey:obj1];
      SignalRecipient *contact2 = [_associatedContactDict objectForKey:obj2];

      return [[manager class] recipientComparator](contact1, contact2);
    }];

    return self;
}

- (NSUInteger)numberOfMembers {
    return [self.knownNumbers count] + [self.unknownNumbers count];
}

- (BOOL)isContactAtIndexPath:(NSIndexPath *)indexPath {
    if ((NSUInteger)indexPath.row < [self.unknownNumbers count]) {
        return NO;
    } else {
        return YES;
    }
}

- (SignalRecipient *)contactForIndexPath:(NSIndexPath *)indexPath {
    if ([self isContactAtIndexPath:indexPath]) {
        NSString *identifier = [_knownNumbers objectAtIndex:[self knownNumbersIndexForIndexPath:indexPath]];
        return [_associatedContactDict objectForKey:identifier];
    } else {
        NSAssert(NO, @"Trying to retrieve contact from array at an index that is not a contact.");
        return nil;
    }
}

- (NSString *)identifierForIndexPath:(NSIndexPath *)indexPath {
    if ([self isContactAtIndexPath:indexPath]) {
        return [_knownNumbers objectAtIndex:[self knownNumbersIndexForIndexPath:indexPath]];
    } else {
        return [_unknownNumbers objectAtIndex:(NSUInteger)indexPath.row];
    }
}

- (NSUInteger)knownNumbersIndexForIndexPath:(NSIndexPath *)indexPath {
    NSAssert(((NSUInteger)indexPath.row >= [_unknownNumbers count]), @"Wrong index for known number");

    return (NSUInteger)indexPath.row - [_unknownNumbers count];
}

@end
