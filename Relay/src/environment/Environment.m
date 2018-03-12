#import "Environment.h"
#import "Constraints.h"
#import "DH3KKeyAgreementProtocol.h"
#import "DebugLogger.h"
#import "FunctionalUtil.h"
#import "KeyAgreementProtocol.h"
#import "MessagesViewController.h"
#import "RecentCallManager.h"
#import "SignalKeyingStorage.h"
#import "TSThread.h"
#import "ContactsUpdater.h"
#import "TSAccountManager.h"
#import "FLThreadViewController.h"
#import "SmileAuthenticator.h"

#define isRegisteredUserDefaultString @"isRegistered"

static Environment *environment = nil;

@implementation Environment

+ (Environment *)getCurrent {
    NSAssert((environment != nil), @"Environment is not defined.");
    return environment;
}

+ (void)setCurrent:(Environment *)curEnvironment {
    environment = curEnvironment;
}
+ (ErrorHandlerBlock)errorNoter {
    return self.getCurrent.errorNoter;
}
+ (bool)hasEnabledTestingOrLegacyOption:(NSString *)flag {
    return [self.getCurrent.testingAndLegacyOptions containsObject:flag];
}

+ (NSString *)relayServerNameToHostName:(NSString *)name {
    return [NSString stringWithFormat:@"%@.%@", name, Environment.getCurrent.relayServerHostNameSuffix];
}
+ (SecureEndPoint *)getMasterServerSecureEndPoint {
    return Environment.getCurrent.masterServerSecureEndPoint;
}
+ (SecureEndPoint *)getSecureEndPointToDefaultRelayServer {
    return [Environment getSecureEndPointToSignalingServerNamed:Environment.getCurrent.defaultRelayName];
}
+ (SecureEndPoint *)getSecureEndPointToSignalingServerNamed:(NSString *)name {
    ows_require(name != nil);
    Environment *env = Environment.getCurrent;

    NSString *hostName         = [self relayServerNameToHostName:name];
    HostNameEndPoint *location = [HostNameEndPoint hostNameEndPointWithHostName:hostName andPort:env.serverPort];
    return [SecureEndPoint secureEndPointForHost:location identifiedByCertificate:env.certificate];
}

- (instancetype)initWithLogging:(id<Logging>)logging
                     errorNoter:(ErrorHandlerBlock)errorNoter
                     serverPort:(in_port_t)serverPort
           masterServerHostName:(NSString *)masterServerHostName
               defaultRelayName:(NSString *)defaultRelayName
      relayServerHostNameSuffix:(NSString *)relayServerHostNameSuffix
                    certificate:(Certificate *)certificate
 supportedKeyAgreementProtocols:(NSArray *)keyAgreementProtocolsInDescendingPriority
        testingAndLegacyOptions:(NSArray *)testingAndLegacyOptions
                   zrtpClientId:(NSData *)zrtpClientId
                  zrtpVersionId:(NSData *)zrtpVersionId
                contactsManager:(FLContactsManager *)contactsManager
                 networkManager:(TSNetworkManager *)networkManager
                  messageSender:(FLMessageSender *)messageSender
{
    ows_require(errorNoter != nil);
    ows_require(zrtpClientId != nil);
    ows_require(zrtpVersionId != nil);
    ows_require(testingAndLegacyOptions != nil);
    ows_require(keyAgreementProtocolsInDescendingPriority != nil);
    ows_require([keyAgreementProtocolsInDescendingPriority all:^int(id p) {
      return [p conformsToProtocol:@protocol(KeyAgreementProtocol)];
    }]);

    // must support DH3k
    ows_require([keyAgreementProtocolsInDescendingPriority any:^int(id p) {
      return [p isKindOfClass:DH3KKeyAgreementProtocol.class];
    }]);

    self = [super init];
    if (!self) {
        return self;
    }

    _errorNoter = errorNoter;
    _logging = logging;
    _testingAndLegacyOptions = testingAndLegacyOptions;
    _serverPort = serverPort;
    _masterServerSecureEndPoint = [SecureEndPoint
          secureEndPointForHost:[HostNameEndPoint hostNameEndPointWithHostName:masterServerHostName andPort:serverPort]
        identifiedByCertificate:certificate];

    _defaultRelayName = defaultRelayName;
    _certificate = certificate;
    _relayServerHostNameSuffix = relayServerHostNameSuffix;
    _keyAgreementProtocolsInDescendingPriority = keyAgreementProtocolsInDescendingPriority;
    _zrtpClientId = zrtpClientId;
    _zrtpVersionId = zrtpVersionId;
    _contactsManager = contactsManager;
    _networkManager = networkManager;
    _messageSender = messageSender;
    _invitationService = [FLInvitationService new];

    return self;
}

