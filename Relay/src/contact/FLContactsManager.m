//
//  FLContactsManager.m
//  Forsta
//
//  Created by Mark on 6/26/17.
//  Copyright © 2017 Forsta. All rights reserved.
//

#import "FLContactsManager.h"
#import "Environment.h"

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

- (NSArray<Contact *> *)allValidContacts
{
    NSMutableArray *abContacts = [[super signalContacts] mutableCopy];
    
    //    // Look for duplicates between the two and merge
    NSPredicate *aPredicate = [NSPredicate predicateWithFormat:@"NONE %@.firstName == firstName", self.ccsmContacts];
    NSPredicate *bPredicate = [NSPredicate predicateWithFormat:@"NONE %@.lastName == lastName", self.ccsmContacts];
    NSCompoundPredicate *predicate = [NSCompoundPredicate andPredicateWithSubpredicates:@[aPredicate, bPredicate]];
    NSMutableArray *resultsArray = [[abContacts filteredArrayUsingPredicate:predicate] mutableCopy];
    [resultsArray addObjectsFromArray:self.ccsmContacts];
    
    return resultsArray;
}


#pragma mark - Lazy Instantiation
- (NSArray<Contact *> *)ccsmContacts;
{
    if (_ccsmContacts == nil) {
        NSMutableArray *tmpArray = [NSMutableArray new];
        
//        NSDictionary *tagsBlob = [Environment.ccsmStorage getTags];
        NSDictionary *usersBlob = [[Environment getCurrent].ccsmStorage getUsers];
//        NSDictionary *userInfo = [Environment.ccsmStorage getUserInfo];
        
        for (NSString *key in usersBlob.allKeys) {
//            NSDictionary *tmpDict = [usersBlob objectForKey:key];
            NSDictionary *userDict = [usersBlob objectForKey:key]; //[tmpDict objectForKey:tmpDict.allKeys.lastObject];
            
            // Filter out superman, no one sees superman
            if (!([[userDict objectForKey:@"phone"] isEqualToString:FLSupermanDevID] ||
                [[userDict objectForKey:@"phone"] isEqualToString:FLSupermanStageID] ||
                [[userDict objectForKey:@"phone"] isEqualToString:FLSupermanProdID])) {
                
                Contact *contact = [[Contact alloc] initWithContactWithFirstName:[userDict objectForKey:@"first_name"]
                                                                         andLastName:[userDict objectForKey:@"last_name"]
                                                             andUserTextPhoneNumbers:@[ [userDict objectForKey:@"phone"] ]
                                                                            andImage:nil
                                                                        andContactID:0];
                 contact.userID = [userDict objectForKey:@"id"];
                
                NSArray *tagsArray = [userDict objectForKey:@"tags"];
                for (NSDictionary *tag in tagsArray) {
                    if ([[tag objectForKey:@"association_type"] isEqualToString:@"USERNAME"]) {
                        contact.tagID = [tag objectForKey:@"id"];
                        
                        NSDictionary *subTag = [tag objectForKey:@"tag"];
                        contact.tagPresentation = [subTag objectForKey:@"slug"];
                        break;
                    }
                }
                
                [tmpArray addObject:contact];
            }
        }
        _ccsmContacts = [NSArray arrayWithArray:tmpArray];
    }
    return _ccsmContacts;
}

-(void)refreshCCSMContacts
{
    _ccsmContacts = nil;
    [self ccsmContacts];
}

@end
