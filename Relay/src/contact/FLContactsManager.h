//
//  FLContactsManager.h
//  Forsta
//
//  Created by Mark on 6/26/17.
//  Copyright © 2017 Forsta. All rights reserved.
//

#import "OWSContactsManager.h"
#import "Contact.h"

@interface FLContactsManager : OWSContactsManager

// Override to include CCSM sourced contacts.
- (NSArray<Contact *> *)ccsmContacts;
- (NSArray<Contact *> *)allContacts;
- (NSArray<Contact *> *)allValidContacts;

-(void)refreshCCSMContacts;

@end
