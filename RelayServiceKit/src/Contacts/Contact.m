#import "Contact.h"
#import "PhoneNumber.h"
#import "SignalRecipient.h"
#import "TSStorageManager.h"
#import <YapDatabase/YapDatabaseConnection.h>
#import <YapDatabase/YapDatabaseTransaction.h>

@implementation Contact

@synthesize userID = _userID;

#if TARGET_OS_IOS
+(instancetype)getContactWithUserID:(NSString *)userID
{
    __block Contact *contact;
    [[self writeDbConnection] readWriteWithBlock:^(YapDatabaseReadWriteTransaction *transaction) {
        contact = [self getContactWithUserID:userID transaction:transaction];
    }];
    
    return contact;
}

+(instancetype)getContactWithUserID:(NSString *)userID
                        transaction:(YapDatabaseReadWriteTransaction *)transaction
{
    Contact *contact = [self fetchObjectWithUniqueID:userID transaction:transaction];
    
    if (!contact) {
        contact = [[Contact alloc] initWithUniqueId:userID];
        [contact saveWithTransaction:transaction];
    }
    
    return contact;
    
}

- (instancetype)initWithContactWithFirstName:(NSString *)firstName
                                 andLastName:(NSString *)lastName
                     andUserTextPhoneNumbers:(NSArray *)phoneNumbers
                                    andImage:(UIImage *)image
                                andContactID:(ABRecordID)record {
    self = [super init];
    if (self) {
        _firstName            = firstName;
        _lastName             = lastName;
        _userTextPhoneNumbers = phoneNumbers;
        _recordID             = record;
        _image                = image;
        
        NSMutableArray *parsedPhoneNumbers = [NSMutableArray array];
        
        for (NSString *phoneNumberString in phoneNumbers) {
            PhoneNumber *phoneNumber = [PhoneNumber tryParsePhoneNumberFromUserSpecifiedText:phoneNumberString];
            if (phoneNumber) {
                [parsedPhoneNumbers addObject:phoneNumber];
            }
        }
        
        _parsedPhoneNumbers = parsedPhoneNumbers.copy;
    }
    
    return self;
}

- (instancetype)initWithContactWithFirstName:(NSString *)firstName
                                    lastName:(NSString *)lastName
                                      userID:(NSString *)userID
                                     tagSlug:(NSString *)tagSlug
{
    if ([super init]) {
        _firstName = firstName;
        _lastName = lastName;
        _userID = userID;
        self.uniqueId = userID;
        _tagPresentation = tagSlug;
    }
    return self;
}

#endif

-(NSString *)fullName
{
    if (self.firstName && self.lastName)
        return [NSString stringWithFormat:@"%@ %@", self.firstName, self.lastName];
    else if (self.lastName)
        return self.lastName;
    else if (self.firstName)
        return self.firstName;
    else
        return nil;
}

- (NSString *)description {
    return [NSString stringWithFormat:@"%@ %@: %@", self.firstName, self.lastName, self.userTextPhoneNumbers];
}

- (BOOL)isSignalContact {
    NSArray *identifiers = [self textSecureIdentifiers];
    
    return [identifiers count] > 0;
}

-(NSArray<NSString *> *)textSecureIdentifiers
{
    // Simply returning an array with userID since a user only has one ID with Forsta
    return @[ self.userID ];
    
    //    __block NSMutableArray *identifiers = [NSMutableArray array];
    //    [[TSStorageManager sharedManager]
    //     .dbConnection readWithBlock:^(YapDatabaseReadTransaction *transaction) {
    //         for (PhoneNumber *number in self.parsedPhoneNumbers) {
    //             if ([SignalRecipient recipientWithTextSecureIdentifier:number.toE164 withTransaction:transaction]) {
    //                 [identifiers addObject:number.toE164];
    //             }
    //         }
    //     }];
    //    return identifiers;
}

-(void)setUserID:(NSString *)value
{
    if (![_userID isEqualToString:value]) {
        _userID = value;
        self.uniqueId = value;
    }
}

-(NSString *)userID
{
    return self.uniqueId;
}

@end