+ (id<Logging>)logging {
    // Many tests create objects that rely on Environment only for logging.
    // So we bypass the nil check in getCurrent and silently don't log during unit testing, instead of failing hard.
    if (environment == nil)
        return nil;

    return Environment.getCurrent.logging;
}

+ (BOOL)isRedPhoneRegistered {
    // Attributes that need to be set
    NSData *signalingKey = SignalKeyingStorage.signalingCipherKey;
    NSData *macKey       = SignalKeyingStorage.signalingMacKey;
    NSData *extra        = SignalKeyingStorage.signalingExtraKey;
    NSString *serverAuth = SignalKeyingStorage.serverAuthPassword;

    return signalingKey && macKey && extra && serverAuth;
}

//- (void)initCallListener {
//    [self.phoneManager.currentCallObservable watchLatestValue:^(CallState *latestCall) {
//        if (latestCall == nil) {
//            return;
//        }
//        FLThreadViewController *vc = [[Environment getCurrent] forstaViewController];
////        SignalsViewController *vc = [[Environment getCurrent] signalsViewController];
//        [vc dismissViewControllerAnimated:NO completion:nil];
//        vc.latestCall = latestCall;
//        [vc performSegueWithIdentifier:kCallSegue sender:self];
//    }
//                                                     onThread:NSThread.mainThread
//                                               untilCancelled:nil];
//}

+ (PropertyListPreferences *)preferences {
    return [PropertyListPreferences sharedInstance];
}

-(void)setForstaViewController:(FLThreadViewController *)forstaViewController
{
    _forstaViewController = forstaViewController;
}

//- (void)setSignalsViewController:(SignalsViewController *)signalsViewController {
//    _signalsViewController = signalsViewController;
//}

- (void)setSignUpFlowNavigationController:(UINavigationController *)navigationController {
    _signUpFlowNavigationController = navigationController;
}


// Called when a thread is updated?
+ (void)messageThreadId:(NSString *)threadId {
    TSThread *thread = [TSThread fetchObjectWithUniqueID:threadId];

    if (!thread) {
        DDLogWarn(@"We get UILocalNotifications with unknown threadId: %@", threadId);
        return;
    }

    Environment *env          = [self getCurrent];
    FLThreadViewController *vc = env.forstaViewController;
    UIViewController *topvc   = vc.navigationController.topViewController;
    
    // Dismisses keyboard if current thread updated.
    // May not be necessary in Forsta implementation
    if ([topvc isKindOfClass:[MessagesViewController class]]) {
        MessagesViewController *mvc = (MessagesViewController *)topvc;
        if ([mvc.thread.uniqueId isEqualToString:threadId]) {
            [mvc popKeyBoard];
            return;
        }
    }
    [vc presentThread:thread keyboardOnViewAppearing:YES];
}


+ (void)messageGroup:(TSThread *)groupThread {
    Environment *env          = [self getCurrent];
    FLThreadViewController *vc = env.forstaViewController;

    [vc presentThread:groupThread keyboardOnViewAppearing:YES];
}

+ (void)resetAppData
{
    [SmileAuthenticator clearPassword];
    [[TSStorageManager sharedManager] wipeSignalStorage];
    [Environment.preferences clear];
    [Environment.getCurrent.contactsManager nukeAndPave];
    [DebugLogger.sharedLogger wipeLogs];

    exit(0);
}

+ (void)wipeCommDatabase {
    [TSStorageManager.sharedManager.dbConnection readWriteWithBlock:^(YapDatabaseReadWriteTransaction *transaction) {
        [transaction removeAllObjectsInCollection:[TSThread collection]];
        [transaction removeAllObjectsInCollection:[SignalRecipient collection]];
    }];
}

//-(FLInvitationService *)invitationService
//{
//    if (_invitationService == nil) {
//        _invitationService = [FLInvitationService new];
//    }
//    return _invitationService;
//}

-(CCSMStorage *)ccsmStorage
{
    if (_ccsmStorage == nil) {
        _ccsmStorage = [CCSMStorage new];
    }
    return _ccsmStorage;
}

@end
