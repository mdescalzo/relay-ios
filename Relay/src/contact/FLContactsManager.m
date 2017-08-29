//
//  FLContactsManager.m
//  Forsta
//
//  Created by Mark on 8/22/17.
//  Copyright © 2017 Forsta. All rights reserved.
//

#import "FLContactsManager.h"
#import <SAMKeychain/SAMKeychain.h>
#import <25519/Randomness.h>
#import "NSData+Base64.h"

static const NSString *const databaseName = @"ForstaContacts.sqlite";
static NSString *keychainService          = @"TSKeyChainService";
static NSString *keychainDBPassAccount    = @"TSDatabasePass";

@interface FLContactsManager()

@property (strong) YapDatabase *database;
@property (nonatomic, strong) NSString *dbPath;

@end


@implementation FLContactsManager

-(instancetype)init {
    if ([super init]) {
        YapDatabaseOptions *options = [YapDatabaseOptions new];
        options.corruptAction = YapDatabaseCorruptAction_Fail;
        options.cipherKeyBlock      = ^{
            return [self databasePassword];
        };
    
        _database = [[YapDatabase alloc] initWithPath:self.dbPath
                                              options:options];
        
        [self mainConnection];
        [self backgroundConnection];
    }
    return self;
}

- (NSData *)databasePassword
{
    [SAMKeychain setAccessibilityType:kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly];
    NSString *dbPassword = [SAMKeychain passwordForService:keychainService account:keychainDBPassAccount];
    
    if (!dbPassword) {
        dbPassword = [[Randomness generateRandomBytes:30] base64EncodedString];
        NSError *error;
        [SAMKeychain setPassword:dbPassword forService:keychainService account:keychainDBPassAccount error:&error];
        if (error) {
            // Sync log to ensure it logs before exiting
            NSLog(@"Exiting because we failed to set new DB password. error: %@", error);
            exit(1);
        } else {
            DDLogError(@"Succesfully set new DB password. First launch?");
        }
    }
    
    return [dbPassword dataUsingEncoding:NSUTF8StringEncoding];
}

#pragma mark - Contact management
-(SignalRecipient *_Nullable)recipientWithUserID:(NSString *_Nonnull)userID
{
    __block SignalRecipient *contact = nil;
    [self.mainConnection readWithBlock:^(YapDatabaseReadTransaction *transaction){
        contact = [transaction objectForKey:userID inCollection:[SignalRecipient collection]];
    }];
    return contact;
}

-(SignalRecipient *_Nonnull)getOrCreateContactWithUserID:(NSString *_Nonnull)userID
{
    __block SignalRecipient *contact = nil;
    [self.mainConnection readWriteWithBlock:^(YapDatabaseReadWriteTransaction *transaction) {
        contact = [transaction objectForKey:userID inCollection:[SignalRecipient collection]];
        if (!contact) {
            contact = [[SignalRecipient alloc] initWithUniqueId:userID];
            [contact saveWithTransaction:transaction];
        }
    }];
    return contact;
}

-(NSSet<SignalRecipient *> *)allContacts
{
    __block NSMutableSet *holdingSet = [NSMutableSet new];
    [self.mainConnection readWithBlock:^(YapDatabaseReadTransaction *transaction) {
        [transaction enumerateKeysAndObjectsInCollection:[SignalRecipient collection]
                                              usingBlock:^(NSString *key, id object, BOOL *stop){
                                                  if ([object isKindOfClass:[SignalRecipient class]]) {
                                                      SignalRecipient *contact = (SignalRecipient *)object;
                                                      [holdingSet addObject:contact];
                                                  }
                                              }];
    }];
    return [NSSet setWithSet:holdingSet];
}

-(void)saveContact:(SignalRecipient *_Nonnull)contact
{
    [self.backgroundConnection asyncReadWriteWithBlock:^(YapDatabaseReadWriteTransaction *transaction) {
        [transaction setObject:contact forKey:contact.uniqueId inCollection:[SignalRecipient collection]];
    }];
}


#pragma mark - lazy instantiation
-(NSString *)dbPath
{
    if (_dbPath.length == 0) {
        NSFileManager *fileManager = [NSFileManager defaultManager];
        NSURL *fileURL = [[fileManager URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask] lastObject];
        NSString *path = [fileURL path];
        _dbPath = [path stringByAppendingFormat:@"/%@", databaseName];
    }
    return _dbPath;
}

-(YapDatabaseConnection *)mainConnection
{
    if (_mainConnection == nil) {
        _mainConnection = [self.database newConnection];
    }
    return _mainConnection;
}

-(YapDatabaseConnection *)backgroundConnection
{
    if (_backgroundConnection == nil) {
        _backgroundConnection = [self.database newConnection];
    }
    return _backgroundConnection;
}


@end
