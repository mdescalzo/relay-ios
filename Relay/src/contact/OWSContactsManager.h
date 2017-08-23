#import <Contacts/Contacts.h>
#import <Foundation/Foundation.h>
#import <RelayServiceKit/ContactsManagerProtocol.h>
#import <RelayServiceKit/PhoneNumber.h>
#import "CollapsingFutures.h"
#import "Contact.h"
#import "ObservableValue.h"

/**
 Get latest Signal contacts, and be notified when they change.
 */

#define SIGNAL_LIST_UPDATED @"Signal_AB_UPDATED"

typedef void (^ABAccessRequestCompletionBlock)(BOOL hasAccess);
typedef void (^ABReloadRequestCompletionBlock)(NSArray *contacts);

@interface OWSContactsManager : NSObject <ContactsManagerProtocol>

@property CNContactStore *contactStore;

@property (nonatomic, strong) NSArray *ccsmContacts;

- (ObservableValue *)getObservableContacts;

- (NSArray *)getContactsFromAddressBook:(ABAddressBookRef)addressBook;
- (Contact *)latestContactForPhoneNumber:(PhoneNumber *)phoneNumber;

-(Contact *)contactForUserID:(NSString *)userID;
-(Contact *)getOrCreateContactWithUserID:(NSString *)userID;

- (void)verifyABPermission;

- (NSArray<Contact *> *)allContacts;
- (NSArray<Contact *> *)signalContacts;
- (NSArray *)textSecureContacts;
- (NSArray<Contact *> *)ccsmContacts;

- (void)doAfterEnvironmentInitSetup;

//- (NSString *)nameStringForPhoneIdentifier:(NSString *)identifier;
//- (UIImage *)imageForPhoneIdentifier:(NSString *)identifier;

- (NSString *)nameStringForContactID:(NSString *)identifier;
- (UIImage *)imageForContactID:(NSString *)identifier;

+ (NSComparator)contactComparator;

-(void)refreshCCSMContacts;

@end
