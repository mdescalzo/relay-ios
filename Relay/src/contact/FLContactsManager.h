//
//  FLContactsManager.h
//  Forsta
//
//  Created by Mark on 8/22/17.
//  Copyright © 2017 Forsta. All rights reserved.
//

#import "Contact.h"
#import <YapDatabase/YapDatabase.h>

@import Foundation;

@interface FLContactsManager : NSObject

@property (nonatomic, strong) YapDatabaseConnection * _Nonnull mainConnection;
@property (nonatomic, strong) YapDatabaseConnection * _Nonnull backgroundConnection;

//-(void)setupDatabase;

-(Contact *_Nonnull)getOrCreateContactWithUserID:(NSString *_Nonnull)userID;
-(Contact *_Nullable)contactWithUserID:(NSString *_Nonnull)userID;
-(NSSet<Contact *> *_Nonnull)allContacts;
-(void)saveContact:(Contact *_Nonnull)contact;

@end
