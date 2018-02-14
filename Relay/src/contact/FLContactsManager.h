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

@interface FLContactsManager : NSObject // <ContactsManagerProtocol>

@property (nonatomic, strong) YapDatabaseConnection * _Nonnull mainConnection;
@property (strong) YapDatabaseConnection * _Nonnull backgroundConnection;

@property (nonatomic, strong) NSArray<SignalRecipient *> * _Nonnull allRecipients;
@property (nonatomic, strong) NSArray<SignalRecipient *> * _Nonnull activeRecipients;
@property (nonatomic, strong) NSCache * _Nonnull avatarCache;

+ (NSComparator _Nonnull )recipientComparator;

-(ObservableValue *_Nullable)getObservableContacts;
- (void)doAfterEnvironmentInitSetup;

-(void)updateRecipient:(NSString *_Nonnull)userId;
-(void)updateRecipient:(NSString *_Nonnull)userId withTransaction:(YapDatabaseReadWriteTransaction *_Nonnull)transaction;

-(SignalRecipient *_Nullable)recipientWithUserId:(NSString *_Nonnull)userId;
-(SignalRecipient *_Nullable)recipientWithUserId:(NSString *_Nonnull)userId transaction:(YapDatabaseReadWriteTransaction *_Nonnull)transaction;

-(void)refreshCCSMRecipients;

-(UIImage *_Nullable)imageForRecipientId:(NSString *_Nonnull)uid;
-(NSString *_Nullable)nameStringForContactId:(NSString *_Nonnull)uid;

-(void)saveRecipient:(SignalRecipient *_Nonnull)recipient;
-(void)saveRecipient:(SignalRecipient *_Nonnull)recipient withTransaction:(YapDatabaseReadWriteTransaction *_Nonnull)transaction;
-(void)removeRecipient:(SignalRecipient *_Nonnull)recipient;
-(void)removeRecipient:(SignalRecipient *_Nonnull)recipient withTransaction:(YapDatabaseReadWriteTransaction *_Nonnull)transaction;

-(void)saveTag:(FLTag *_Nonnull)recipient;
-(void)saveTag:(FLTag *_Nonnull)recipient withTransaction:(YapDatabaseReadWriteTransaction *_Nonnull)transaction;
-(void)removeTag:(FLTag *_Nonnull)recipient;
-(void)removeTag:(FLTag *_Nonnull)recipient withTransaction:(YapDatabaseReadWriteTransaction *_Nonnull)transaction;

-(void)nukeAndPave;

@end
