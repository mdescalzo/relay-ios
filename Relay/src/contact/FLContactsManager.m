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

@import Contacts;

static const NSString *const databaseName = @"ForstaContacts.sqlite";
static NSString *keychainService          = @"TSKeyChainService";
static NSString *keychainDBPassAccount    = @"TSDatabasePass";

typedef BOOL (^ContactSearchBlock)(id, NSUInteger, BOOL *);

@interface FLContactsManager()

@property (strong) YapDatabase *database;
@property (nonatomic, strong) NSString *dbPath;
@property (nonatomic, strong) PropertyListPreferences *prefs;
@property ObservableValueController *observableContactsController;
@property TOCCancelTokenSource *life;
@property(atomic, copy) NSDictionary *latestRecipientsById;
@property (strong, nonatomic) NSMutableArray<SignalRecipient *> *activeRecipientsBacker;
@property (strong, nonatomic) NSCompoundPredicate *visibleRecipientsPredicate;
@property (strong) CNContactStore *contactStore;

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
        
        _database = [[YapDatabase alloc] initWithPath:self.dbPath
                                              options:options];
        _backgroundConnection = [self.database newConnection];
        _mainConnection = [self.database newConnection];
        
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(processUsersBlob)
                                                     name:FLCCSMUsersUpdated
                                                   object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(processTags)
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
-(void)processTags
{
    [self.backgroundConnection asyncReadWriteWithBlock:^(YapDatabaseReadWriteTransaction * _Nonnull transaction) {
        
        // Look for badly formed tags and fix them
        [[FLTag allObjectsInCollection] enumerateObjectsUsingBlock:^(id  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
            FLTag *aTag = (FLTag *)obj;
            if (aTag.recipientIds.count == 0) {
                NSDictionary *results = [FLTagMathService syncTagLookupWithString:aTag.displaySlug];
                NSArray *uids = [results objectForKey:@"userids"];
                aTag.recipientIds = [NSCountedSet setWithArray:uids];
                [aTag saveWithTransaction:transaction];
            }
        }];
    }];
}

#pragma mark - Recipient/Contact management
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

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [_life cancel];
}

- (void)doAfterEnvironmentInitSetup
{
    // Lookup compare locally stored contacts to those in Atlas for "public" only
    if ([[SignalRecipient selfRecipient].orgSlug isEqualToString:FLPublicDomainName]) {
        if (SYSTEM_VERSION_GREATER_THAN_OR_EQUAL_TO(_iOS_9)) {
            self.contactStore = [[CNContactStore alloc] init];
            [self.contactStore requestAccessForEntityType:CNEntityTypeContacts
                                        completionHandler:^(BOOL granted, NSError *_Nullable error) {
                                            if (granted) {
                                                __block NSMutableSet *contactPhoneNumbers = [NSMutableSet new];
                                                NSArray *keysToFetch = @[ CNContactPhoneNumbersKey ];
                                                CNContactFetchRequest *fetchRequest = [[CNContactFetchRequest alloc] initWithKeysToFetch:keysToFetch];
                                                
                                                NSError *fetchError = nil;
                                                if (![self.contactStore enumerateContactsWithFetchRequest:fetchRequest
                                                                                                   error:&fetchError
                                                                                              usingBlock:^(CNContact * _Nonnull contact, BOOL * _Nonnull stop) {
                                                                                                  for (CNPhoneNumber *phoneNumber in contact.phoneNumbers) {
                                                                                                      [contactPhoneNumbers addObject:phoneNumber.stringValue];
                                                                                                  }
                                                                                              }]) {
                                                                                                  DDLogDebug(@"Enumeration of local contacts failed.  Error: %@", error.description);
                                                }
                                                DDLogDebug(@"Pulled phone #s: %@", contactPhoneNumbers);
                                            } else {
                                                DDLogDebug(@"User denied access to local Contacts.");
                                            }
                                        }];
        }
    }
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
    [self processUsersBlob];
}

-(void)processUsersBlob
{
    NSDictionary *usersBlob = [[Environment getCurrent].ccsmStorage getUsers];
    
    if (usersBlob.count > 0) {
        [self.backgroundConnection asyncReadWriteWithBlock:^(YapDatabaseReadWriteTransaction *transaction)
         {
             for (NSDictionary *userDict in usersBlob.allValues) {
                 SignalRecipient *newRecipient = [SignalRecipient recipientForUserDict:userDict];
                 if (newRecipient.isActive) {
                     [newRecipient saveWithTransaction:transaction];
                 } else {
                     [newRecipient removeWithTransaction:transaction];
                 }
             }
         }];
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
    // Check to see if we already it locally
    for (SignalRecipient *contact in self.allRecipients) {
        if ([contact.uniqueId isEqualToString:userID]) {
            return contact;
        }
    }
    
    // If not, go get it, build it, and save it.
    SignalRecipient *recipient = [CCSMCommManager recipientFromCCSMWithID:userID];
    if (recipient) {
        [self saveRecipient:recipient];
    }
    
    return recipient;
}

-(SignalRecipient *_Nullable)recipientWithUserID:(NSString *_Nonnull)userID transaction:(YapDatabaseReadWriteTransaction *_Nonnull)transaction
{
    // Check to see if we already it locally
    for (SignalRecipient *contact in self.allRecipients) {
        if ([contact.uniqueId isEqualToString:userID]) {
            return contact;
        }
    }
    
    // If not, go get it, build it, and save it.
    SignalRecipient *recipient = [CCSMCommManager recipientFromCCSMWithID:userID];
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

- (NSString *)nameStringForContactID:(NSString *)identifier
{
    SignalRecipient *recipient = [[Environment getCurrent].contactsManager recipientWithUserID:identifier];
    if (recipient.fullName) {
        return recipient.fullName;
    } else if (recipient.flTag.slug){
        return recipient.flTag.slug;
    } else {
        return NSLocalizedString(@"UNKNOWN_CONTACT_NAME",
                                 @"Displayed if for some reason we can't determine a contacts ID *or* name");
    }
}

-(UIImage *)imageForIdentifier:(NSString *)uid
{
    __block UIImage *returnImage = nil;
    [self.allRecipients enumerateObjectsUsingBlock:^(SignalRecipient * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        if ([obj.uniqueId isEqualToString:uid]) {
            if (self.prefs.useGravatars) {
                returnImage = obj.gravatarImage;
            } else {
                returnImage = obj.avatar;
            }
            *stop = YES;
        }
    }];
    
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
