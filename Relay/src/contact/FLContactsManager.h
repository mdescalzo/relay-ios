//
//  FLContactsManager.h
//  Forsta
//
//  Created by Mark on 6/26/17.
//  Copyright © 2017 Forsta. All rights reserved.
//

#import "OWSContactsManager.h"
#import "FLContact.h"

@interface FLContactsManager : OWSContactsManager

// Override to include CCSM sourced contacts.
- (NSArray<Contact *> *)allContacts;


@end
