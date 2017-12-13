//
//  FLContactsManager.h
//  Forsta
//
//  Created by Mark on 8/22/17.
//  Copyright © 2017 Forsta. All rights reserved.
//

#import "SignalRecipient.h"
#import <YapDatabase/YapDatabase.h>
#import "ObservableValue.h"
#import <Foundation/Foundation.h>
#import "PhoneNumber.h"

@interface FLContactsManager : NSObject <ContactsManagerProtocol>

@property (nonatomic, strong) YapDatabaseConnection * _Nonnull mainConnection;
@property (strong) YapDatabaseConnection * _Nonnull backgroundConnection;

@property (nonatomic, strong) NSArray<SignalRecipient *> * _Nonnull allRecipients;
@property (nonatomic, strong) NSArray<SignalRecipient *> * _Nonnull activeRecipients;

+ (NSComparator _Nonnull )recipientComparator;

-(void)setupDatabase;
-(ObservableValue *_Nullable)getObservableContacts;
- (void)doAfterEnvironmentInitSetup;
-(SignalRecipient *_Nonnull)getOrCreateContactWithUserID:(NSString *_Nonnull)userID;
-(SignalRecipient *_Nullable)recipientWithUserID:(NSString *_Nonnull)userID;
//-(NSArray<SignalRecipient *> *_Nonnull)allRecipients;
-(void)saveRecipient:(SignalRecipient *_Nonnull)recipient;
-(void)refreshRecipients;

@end
