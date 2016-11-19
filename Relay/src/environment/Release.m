#import "Release.h"
#import "DiscardingLog.h"
#import "PhoneManager.h"
#import "PhoneNumberUtil.h"
#import "RecentCallManager.h"
#import <RelayServiceKit/ContactsUpdater.h>
#import <RelayServiceKit/OWSMessageSender.h>
#import <RelayServiceKit/TSNetworkManager.h>

#define RELEASE_ZRTP_CLIENT_ID @"Whisper 000     ".encodedAsAscii
#define RELEASE_ZRTP_VERSION_ID @"1.10".encodedAsAscii

#define TESTING_ZRTP_CLIENT_ID @"RedPhone 019    ".encodedAsAscii
#define TESTING_ZRTP_VERSION_ID @"1.10".encodedAsAscii

static unsigned char DH3K_PRIME[] = {
    0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xC9, 0x0F, 0xDA, 0xA2, 0x21, 0x68, 0xC2, 0x34, 0xC4, 0xC6, 0x62,
    0x8B, 0x80, 0xDC, 0x1C, 0xD1, 0x29, 0x02, 0x4E, 0x08, 0x8A, 0x67, 0xCC, 0x74, 0x02, 0x0B, 0xBE, 0xA6, 0x3B, 0x13,
    0x9B, 0x22, 0x51, 0x4A, 0x08, 0x79, 0x8E, 0x34, 0x04, 0xDD, 0xEF, 0x95, 0x19, 0xB3, 0xCD, 0x3A, 0x43, 0x1B, 0x30,
    0x2B, 0x0A, 0x6D, 0xF2, 0x5F, 0x14, 0x37, 0x4F, 0xE1, 0x35, 0x6D, 0x6D, 0x51, 0xC2, 0x45, 0xE4, 0x85, 0xB5, 0x76,
    0x62, 0x5E, 0x7E, 0xC6, 0xF4, 0x4C, 0x42, 0xE9, 0xA6, 0x37, 0xED, 0x6B, 0x0B, 0xFF, 0x5C, 0xB6, 0xF4, 0x06, 0xB7,
    0xED, 0xEE, 0x38, 0x6B, 0xFB, 0x5A, 0x89, 0x9F, 0xA5, 0xAE, 0x9F, 0x24, 0x11, 0x7C, 0x4B, 0x1F, 0xE6, 0x49, 0x28,
    0x66, 0x51, 0xEC, 0xE4, 0x5B, 0x3D, 0xC2, 0x00, 0x7C, 0xB8, 0xA1, 0x63, 0xBF, 0x05, 0x98, 0xDA, 0x48, 0x36, 0x1C,
    0x55, 0xD3, 0x9A, 0x69, 0x16, 0x3F, 0xA8, 0xFD, 0x24, 0xCF, 0x5F, 0x83, 0x65, 0x5D, 0x23, 0xDC, 0xA3, 0xAD, 0x96,
    0x1C, 0x62, 0xF3, 0x56, 0x20, 0x85, 0x52, 0xBB, 0x9E, 0xD5, 0x29, 0x07, 0x70, 0x96, 0x96, 0x6D, 0x67, 0x0C, 0x35,
    0x4E, 0x4A, 0xBC, 0x98, 0x04, 0xF1, 0x74, 0x6C, 0x08, 0xCA, 0x18, 0x21, 0x7C, 0x32, 0x90, 0x5E, 0x46, 0x2E, 0x36,
    0xCE, 0x3B, 0xE3, 0x9E, 0x77, 0x2C, 0x18, 0x0E, 0x86, 0x03, 0x9B, 0x27, 0x83, 0xA2, 0xEC, 0x07, 0xA2, 0x8F, 0xB5,
    0xC5, 0x5D, 0xF0, 0x6F, 0x4C, 0x52, 0xC9, 0xDE, 0x2B, 0xCB, 0xF6, 0x95, 0x58, 0x17, 0x18, 0x39, 0x95, 0x49, 0x7C,
    0xEA, 0x95, 0x6A, 0xE5, 0x15, 0xD2, 0x26, 0x18, 0x98, 0xFA, 0x05, 0x10, 0x15, 0x72, 0x8E, 0x5A, 0x8A, 0xAA, 0xC4,
    0x2D, 0xAD, 0x33, 0x17, 0x0D, 0x04, 0x50, 0x7A, 0x33, 0xA8, 0x55, 0x21, 0xAB, 0xDF, 0x1C, 0xBA, 0x64, 0xEC, 0xFB,
    0x85, 0x04, 0x58, 0xDB, 0xEF, 0x0A, 0x8A, 0xEA, 0x71, 0x57, 0x5D, 0x06, 0x0C, 0x7D, 0xB3, 0x97, 0x0F, 0x85, 0xA6,
    0xE1, 0xE4, 0xC7, 0xAB, 0xF5, 0xAE, 0x8C, 0xDB, 0x09, 0x33, 0xD7, 0x1E, 0x8C, 0x94, 0xE0, 0x4A, 0x25, 0x61, 0x9D,
    0xCE, 0xE3, 0xD2, 0x26, 0x1A, 0xD2, 0xEE, 0x6B, 0xF1, 0x2F, 0xFA, 0x06, 0xD9, 0x8A, 0x08, 0x64, 0xD8, 0x76, 0x02,
    0x73, 0x3E, 0xC8, 0x6A, 0x64, 0x52, 0x1F, 0x2B, 0x18, 0x17, 0x7B, 0x20, 0x0C, 0xBB, 0xE1, 0x17, 0x57, 0x7A, 0x61,
    0x5D, 0x6C, 0x77, 0x09, 0x88, 0xC0, 0xBA, 0xD9, 0x46, 0xE2, 0x08, 0xE2, 0x4F, 0xA0, 0x74, 0xE5, 0xAB, 0x31, 0x43,
    0xDB, 0x5B, 0xFC, 0xE0, 0xFD, 0x10, 0x8E, 0x4B, 0x82, 0xD1, 0x20, 0xA9, 0x3A, 0xD2, 0xCA, 0xFF, 0xFF, 0xFF, 0xFF,
    0xFF, 0xFF, 0xFF, 0xFF};
