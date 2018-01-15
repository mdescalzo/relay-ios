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
#import "Util.h"
#import "FLTagMathService.h"

static const NSString *const databaseName = @"ForstaContacts.sqlite";
static NSString *keychainService          = @"TSKeyChainService";
static NSString *keychainDBPassAccount    = @"TSDatabasePass";

typedef BOOL (^ContactSearchBlock)(id, NSUInteger, BOOL *);

@interface FLContactsManager()

@property (strong) YapDatabase *database;
//@property (nonatomic, strong) NSString *dbPath;
@property (nonatomic, strong) PropertyListPreferences *prefs;
@property ObservableValueController *observableContactsController;
@property TOCCancelTokenSource *life;
@property(atomic, copy) NSDictionary *latestRecipientsById;
@property (strong, nonatomic) NSMutableArray<SignalRecipient *> *activeRecipientsBacker;
@property (strong, nonatomic) NSCompoundPredicate *visibleRecipientsPredicate;
// TODO: Implement these
//@property (strong) NSCache *recipientCache;
//@property (strong) NSCache *tagCache;

@end


@implementation FLContactsManager

-(instancetype)init {
    if ([super init]) {
        _life = [TOCCancelTokenSource new];
        
        _observableContactsController = [ObservableValueController observableValueControllerWithInitialValue:nil];
        _latestRecipientsById = @{};
        
        YapDatabaseOptions *options = [YapDatabaseOptions new];
        options.corruptAction = YapDatabaseCorruptAction_Fail;
        options.cipherKeyBlock      = ^{
            return [self databasePassword];
        };
        
//        _database = [[YapDatabase alloc] initWithPath:self.dbPath
//                                                                options:options];
        _database = TSStorageManager.sharedManager.database;
        _backgroundConnection = [self.database newConnection];
        _backgroundConnection.permittedTransactions = YDB_AnyAsyncTransaction;
        _mainConnection = [self.database newConnection];
        
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(processUsersBlob)
                                                     name:FLCCSMUsersUpdated
                                                   object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(processTagsBlob)
                                                     name:FLCCSMTagsUpdated
                                                   object:nil];
        
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

#pragma mark - Tag management
-(void)processTagsBlob
{
    __block NSDictionary *tagsBlob = [[Environment getCurrent].ccsmStorage getTags];
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{
        [self.backgroundConnection asyncReadWriteWithBlock:^(YapDatabaseReadWriteTransaction * _Nonnull transaction) {
            for (NSDictionary *tagDict in [tagsBlob allValues]) {
                FLTag *aTag = [FLTag getOrCreateTagWithDictionary:tagDict transaction:transaction];
                if (aTag.recipientIds.count == 0) {
                    [aTag removeWithTransaction:transaction];
                }
            }
        }];
    });
}

#pragma mark - Recipient/Contact management
-(NSArray<SignalRecipient *> *)allRecipients
{
    // TODO: implement NSCache here?
    //    if (_allRecipients == nil) {
    //        _allRecipients = [SignalRecipient allObjectsInCollection];
    //    }
    //    return _allRecipients;
    return [SignalRecipient allObjectsInCollection];
}

-(NSArray<SignalRecipient *> *)activeRecipients
{
    NSPredicate *activePred = [NSPredicate predicateWithFormat:@"isActive == YES"];
    NSPredicate *monitorPred = [NSPredicate predicateWithFormat:@"isMonitor == NO"];
    NSCompoundPredicate *preds = [NSCompoundPredicate andPredicateWithSubpredicates:@[ activePred, monitorPred ]];
    NSArray *filteredArray = [self.allRecipients filteredArrayUsingPredicate:preds];
    return filteredArray;
}

-(void)saveContact:(SignalRecipient *_Nonnull)contact
{
    [self.backgroundConnection asyncReadWriteWithBlock:^(YapDatabaseReadWriteTransaction *transaction) {
        [transaction setObject:contact forKey:contact.uniqueId inCollection:[SignalRecipient collection]];
    }];
}


#pragma mark - lazy instantiation
//-(NSString *)dbPath
//{
//    if (_dbPath.length == 0) {
//        NSFileManager *fileManager = [NSFileManager defaultManager];
//        NSURL *fileURL = [[fileManager URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask] lastObject];
//        NSString *path = [fileURL path];
//        _dbPath = [path stringByAppendingFormat:@"/%@", databaseName];
//    }
//    return _dbPath;
//}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [_life cancel];
}

