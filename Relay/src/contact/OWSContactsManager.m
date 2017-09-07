#import "OWSContactsManager.h"
//#import "ContactsUpdater.h"
#import "Environment.h"
#import "Util.h"

#define ADDRESSBOOK_QUEUE dispatch_get_main_queue()

typedef BOOL (^ContactSearchBlock)(id, NSUInteger, BOOL *);

@interface OWSContactsManager ()

//@property id addressBookReference;
//@property TOCFuture *futureAddressBook;
@property ObservableValueController *observableContactsController;
@property TOCCancelTokenSource *life;
@property(atomic, copy) NSDictionary *latestRecipientsById;

@property (strong, atomic, readonly) YapDatabaseConnection *dbConnection;
@property (strong, atomic, readonly) YapDatabaseConnection *backgroundConnection;

@end

@implementation OWSContactsManager

@synthesize backgroundConnection = _backgroundConnection;
@synthesize dbConnection = _dbConnection;

- (void)dealloc {
    [_life cancel];
}

- (id)init {
    self = [super init];
    if (self) {
        _life = [TOCCancelTokenSource new];
        _observableContactsController = [ObservableValueController observableValueControllerWithInitialValue:nil];
        _latestRecipientsById = @{};
        _dbConnection = [[TSStorageManager sharedManager].database newConnection];
        _backgroundConnection = [[TSStorageManager sharedManager].database newConnection];
    }
    return self;
}

- (void)doAfterEnvironmentInitSetup {
    if (SYSTEM_VERSION_GREATER_THAN_OR_EQUAL_TO(_iOS_9)) {
        self.contactStore = [[CNContactStore alloc] init];
        [self.contactStore requestAccessForEntityType:CNEntityTypeContacts
                                    completionHandler:^(BOOL granted, NSError *_Nullable error) {
                                      if (!granted) {
                                          // We're still using the old addressbook API.
                                          // User warned if permission not granted in that setup.
                                      }
                                    }];
    }

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
#warning XXX Needs catch for failure to communicate with CCSM
    [[Environment getCurrent].ccsmCommManager refreshCCSMUsers];
    
    NSDictionary *usersBlob = [[Environment getCurrent].ccsmStorage getUsers];
    
    if (usersBlob.count > 0) {
        [self.dbConnection asyncReadWriteWithBlock:^(YapDatabaseReadWriteTransaction *transaction)
         {
             for (NSDictionary *userDict in usersBlob.allValues) {
                 SignalRecipient *newRecipient = [SignalRecipient recipientForUserDict:userDict];
                 [newRecipient saveWithTransaction:transaction];
             }
         }];
    } else {
#warning XXX Make call to CCSM to attempt to get users and repeat.
    }
}


- (void)setupLatestRecipients:(NSArray *)recipients {
    if (recipients) {
        self.latestRecipientsById = [OWSContactsManager keyRecipientsById:recipients];
    }
}

#pragma mark - Observables

- (ObservableValue *)getObservableContacts {
    return self.observableContactsController;
}

#pragma mark - Contact/Phone Number util

-(void)saveRecipient:(SignalRecipient *)recipient
{
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        [self.backgroundConnection asyncReadWriteWithBlock:^(YapDatabaseReadWriteTransaction *transaction) {
            [transaction setObject:recipient forKey:recipient.uniqueId inCollection:[SignalRecipient collection]];
        }];
    });
}

-(SignalRecipient *)recipientForUserID:(NSString *)userID
{
    __block SignalRecipient *recipient = nil;

    if (userID.length > 0) {
        [self.dbConnection readWithBlock:^(YapDatabaseReadTransaction *transaction) {
            recipient = [transaction objectForKey:userID inCollection:[SignalRecipient collection]];
        }];
    }
    
#warning XXX Lookup is broken. Causes main thread to block, freezing app.  Get more reliable method.
    if (!recipient) {
        recipient = [[Environment getCurrent].ccsmCommManager recipientFromCCSMWithID:userID synchronoous:YES];
        if (recipient) {
            [self saveRecipient:recipient];
        }
    }
    
    return recipient;
}

