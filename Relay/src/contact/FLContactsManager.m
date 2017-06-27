//
//  FLContactsManager.m
//  Forsta
//
//  Created by Mark on 6/26/17.
//  Copyright © 2017 Forsta. All rights reserved.
//

#import "FLContactsManager.h"
#import "CCSMStorage.h"

@interface FLContactsManager()

@property (nonatomic, strong) NSArray *ccsmContacts;

@end

@implementation FLContactsManager

- (NSArray<Contact *> *)allContacts {
 
    NSMutableArray *abContacts = [[super allContacts] mutableCopy];

//    // Look for duplicates between the two and merge
    NSPredicate *aPredicate = [NSPredicate predicateWithFormat:@"NONE %@.firstName == firstName", self.ccsmContacts];
    NSPredicate *bPredicate = [NSPredicate predicateWithFormat:@"NONE %@.lastName == lastName", self.ccsmContacts];
    NSCompoundPredicate *predicate = [NSCompoundPredicate andPredicateWithSubpredicates:@[aPredicate, bPredicate]];
    NSMutableArray *resultsArray = [[abContacts filteredArrayUsingPredicate:predicate] mutableCopy];
    [resultsArray addObjectsFromArray:self.ccsmContacts];
    
    return resultsArray;
//    return self.ccsmContacts ;
}


#pragma mark - Lazy Instantiation
-(NSArray<Contact *> *)ccsmContacts
{
    if (_ccsmContacts == nil) {
        NSMutableArray *tmpArray = [NSMutableArray new];
        
        NSDictionary *tagsBlob = [[CCSMStorage new] getTags];
        
        for (NSString *key in tagsBlob.allKeys) {
            NSDictionary *tmpDict = [tagsBlob objectForKey:key];
            NSDictionary *userDict = [tmpDict objectForKey:tmpDict.allKeys.lastObject];
            
            // Filter out superman, no one sees superman
            if (!([[userDict objectForKey:@"phone"] isEqualToString:FLSupermanDevID] ||
                [[userDict objectForKey:@"phone"] isEqualToString:FLSupermanStageID] ||
                [[userDict objectForKey:@"phone"] isEqualToString:FLSupermanProdID])) {
                
                FLContact *contact = [[FLContact alloc] initWithContactWithFirstName:[userDict objectForKey:@"first_name"]
                                                                         andLastName:[userDict objectForKey:@"last_name"]
                                                             andUserTextPhoneNumbers:@[ [userDict objectForKey:@"phone"] ]
                                                                            andImage:nil
                                                                        andContactID:0];
                contact.tag = key;
                
                [tmpArray addObject:contact];
            }
        }
        _ccsmContacts = [NSArray arrayWithArray:tmpArray];
    }
    return _ccsmContacts;
}

@end
