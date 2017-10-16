////  Created by Frederic Jacobs on 21/11/15.
////  Copyright © 2015 Open Whisper Systems. All rights reserved.
//
//#import "ContactsUpdater.h"
//
//#import "Contact.h"
//#import "Cryptography.h"
//#import "PhoneNumber.h"
//#import "OWSError.h"
//#import "TSContactsIntersectionRequest.h"
//#import "TSNetworkManager.h"
//#import "TSStorageManager.h"
//
//NS_ASSUME_NONNULL_BEGIN
//
//@implementation ContactsUpdater
//
//+ (instancetype)sharedUpdater {
//    static dispatch_once_t onceToken;
//    static id sharedInstance = nil;
//    dispatch_once(&onceToken, ^{
//        sharedInstance = [self new];
//    });
//    return sharedInstance;
//}
//
//- (nullable SignalRecipient *)synchronousLookup:(NSString *)identifier error:(NSError **)error
//{
//    dispatch_semaphore_t sema = dispatch_semaphore_create(0);
//    
//    __block SignalRecipient *recipient;
//    
//    // Assigning to a pointer parameter within the block is not preventing the referenced error from being dealloc
//    // Instead, we avoid ambiguity in ownership by assigning to a local __block variable ensuring the error will be
//    // retained until our error parameter can take ownership.
//    __block NSError *retainedError;
//    [self lookupIdentifier:identifier
//                   success:^(NSSet<NSString *> *matchedIds) {
//                       if (matchedIds.count == 1) {
//                           recipient = [SignalRecipient recipientWithTextSecureIdentifier:identifier];
//                       } else {
//                           retainedError = [NSError errorWithDomain:@"contactsmanager.notfound" code:NOTFOUND_ERROR userInfo:nil];
//                       }
//                       dispatch_semaphore_signal(sema);
//                   }
//                   failure:^(NSError *lookupError) {
//                       retainedError = lookupError;
//                       dispatch_semaphore_signal(sema);
//                   }];
//    
//    dispatch_semaphore_wait(sema, DISPATCH_TIME_FOREVER);
//    *error = retainedError;
//    return recipient;
//}
//
//
//- (void)lookupIdentifier:(NSString *)identifier
//                 success:(void (^)(NSSet<NSString *> *matchedIds))success
//                 failure:(void (^)(NSError *error))failure
//{
//    if (!identifier) {
//        failure(OWSErrorWithCodeDescription(OWSErrorCodeInvalidMethodParameters, @"Cannot lookup nil identifier"));
//        return;
//    }
//    
//    [self contactIntersectionWithSet:[NSSet setWithObject:identifier] success:success failure:failure];
//}
//
//#warning Modify for UUIDs in place of phone #s
//- (void)updateSignalContactIntersectionWithABContacts:(NSArray<Contact *> *)abContacts
//                                              success:(void (^)())success
//                                              failure:(void (^)(NSError *error))failure
//{
//    NSMutableSet<NSString *> *abPhoneNumbers = [NSMutableSet set];
//    
//    for (Contact *contact in abContacts) {
//        // Hijacked to use UUIDs
//        if (contact.userID) {
//            [abPhoneNumbers addObject:contact.userID];
//        }
//        //        for (PhoneNumber *phoneNumber in contact.parsedPhoneNumbers) {
//        //            [abPhoneNumbers addObject:phoneNumber.toE164];
//        //        }
//    }
//    
//    NSMutableSet *recipientIds = [NSMutableSet set];
//    [[TSStorageManager sharedManager]
//     .dbConnection readWithBlock:^(YapDatabaseReadTransaction *_Nonnull transaction) {
//         NSArray *allRecipientKeys = [transaction allKeysInCollection:[SignalRecipient collection]];
//         [recipientIds addObjectsFromArray:allRecipientKeys];
//     }];
//    
//    NSMutableSet<NSString *> *allContacts = [[abPhoneNumbers setByAddingObjectsFromSet:recipientIds] mutableCopy];
//    
//    [self contactIntersectionWithSet:allContacts
//                             success:^(NSSet<NSString *> *matchedIds) {
//                                 [recipientIds minusSet:matchedIds];
//                                 
//                                 // Cleaning up unregistered identifiers
//                                 [[TSStorageManager sharedManager].dbConnection
//                                  readWriteWithBlock:^(YapDatabaseReadWriteTransaction *transaction) {
//                                      for (NSString *identifier in recipientIds) {
//                                          SignalRecipient *recipient =
//                                          [SignalRecipient fetchObjectWithUniqueID:identifier
//                                                                       transaction:transaction];
//                                          
//                                          [recipient removeWithTransaction:transaction];
//                                      }
//                                  }];
//                                 
//                                 DDLogInfo(@"%@ successfully intersected contacts.", self.tag);
//                                 success();
//                             }
//                             failure:failure];
//}
//
//- (void)contactIntersectionWithSet:(NSSet<NSString *> *)idSet
//                           success:(void (^)(NSSet<NSString *> *matchedIds))success
//                           failure:(void (^)(NSError *error))failure {
//    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
//        NSMutableDictionary *phoneNumbersByHashes = [NSMutableDictionary dictionary];
//        for (NSString *identifier in idSet) {
//            [phoneNumbersByHashes setObject:identifier
//                                     forKey:[Cryptography truncatedSHA1Base64EncodedWithoutPadding:identifier]];
//        }
//        NSArray *hashes = [phoneNumbersByHashes allKeys];
//        
//        TSRequest *request = [[TSContactsIntersectionRequest alloc] initWithHashesArray:hashes];
//        [[TSNetworkManager sharedManager] makeRequest:request
//                                              success:^(NSURLSessionDataTask *tsTask, id responseDict) {
//                                                  NSMutableDictionary *attributesForIdentifier = [NSMutableDictionary dictionary];
//                                                  NSArray *contactsArray                       = [(NSDictionary *)responseDict objectForKey:@"contacts"];
//                                                  
//                                                  // Map attributes to phone numbers
//                                                  if (contactsArray) {
//                                                      for (NSDictionary *dict in contactsArray) {
//                                                          NSString *hash       = [dict objectForKey:@"token"];
//                                                          NSString *identifier = [phoneNumbersByHashes objectForKey:hash];
//                                                          
//                                                          if (!identifier) {
//                                                              DDLogWarn(@"%@ An interesecting hash wasn't found in the mapping.", self.tag);
//                                                              break;
//                                                          }
//                                                          
//                                                          [attributesForIdentifier setObject:dict forKey:identifier];
//                                                      }
//                                                  }
//                                                  
//                                                  // Insert or update contact attributes
//                                                  [[TSStorageManager sharedManager]
//                                                   .dbConnection readWriteWithBlock:^(YapDatabaseReadWriteTransaction *transaction) {
//                                                       for (NSString *identifier in attributesForIdentifier) {
//                                                           SignalRecipient *recipient =
//                                                           [SignalRecipient recipientWithTextSecureIdentifier:identifier withTransaction:transaction];
//                                                           if (!recipient) {
//                                                               recipient =
//                                                               [[SignalRecipient alloc] initWithTextSecureIdentifier:identifier relay:nil supportsVoice:NO];
//                                                           }
//                                                           
//                                                           NSDictionary *attributes = [attributesForIdentifier objectForKey:identifier];
//                                                           
//                                                           NSString *relay = [attributes objectForKey:@"relay"];
//                                                           if (relay) {
//                                                               recipient.relay = relay;
//                                                           } else {
//                                                               recipient.relay = nil;
//                                                           }
//                                                           
//                                                           BOOL supportsVoice = [[attributes objectForKey:@"voice"] boolValue];
//                                                           if (supportsVoice) {
//                                                               recipient.supportsVoice = YES;
//                                                           } else {
//                                                               recipient.supportsVoice = NO;
//                                                           }
//                                                           
//                                                           [recipient saveWithTransaction:transaction];
//                                                       }
//                                                   }];
//                                                  
//                                                  success([NSSet setWithArray:attributesForIdentifier.allKeys]);
//                                              }
//                                              failure:^(NSURLSessionDataTask *task, NSError *error) {
//                                                  failure(error);
//                                              }];
//    });
//}
//
//#pragma mark - Logging
//
//+ (NSString *)tag
//{
//    return [NSString stringWithFormat:@"[%@]", self.class];
//}
//
//- (NSString *)tag
//{
//    return self.class.tag;
//}
//
//@end
//
//NS_ASSUME_NONNULL_END