- (SignalRecipient *)latestRecipientForPhoneNumber:(PhoneNumber *)phoneNumber
{
    NSArray *allContacts = [self allContacts];

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

    NSUInteger contactIndex = [allContacts indexOfObjectPassingTest:searchBlock];

    if (contactIndex != NSNotFound) {
        return allContacts[contactIndex];
    } else {
        return nil;
    }
}

- (BOOL)phoneNumber:(PhoneNumber *)phoneNumber1 matchesNumber:(PhoneNumber *)phoneNumber2 {
    return [phoneNumber1.toE164 isEqualToString:phoneNumber2.toE164];
}

//- (NSArray *)phoneNumbersForRecord:(ABRecordRef)record {
//    ABMultiValueRef numberRefs = ABRecordCopyValue(record, kABPersonPhoneProperty);
//
//    @try {
//        NSArray *phoneNumbers = (__bridge_transfer NSArray *)ABMultiValueCopyArrayOfAllValues(numberRefs);
//
//        if (phoneNumbers == nil)
//            phoneNumbers = @[];
//
//        NSMutableArray *numbers = [NSMutableArray array];
//
//        for (NSUInteger i = 0; i < phoneNumbers.count; i++) {
//            NSString *phoneNumber = phoneNumbers[i];
//            [numbers addObject:phoneNumber];
//        }
//
//        return numbers;
//
//    } @finally {
//        if (numberRefs) {
//            CFRelease(numberRefs);
//        }
//    }
//}

#warning keyRecipientsById may not be necessary with Address Book
+ (NSDictionary *)keyRecipientsById:(NSArray *)recipients {
    return [recipients keyedBy:^id(SignalRecipient *recipient) {
      return @((int)recipient.uniqueId);
    }];
}