- (void)doAfterEnvironmentInitSetup {
#warning XXX is this method still necessary?
    //    if (SYSTEM_VERSION_GREATER_THAN_OR_EQUAL_TO(_iOS_9)) {
    //        self.contactStore = [[CNContactStore alloc] init];
    //        [self.contactStore requestAccessForEntityType:CNEntityTypeContacts
    //                                    completionHandler:^(BOOL granted, NSError *_Nullable error) {
    //                                      if (!granted) {
    //                                          // We're still using the old addressbook API.
    //                                          // User warned if permission not granted in that setup.
    //                                      }
    //                                    }];
    //    }
    
    //    [self setupAddressBook];
    
    [self.observableContactsController watchLatestValueOnArbitraryThread:^(NSArray *latestContacts) {
        @synchronized(self) {
            [self setupLatestRecipients:latestContacts];
        }
    }
                                                          untilCancelled:_life.token];
}

#pragma mark - Setup
-(void)refreshCCSMRecipients
{
    [CCSMCommManager refreshCCSMData];
}

-(void)processUsersBlob
{
    __block NSDictionary *usersBlob = [[Environment getCurrent].ccsmStorage getUsers];
    
    if (usersBlob.count > 0) {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{
            [self.backgroundConnection asyncReadWriteWithBlock:^(YapDatabaseReadWriteTransaction *transaction)
             {
                 for (NSDictionary *userDict in usersBlob.allValues) {
                     [SignalRecipient getOrCreateRecipientWithUserDictionary:userDict transaction:transaction];
                 }
             }];
        });
    }
}


- (void)setupLatestRecipients:(NSArray *)recipients {
    if (recipients) {
        self.latestRecipientsById = [FLContactsManager keyRecipientsById:recipients];
    }
}

#pragma mark - Observables

- (ObservableValue *)getObservableContacts {
    return self.observableContactsController;
}

#pragma mark - Contact/Phone Number util

-(void)saveRecipient:(SignalRecipient *)recipient
{
    //    [self.allRecipientsBacker addObject:recipient];
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{
        [self.backgroundConnection asyncReadWriteWithBlock:^(YapDatabaseReadWriteTransaction *transaction) {
            [transaction setObject:recipient forKey:recipient.uniqueId inCollection:[SignalRecipient collection]];
        }];
    });
}

-(SignalRecipient *)recipientWithUserID:(NSString *)userID
{
    // Check to see if we already have it locally
    for (SignalRecipient *recipient in self.allRecipients) {
        if ([recipient.uniqueId isEqualToString:userID]) {
            return recipient;
        }
    }
    
    // If not, go get it, build it, and save it.
    __block SignalRecipient *recipient = nil;
    [self.mainConnection readWriteWithBlock:^(YapDatabaseReadWriteTransaction * _Nonnull transaction) {
        if (!recipient) {
            recipient = [CCSMCommManager recipientFromCCSMWithID:userID transaction:transaction];
            if (recipient) {
                [recipient saveWithTransaction:transaction];
            }
        }
    }];
    return recipient;
}

-(SignalRecipient *_Nullable)recipientWithUserID:(NSString *_Nonnull)userID transaction:(YapDatabaseReadWriteTransaction *_Nonnull)transaction
{
    // Check to see if we already it locally
    for (SignalRecipient *recipient in self.allRecipients) {
        if ([recipient.uniqueId isEqualToString:userID]) {
            return recipient;
        }
    }
    
    // If not, go get it, build it, and save it.
    SignalRecipient *recipient = [CCSMCommManager recipientFromCCSMWithID:userID transaction:transaction];
    if (recipient) {
        [recipient saveWithTransaction:transaction];
    }
    
    return recipient;}

- (SignalRecipient *)latestRecipientForPhoneNumber:(PhoneNumber *)phoneNumber
{
    NSArray *allRecipients = [self allRecipients];
    
    ContactSearchBlock searchBlock = ^BOOL(SignalRecipient *contact, NSUInteger idx, BOOL *stop) {
        if ([contact.phoneNumber isEqual:phoneNumber.toE164]) {
            *stop = YES;
            return YES;
        }
        //      for (PhoneNumber *number in contact.phoneNumber) {
        //          if ([self phoneNumber:number matchesNumber:phoneNumber]) {
        //              *stop = YES;
        //              return YES;
        //          }
        //      }
        return NO;
    };
    
    NSUInteger contactIndex = [allRecipients indexOfObjectPassingTest:searchBlock];
    
    if (contactIndex != NSNotFound) {
        return allRecipients[contactIndex];
    } else {
        return nil;
    }
}

- (BOOL)phoneNumber:(PhoneNumber *)phoneNumber1 matchesNumber:(PhoneNumber *)phoneNumber2 {
    return [phoneNumber1.toE164 isEqualToString:phoneNumber2.toE164];
}


#warning keyRecipientsById may not be necessary with Address Book
+ (NSDictionary *)keyRecipientsById:(NSArray *)recipients {
    return [recipients keyedBy:^id(SignalRecipient *recipient) {
        return @((int)recipient.uniqueId);
    }];
}

