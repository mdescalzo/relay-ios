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
#warning XXX Needs catch for failure to communicate with CCSM
    [CCSMCommManager refreshCCSMData];
    
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
        // TODO: Make call to CCSM to attempt to get users and repeat.
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
    
    for (SignalRecipient *contact in self.allContacts) {
        if ([contact.uniqueId isEqualToString:userID]) {
            return contact;
        }
    }
    
    if (!recipient) {
        recipient = [CCSMCommManager recipientFromCCSMWithID:userID];
        [self.backgroundConnection readWriteWithBlock:^(YapDatabaseReadWriteTransaction *transaction){
            [recipient saveWithTransaction:transaction];
        }];
        return recipient;
    }
    
    return nil;
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

- (NSString *)nameStringForContactID:(NSString *)identifier
{
    SignalRecipient *recipient = [[Environment getCurrent].contactsManager recipientForUserID:identifier];
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
    for (SignalRecipient *contact in self.allContacts) {
        if ([contact.uniqueId isEqualToString:uid]) {
            return contact.avatar;
        }
    }
    return nil;
}

#pragma mark - Accessors
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
    // TODO: BUILD THIS!
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
