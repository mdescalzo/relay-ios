#import <Contacts/Contacts.h>
#import <Foundation/Foundation.h>
#import <RelayServiceKit/ContactsManagerProtocol.h>
#import <RelayServiceKit/PhoneNumber.h>
#import "CollapsingFutures.h"
//#import "Contact.h"
#import "ObservableValue.h"
#import "SignalRecipient.h"

/**
 Get latest Signal contacts, and be notified when they change.
 */

#define SIGNAL_LIST_UPDATED @"Signal_AB_UPDATED"

typedef void (^ABAccessRequestCompletionBlock)(BOOL hasAccess);
typedef void (^ABReloadRequestCompletionBlock)(NSArray *contacts);

@interface OWSContactsManager : NSObject <ContactsManagerProtocol>

@property CNContactStore *contactStore;

@property (nonatomic, strong) NSArray *ccsmRecipients;

- (ObservableValue *)getObservableContacts;

//- (NSArray *)getContactsFromAddressBook:(ABAddressBookRef)addressBook;
- (SignalRecipient *)latestRecipientForPhoneNumber:(PhoneNumber *)phoneNumber;

-(SignalRecipient *)recipientForUserID:(NSString *)userID;
-(SignalRecipient *)getOrCreateRecipientWithUserID:(NSString *)userID;

//- (void)verifyABPermission;

- (NSArray<SignalRecipient *> *)allContacts;
//- (NSArray<Contact *> *)signalContacts;
//- (NSArray *)textSecureContacts;
- (NSArray<SignalRecipient *> *)ccsmRecipients;


- (void)doAfterEnvironmentInitSetup;

//- (NSString *)nameStringForPhoneIdentifier:(NSString *)identifier;
//- (UIImage *)imageForPhoneIdentifier:(NSString *)identifier;

- (NSString *)nameStringForRecipientID:(NSString *)identifier;
- (UIImage *)avatarForRecipientID:(NSString *)identifier;

+ (NSComparator)recipientComparator;

-(void)refreshCCSMRecipients;

-(NSSet *)identifiersForTagSlug:(NSString *)tagSlug;

@end