-(void)refreshRecipients
{
    _allRecipients = nil;
    [self allRecipients];
}


+ (BOOL)name:(NSString *)nameString matchesQuery:(NSString *)queryString {
    NSCharacterSet *whitespaceSet = NSCharacterSet.whitespaceCharacterSet;
    NSArray *queryStrings         = [queryString componentsSeparatedByCharactersInSet:whitespaceSet];
    NSArray *nameStrings          = [nameString componentsSeparatedByCharactersInSet:whitespaceSet];
    
    return [queryStrings all:^int(NSString *query) {
        if (query.length == 0)
            return YES;
        return [nameStrings any:^int(NSString *nameWord) {
            NSStringCompareOptions searchOpts = NSCaseInsensitiveSearch | NSAnchoredSearch;
            return [nameWord rangeOfString:query options:searchOpts].location != NSNotFound;
        }];
    }];
}

#pragma mark - Whisper User Management

//- (NSArray *)getSignalUsersFromContactsArray:(NSArray *)contacts {
//    return [[contacts filter:^int(Contact *contact) {
//      return [contact isSignalContact];
//    }] sortedArrayUsingComparator:[[self class] contactComparator]];
//}

+ (NSComparator)recipientComparator {
    return ^NSComparisonResult(id obj1, id obj2) {
        SignalRecipient *contact1 = (SignalRecipient *)obj1;
        SignalRecipient *contact2 = (SignalRecipient *)obj2;
        
        BOOL firstNameOrdering = NO; // ABPersonGetSortOrdering() == kABPersonCompositeNameFormatFirstNameFirst ? YES : NO;
        
        if (firstNameOrdering) {
            return [contact1.firstName caseInsensitiveCompare:contact2.firstName];
        } else {
            return [contact1.lastName caseInsensitiveCompare:contact2.lastName];
        };
    };
}

-(NSString *_Nullable)nameStringForContactId:(NSString *_Nonnull)uid
{
    SignalRecipient *recipient = [self recipientWithUserID:uid];
    if (recipient.fullName) {
        return recipient.fullName;
    } else if (recipient.flTag.displaySlug){
        return recipient.flTag.displaySlug;
    } else {
        return NSLocalizedString(@"UNKNOWN_CONTACT_NAME",
                                 @"Displayed if for some reason we can't determine a contacts ID *or* name");
    }
}

-(UIImage *_Nullable)imageForRecipientId:(NSString *_Nonnull)uid
{
    __block UIImage *returnImage = nil;
    NSString *cacheKey = nil;
    if (self.prefs.useGravatars) {
        cacheKey = [NSString stringWithFormat:@"gravatar:%@", uid];
    } else {
        cacheKey = [NSString stringWithFormat:@"avatar:%@", uid];
    }
    returnImage = [self.avatarCache objectForKey:cacheKey];
    
    if (returnImage == nil) {
        [self.mainConnection readWriteWithBlock:^(YapDatabaseReadWriteTransaction * _Nonnull transaction) {
            SignalRecipient *recipient = [self recipientWithUserID:uid transaction:transaction];
            if (self.prefs.useGravatars) {
                returnImage = recipient.gravatarImage;
            } else {
                returnImage = recipient.avatar;
            }
        }];
    }
    if (returnImage) {
        [self.avatarCache setObject:returnImage forKey:cacheKey];
    }
    return returnImage;
}

#pragma mark - Accessors
-(PropertyListPreferences *)prefs
{
    if (_prefs == nil) {
        _prefs = Environment.preferences;
    }
    return _prefs;
}

-(NSCompoundPredicate *)visibleRecipientsPredicate
{
    if (_visibleRecipientsPredicate == nil) {
        NSPredicate *activePred = [NSPredicate predicateWithFormat:@"isActive == YES"];
        NSPredicate *monitorPred = [NSPredicate predicateWithFormat:@"isMonitor == NO"];
        _visibleRecipientsPredicate = [NSCompoundPredicate andPredicateWithSubpredicates:@[ activePred, monitorPred ]];
    }
    return _visibleRecipientsPredicate;
}

-(NSMutableArray<SignalRecipient *> *)activeRecipientsBacker
{
    if (_activeRecipientsBacker == nil) {
        _activeRecipientsBacker = [NSMutableArray new];
    }
    return _activeRecipientsBacker;
}

-(NSSet *)identifiersForTagSlug:(NSString *)tagSlug
{
    // TODO: BUILD THIS!
    return [NSSet new];
}

-(NSCache *)avatarCache
{
    if (_avatarCache == nil) {
        _avatarCache = [NSCache new];
    }
    return _avatarCache;
}

#pragma mark - Logging

+ (NSString *)tag
{
    return [NSString stringWithFormat:@"[%@]", self.class];
}

- (NSString *)tag
{
    return self.class.tag;
}

@end