- (NSArray<SignalRecipient *> *)allContacts {
//    NSMutableArray *allContacts = [NSMutableArray array];
//
//    for (NSString *key in self.latestContactsById.allKeys) {
//        Contact *contact = [self.latestContactsById objectForKey:key];
//
//        if ([contact isKindOfClass:[Contact class]]) {
//            [allContacts addObject:contact];
//        }
//    }
//    return allContacts;
    return self.ccsmRecipients;
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

//- (NSArray<Contact *> *)signalContacts {
//    return [self getSignalUsersFromContactsArray:[self allContacts]];
//}

//- (NSArray *)textSecureContacts {
//    return [[self.allContacts filter:^int(Contact *contact) {
//      return [contact isSignalContact];
//    }] sortedArrayUsingComparator:[[self class] contactComparator]];
//}

//- (NSString *)nameStringForIdentifier:(NSString *)identifier
//{
//    SignalRecipient *recipient = [[Environment getCurrent].contactsManager recipientForUserID:identifier];
//    if (recipient.fullName) {
//        return recipient.fullName;
//    } else if (recipient.tagSlug){
//        return recipient.tagSlug;
//    } else {
//        return NSLocalizedString(@"UNKNOWN_CONTACT_NAME",
//                                 @"Displayed if for some reason we can't determine a contacts ID *or* name");
//    }
//}

- (UIImage *)imageForPhoneIdentifier:(NSString *)identifier {
    for (SignalRecipient *contact in self.allContacts) {
            if ([contact.uniqueId isEqualToString:identifier]) {
                return contact.avatar;
        }
    }
    return nil;
}

-(SignalRecipient *)recipientForUserDict:(NSDictionary *)userDict
{
    //    Contact *contact = [Contact getContactWithUserID:[userDict objectForKey:@"id"]];

    NSDictionary *tagDict = [userDict objectForKey:@"tag"];
    SignalRecipient *recipient = [[SignalRecipient alloc] initWithTextSecureIdentifier:[userDict objectForKey:@"id"]
                                                                             firstName:[userDict objectForKey:@"first_name"]
                                                                              lastName:[userDict objectForKey:@"last_name"]
                                                                               tagSlug:(tagDict ? [tagDict objectForKey:@"slug"] : nil)];
    recipient.email = [userDict objectForKey:@"email"];
    recipient.phoneNumber = [userDict objectForKey:@"phone"];

    return recipient;
}

- (NSString *)nameStringForContactID:(NSString *)identifier {
//    if (!identifier) {
//        return NSLocalizedString(@"UNKNOWN_CONTACT_NAME",
//                                 @"Displayed if for some reason we can't determine a contacts ID *or* name");
//    }
    SignalRecipient *recipient = [[Environment getCurrent].contactsManager recipientForUserID:identifier];
    if (recipient.fullName) {
        return recipient.fullName;
    } else if (recipient.tagSlug){
        return recipient.tagSlug;
    } else {
        return NSLocalizedString(@"UNKNOWN_CONTACT_NAME",
                                 @"Displayed if for some reason we can't determine a contacts ID *or* name");
    }
    
    
//    for (SignalRecipient *contact in [self ccsmRecipients]) {
//        if ([contact.uniqueId isEqualToString:identifier]) {
//            return contact.fullName;
//        }
//    }
//    return identifier;
}

- (UIImage *)imageForContactID:(NSString *)identifier {
    for (SignalRecipient *contact in self.allContacts) {
        if ([contact.uniqueId isEqualToString:identifier]) {
            return contact.avatar;
        }
    }
    return nil;
}

#pragma mark - Lazy Instantiation
- (NSArray<SignalRecipient *> *)ccsmRecipients;
{
    if (_ccsmRecipients == nil) {
        NSMutableArray *mArray = [[SignalRecipient allObjectsInCollection] mutableCopy];
        SignalRecipient *superman = [SignalRecipient recipientWithTextSecureIdentifier:FLSupermanID];
        if (superman) {
            [mArray removeObject:superman];
        }
        _ccsmRecipients = [NSArray arrayWithArray:mArray];
    }
    return _ccsmRecipients;
    
//    if (_ccsmContacts == nil) {
//        NSMutableArray *tmpArray = [NSMutableArray new];
//        
////        NSDictionary *tagsBlob = [Environment.ccsmStorage getTags];
//        NSDictionary *usersBlob = [[Environment getCurrent].ccsmStorage getUsers];
////        NSDictionary *userInfo = [Environment.ccsmStorage getUserInfo];
//        
//        for (NSString *key in usersBlob.allKeys) {
////            NSDictionary *tmpDict = [usersBlob objectForKey:key];
//            NSDictionary *userDict = [usersBlob objectForKey:key]; //[tmpDict objectForKey:tmpDict.allKeys.lastObject];
//            
//            // Filter out superman, no one sees superman
//            if (!([[userDict objectForKey:@"phone"] isEqualToString:FLSupermanDevID] ||
//                  [[userDict objectForKey:@"phone"] isEqualToString:FLSupermanStageID] ||
//                  [[userDict objectForKey:@"phone"] isEqualToString:FLSupermanProdID])) {
//                
//                [tmpArray addObject:[self contactForUserDict:userDict]];
//            }
//        }
//        _ccsmContacts = [NSArray arrayWithArray:tmpArray];
//    }
//    return _ccsmContacts;
}

-(void)refreshCCSMContacts
{
    _ccsmRecipients = nil;
    
    [self ccsmRecipients];
}

-(YapDatabaseConnection *)backgroundConnection
{
    if (_backgroundConnection == nil) {
        _backgroundConnection = [TSStorageManager.sharedManager.database newConnection];
    }
    return _backgroundConnection;
}


-(NSSet *)identifiersForTagSlug:(NSString *)tagSlug
{
    
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
