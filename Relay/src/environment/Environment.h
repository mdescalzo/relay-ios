#import "Logging.h"
#import "PacketHandler.h"
#import "PropertyListPreferences.h"
#import "SecureEndPoint.h"
#import "TSGroupModel.h"
#import "TSStorageHeaders.h"
#import "CCSMStorage.h"
#import "CCSMCommunication.h"
#import "FLMessageSender.h"
#import "FLContactsManager.h"
#import "FLInvitationService.h"

/**
 *
 * Environment is a data and data accessor class.
 * It handles application-level component wiring in order to support mocks for testing.
 * It also handles network configuration for testing/deployment server configurations.
 *
 **/

#define SAMPLE_RATE 8000

#define ENVIRONMENT_TESTING_OPTION_LOSE_CONF_ACK_ON_PURPOSE @"LoseConfAck"
#define ENVIRONMENT_TESTING_OPTION_ALLOW_NETWORK_STREAM_TO_NON_SECURE_END_POINTS @"AllowTcpWithoutTls"
#define ENVIRONMENT_LEGACY_OPTION_RTP_PADDING_BIT_IMPLIES_EXTENSION_BIT_AND_TWELVE_EXTRA_ZERO_BYTES_IN_HEADER \
    @"LegacyAndroidInterop_1"
#define TESTING_OPTION_USE_DH_FOR_HANDSHAKE @"DhKeyAgreementOnly"

@class FLContactsManager, TSNetworkManager, FLMessageSender, FLThreadViewController, CallKitManager, CallKitProviderDelegate;

@interface Environment : NSObject

- (instancetype)initWithLogging:(id<Logging>)logging
                     errorNoter:(ErrorHandlerBlock)errorNoter
                     serverPort:(in_port_t)serverPort
           masterServerHostName:(NSString *)masterServerHostName
               defaultRelayName:(NSString *)defaultRelayName
      relayServerHostNameSuffix:(NSString *)relayServerHostNameSuffix
                    certificate:(Certificate *)certificate
        testingAndLegacyOptions:(NSArray *)testingAndLegacyOptions
                contactsManager:(FLContactsManager *)contactsManager
                 networkManager:(TSNetworkManager *)networkManager
                  messageSender:(FLMessageSender *)messageSender;

@property (nonatomic, readonly) in_port_t serverPort;
@property (nonatomic, readonly) id<Logging> logging;
@property (nonatomic, readonly) SecureEndPoint *masterServerSecureEndPoint;
@property (nonatomic, readonly) NSString *defaultRelayName;
@property (nonatomic, readonly) Certificate *certificate;
@property (nonatomic, readonly) NSString *relayServerHostNameSuffix;
@property (nonatomic, readonly) NSArray *keyAgreementProtocolsInDescendingPriority;
@property (nonatomic, readonly) ErrorHandlerBlock errorNoter;
@property (nonatomic, readonly) NSArray *testingAndLegacyOptions;
@property (nonatomic, readonly) NSData *zrtpClientId;
@property (nonatomic, readonly) NSData *zrtpVersionId;
@property (nonatomic, readonly) FLContactsManager *contactsManager;
@property (nonatomic, readonly) TSNetworkManager *networkManager;
@property (nonatomic, readonly) FLMessageSender *messageSender;
@property (nonatomic, readonly) FLInvitationService *invitationService;

@property (nonatomic, readonly) FLThreadViewController *forstaViewController;
@property (nonatomic, readonly, weak) UINavigationController *signUpFlowNavigationController;

@property (nonatomic, readonly) CallKitManager *callManager;
@property (nonatomic) CallKitProviderDelegate *callProviderDelegate;

+ (SecureEndPoint *)getMasterServerSecureEndPoint;
+ (SecureEndPoint *)getSecureEndPointToDefaultRelayServer;
+ (SecureEndPoint *)getSecureEndPointToSignalingServerNamed:(NSString *)name;

+ (Environment *)getCurrent;
+ (void)setCurrent:(Environment *)curEnvironment;
+ (id<Logging>)logging;
+ (NSString *)relayServerNameToHostName:(NSString *)name;
+ (ErrorHandlerBlock)errorNoter;
+ (bool)hasEnabledTestingOrLegacyOption:(NSString *)flag;

+ (PropertyListPreferences *)preferences;

+ (void)resetAppData;
+ (void)wipeCommDatabase;

-(void)setForstaViewController:(FLThreadViewController *)forstaViewController;
- (void)setSignUpFlowNavigationController:(UINavigationController *)signUpFlowNavigationController;

+ (void)messageThreadId:(NSString *)threadId;
+ (void)messageGroup:(TSThread *)groupThread;

+(void)displayIncomingCall:(nonnull NSString *)callId originalorId:(nonnull NSString *)originator video:(BOOL)hasVideo completion:(void (^_Nonnull)(NSError *_Nullable))completion;

@end
