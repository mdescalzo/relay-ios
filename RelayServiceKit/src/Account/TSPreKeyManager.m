//
//  TSPrekeyManager.m
//  TextSecureKit
//
//  Created by Frederic Jacobs on 07/11/14.
//  Copyright (c) 2014 Open Whisper Systems. All rights reserved.
//

#import "TSPreKeyManager.h"

#import "NSURLSessionDataTask+StatusCode.h"
#import "TSNetworkManager.h"
#import "TSStorageHeaders.h"

#define EPHEMERAL_PREKEYS_MINIMUM 35

@implementation TSPreKeyManager

+ (void)registerPreKeysWithSuccess:(void (^)())success failure:(void (^)(NSError *))failureBlock
{
    TSStorageManager *storageManager = [TSStorageManager sharedManager];
    YapDatabaseConnection *dbConnection = [storageManager newDatabaseConnection];
    
    __block ECKeyPair *identityKeyPair = nil;
    __block PreKeyRecord *lastResortPreKey = nil;
    __block SignedPreKeyRecord *signedPreKey = nil;
    __block NSArray *preKeys = nil;

    
    [dbConnection readWriteWithBlock:^(YapDatabaseReadWriteTransaction * _Nonnull transaction) {
        identityKeyPair = [storageManager identityKeyPair:transaction ];
        if (!identityKeyPair) {
            [storageManager generateNewIdentityKeyWithProtocolContext:transaction];
            identityKeyPair = [storageManager identityKeyPair:transaction];
        }
        lastResortPreKey   = [storageManager getOrGenerateLastResortKeyWithProtocolContext:transaction];
        signedPreKey = [storageManager generateRandomSignedRecordWithProtocolContext:transaction];
        preKeys = [storageManager generatePreKeyRecordsWithProtocolContext:transaction];
    }];

    
    TSRegisterPrekeysRequest *request =
    [[TSRegisterPrekeysRequest alloc] initWithPrekeyArray:preKeys
                                              identityKey:identityKeyPair.publicKey
                                       signedPreKeyRecord:signedPreKey
                                         preKeyLastResort:lastResortPreKey];
    
    [[TSNetworkManager sharedManager] makeRequest:request
                                          success:^(NSURLSessionDataTask *task, id responseObject) {
                                              DDLogInfo(@"%@ Successfully registered pre keys.", self.tag);
                                              [storageManager storePreKeyRecords:preKeys withProtocolContext:nil];
                                              [storageManager storeSignedPreKey:signedPreKey.Id signedPreKeyRecord:signedPreKey];
                                              
                                              success(nil);
                                          }
                                          failure:^(NSURLSessionDataTask *task, NSError *error) {
                                              DDLogError(@"%@ Failed to register pre keys.", self.tag);
                                              failureBlock(error);
                                          }];
}

+ (void)refreshPreKeys {
    TSAvailablePreKeysCountRequest *preKeyCountRequest = [[TSAvailablePreKeysCountRequest alloc] init];
    [[TSNetworkManager sharedManager] makeRequest:preKeyCountRequest
        success:^(NSURLSessionDataTask *task, NSDictionary *responseObject) {
          NSString *preKeyCountKey = @"count";
          NSNumber *count          = [responseObject objectForKey:preKeyCountKey];

          if (count.integerValue > EPHEMERAL_PREKEYS_MINIMUM) {
              DDLogVerbose(@"Available prekeys sufficient: %@", count.stringValue);
              return;
          } else {
              [self registerPreKeysWithSuccess:^{
                DDLogInfo(@"New PreKeys registered with server.");

                [self clearSignedPreKeyRecords];
              }
                  failure:^(NSError *error) {
                    DDLogWarn(@"Failed to update prekeys with the server");
                  }];
          }
        }
        failure:^(NSURLSessionDataTask *task, NSError *error) {
          DDLogError(@"Failed to retrieve the number of available prekeys.");
        }];
}

+ (void)clearSignedPreKeyRecords {
    TSRequest *currentSignedPreKey = [[TSCurrentSignedPreKeyRequest alloc] init];
    [[TSNetworkManager sharedManager] makeRequest:currentSignedPreKey
        success:^(NSURLSessionDataTask *task, NSDictionary *responseObject) {
          NSString *keyIdDictKey = @"keyId";
          NSNumber *keyId        = [responseObject objectForKey:keyIdDictKey];

          [self clearSignedPreKeyRecordsWithKeyId:keyId];

        }
        failure:^(NSURLSessionDataTask *task, NSError *error) {
          DDLogWarn(@"Failed to retrieve current prekey.");
        }];
}

+ (void)clearSignedPreKeyRecordsWithKeyId:(NSNumber *)keyId {
    if (!keyId) {
        DDLogError(@"The server returned an incomplete ");
        return;
    }

    TSStorageManager *storageManager  = [TSStorageManager sharedManager];
    SignedPreKeyRecord *currentRecord = [storageManager loadSignedPrekey:keyId.intValue];
    NSArray *allSignedPrekeys         = [storageManager loadSignedPreKeys];
    NSArray *oldSignedPrekeys         = [self removeCurrentRecord:currentRecord fromRecords:allSignedPrekeys];

    if ([oldSignedPrekeys count] > 3) {
        for (SignedPreKeyRecord *deletionCandidate in oldSignedPrekeys) {
            DDLogInfo(@"Old signed prekey record: %@", deletionCandidate.generatedAt);

            if ([deletionCandidate.generatedAt timeIntervalSinceNow] > SignedPreKeysDeletionTime) {
                [storageManager removeSignedPreKey:deletionCandidate.Id];
            }
        }
    }
}

+ (NSArray *)removeCurrentRecord:(SignedPreKeyRecord *)currentRecord fromRecords:(NSArray *)allRecords {
    NSMutableArray *oldRecords = [NSMutableArray array];

    for (SignedPreKeyRecord *record in allRecords) {
        if (currentRecord.Id != record.Id) {
            [oldRecords addObject:record];
        }
    }

    return oldRecords;
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
