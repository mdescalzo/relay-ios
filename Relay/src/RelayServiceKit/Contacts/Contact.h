#import "TSYapDatabaseObject.h"

#import <Foundation/Foundation.h>
@import AddressBook;

/**
 *
 * Contact represents relevant information related to a contact from the user's
 * contact list.
 *
 */

@interface Contact : TSYapDatabaseObject
//@interface Contact : NSObject

@property (strong, nonatomic) NSString *firstName;
@property (strong, nonatomic) NSString *lastName;
@property (strong, nonatomic) NSArray *parsedPhoneNumbers;
@property (strong, nonatomic) NSArray *userTextPhoneNumbers;
@property (strong, nonatomic) NSArray *emails;
@property (strong, nonatomic) NSString *notes;

@property (nonatomic, readonly) NSString *fullName;
@property (nonatomic, strong) NSString *tagPresentation;
@property (nonatomic, strong) NSString *tagID;
@property (nonatomic, strong) NSString *userID;
@property (nonatomic, strong) NSArray<NSString *> *textSecureIdentifiers;

- (BOOL)isSignalContact;

#if TARGET_OS_IOS

+(instancetype)getContactWithUserID:(NSString *)userID;
+(instancetype)getContactWithUserID:(NSString *)userID
                        transaction:(YapDatabaseReadWriteTransaction *)transaction;

- (instancetype)initWithContactWithFirstName:(NSString *)firstName
                                 andLastName:(NSString *)lastName
                     andUserTextPhoneNumbers:(NSArray *)phoneNumbers
                                    andImage:(UIImage *)image
                                andContactID:(ABRecordID)record;

- (instancetype)initWithContactWithFirstName:(NSString *)firstName
                                    lastName:(NSString *)lastName
                                      userID:(NSString *)userID
                                     tagSlug:(NSString *)tagSlug;

@property (readonly, nonatomic) UIImage *image;
@property (readonly, nonatomic) ABRecordID recordID;
#endif

@end
