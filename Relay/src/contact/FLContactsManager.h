//
//  FLContactsManager.h
//  Forsta
//
//  Created by Mark on 8/22/17.
//  Copyright © 2017 Forsta. All rights reserved.
//

#import "SignalRecipient.h"
#import <YapDatabase/YapDatabase.h>

#import <Foundation/Foundation.h>

@interface FLContactsManager : NSObject

@property (nonatomic, strong) YapDatabaseConnection * _Nonnull mainConnection;
@property (strong) YapDatabaseConnection * _Nonnull backgroundConnection;

//-(void)setupDatabase;

-(SignalRecipient *_Nonnull)getOrCreateContactWithUserID:(NSString *_Nonnull)userID;
-(SignalRecipient *_Nullable)recipientWithUserID:(NSString *_Nonnull)userID;
-(NSSet<SignalRecipient *> *_Nonnull)allContacts;
-(void)saveContact:(SignalRecipient *_Nonnull)recipient;

@end