#define DH3K_GENERATOR 2

@implementation Release

+ (Environment *)releaseEnvironmentWithLogging:(id<Logging>)logging {
    // ErrorHandlerBlock errorDiscarder = ^(id error, id relatedInfo, bool causedTermination) {};
    ErrorHandlerBlock errorNoter = ^(id error, id relatedInfo, bool causedTermination) {
      DDLogError(@"%@: %@, %d", error, relatedInfo, causedTermination);
    };

    TSNetworkManager *networkManager = [TSNetworkManager sharedManager];
    OWSContactsManager *contactsManager = [OWSContactsManager new];
    ContactsUpdater *contactsUpdater = [ContactsUpdater sharedUpdater];
    OWSMessageSender *messageSender = [[OWSMessageSender alloc] initWithNetworkManager:networkManager
                                                                        storageManager:[TSStorageManager sharedManager]
                                                                       contactsManager:contactsManager
                                                                       contactsUpdater:contactsUpdater];
    return [[Environment alloc] initWithLogging:logging
                                     errorNoter:errorNoter
                                     serverPort:80
                           masterServerHostName:@"forsta-relay-1307716308.us-west-2.elb.amazonaws.com"
                               defaultRelayName:@"forsta-relay-1307716308"
                      relayServerHostNameSuffix:@"us-west-2.elb.amazonaws.com"
                                    certificate:[Certificate certificateFromResourcePath:@"redphone" ofType:@"cer"]
                 supportedKeyAgreementProtocols:[self supportedKeyAgreementProtocols]
                                   phoneManager:[PhoneManager phoneManagerWithErrorHandler:errorNoter]
                              recentCallManager:[RecentCallManager new]
                        testingAndLegacyOptions:@[ ENVIRONMENT_LEGACY_OPTION_RTP_PADDING_BIT_IMPLIES_EXTENSION_BIT_AND_TWELVE_EXTRA_ZERO_BYTES_IN_HEADER ]
                                   zrtpClientId:RELEASE_ZRTP_CLIENT_ID
                                  zrtpVersionId:RELEASE_ZRTP_VERSION_ID
                                contactsManager:contactsManager
                                contactsUpdater:contactsUpdater
                                 networkManager:networkManager
                                  messageSender:messageSender];
}

+ (Environment *)stagingEnvironmentWithLogging:(id<Logging>)logging {
    ErrorHandlerBlock errorNoter = ^(id error, id relatedInfo, bool causedTermination) {
      DDLogError(@"%@: %@, %d", error, relatedInfo, causedTermination);
    };

    TSNetworkManager *networkManager = [TSNetworkManager sharedManager];
    OWSContactsManager *contactsManager = [OWSContactsManager new];
    ContactsUpdater *contactsUpdater = [ContactsUpdater sharedUpdater];
    OWSMessageSender *messageSender = [[OWSMessageSender alloc] initWithNetworkManager:networkManager
                                                                        storageManager:[TSStorageManager sharedManager]
                                                                       contactsManager:contactsManager
                                                                       contactsUpdater:contactsUpdater];
    return [[Environment alloc] initWithLogging:logging
                                     errorNoter:errorNoter
                                     serverPort:80
                           masterServerHostName:@"forsta-relay-1307716308.us-west-2.elb.amazonaws.com"
                               defaultRelayName:@"forsta-relay-1307716308"
                      relayServerHostNameSuffix:@"us-west-2.elb.amazonaws.com"
                                    certificate:[Certificate certificateFromResourcePath:@"redphone" ofType:@"cer"]
                 supportedKeyAgreementProtocols:[self supportedKeyAgreementProtocols]
                                   phoneManager:[PhoneManager phoneManagerWithErrorHandler:errorNoter]
                              recentCallManager:[RecentCallManager new]
                        testingAndLegacyOptions:@[ ENVIRONMENT_LEGACY_OPTION_RTP_PADDING_BIT_IMPLIES_EXTENSION_BIT_AND_TWELVE_EXTRA_ZERO_BYTES_IN_HEADER ]
                                   zrtpClientId:RELEASE_ZRTP_CLIENT_ID
                                  zrtpVersionId:RELEASE_ZRTP_VERSION_ID
                                contactsManager:contactsManager
                                contactsUpdater:contactsUpdater
                                 networkManager:networkManager
                                  messageSender:messageSender];
}

+ (Environment *)unitTestEnvironment:(NSArray *)testingAndLegacyOptions {
    NSArray *keyAgreementProtocols = self.supportedKeyAgreementProtocols;
    if ([testingAndLegacyOptions containsObject:TESTING_OPTION_USE_DH_FOR_HANDSHAKE]) {
        keyAgreementProtocols = @[ [Release supportedDH3KKeyAgreementProtocol] ];
    }

    TSNetworkManager *networkManager = [TSNetworkManager sharedManager];
    OWSContactsManager *contactsManager = [OWSContactsManager new];
    ContactsUpdater *contactsUpdater = [ContactsUpdater sharedUpdater];
    OWSMessageSender *messageSender = [[OWSMessageSender alloc] initWithNetworkManager:networkManager
                                                                        storageManager:[TSStorageManager sharedManager]
                                                                       contactsManager:contactsManager
                                                                       contactsUpdater:contactsUpdater];

    return [[Environment alloc] initWithLogging:[DiscardingLog discardingLog]
                                     errorNoter:^(id error, id relatedInfo, bool causedTermination) {
                                     }
                                     serverPort:80
                           masterServerHostName:@"forsta-relay-1307716308.us-west-2.elb.amazonaws.com"
                               defaultRelayName:@"forsta-relay-1307716308"
                      relayServerHostNameSuffix:@"us-west-2.elb.amazonaws.com"
                                    certificate:[Certificate certificateFromResourcePath:@"redphone" ofType:@"cer"]
                 supportedKeyAgreementProtocols:keyAgreementProtocols
                                   phoneManager:nil
                              recentCallManager:nil
                        testingAndLegacyOptions:testingAndLegacyOptions
                                   zrtpClientId:TESTING_ZRTP_CLIENT_ID
                                  zrtpVersionId:TESTING_ZRTP_VERSION_ID
                                contactsManager:nil
                                contactsUpdater:contactsUpdater
                                 networkManager:networkManager
                                  messageSender:messageSender];
}

+ (NSArray *)supportedKeyAgreementProtocols {
    return @[ [EC25KeyAgreementProtocol new], [Release supportedDH3KKeyAgreementProtocol] ];
}

+ (DH3KKeyAgreementProtocol *)supportedDH3KKeyAgreementProtocol {
    NSData *prime     = [NSData dataWithBytes:DH3K_PRIME length:sizeof(DH3K_PRIME)];
    NSData *generator = [NSData dataWithSingleByte:DH3K_GENERATOR];
    return [DH3KKeyAgreementProtocol protocolWithModulus:prime andGenerator:generator];
}

@end
