#import "Environment.h"
#import "Constraints.h"
#import "DebugLogger.h"
#import "FunctionalUtil.h"
#import "MessagesViewController.h"
#import "SignalKeyingStorage.h"
#import "TSThread.h"
#import "ContactsUpdater.h"
#import "TSAccountManager.h"
#import "FLThreadViewController.h"
#import "SmileAuthenticator.h"
#import "Relay-Swift.h"

#define isRegisteredUserDefaultString @"isRegistered"
#define callSegueId @"callViewSegue"

static Environment *environment = nil;

@implementation Environment

+ (Environment *)shared {
    NSAssert((environment != nil), @"Environment is not defined.");
    return environment;
}

+ (void)setCurrent:(Environment *)curEnvironment {
    environment = curEnvironment;
}
+ (ErrorHandlerBlock)errorNoter {
    return self.shared.errorNoter;
}
+ (bool)hasEnabledTestingOrLegacyOption:(NSString *)flag {
    return [self.shared.testingAndLegacyOptions containsObject:flag];
}

+ (NSString *)relayServerNameToHostName:(NSString *)name {
    return [NSString stringWithFormat:@"%@.%@", name, Environment.shared.relayServerHostNameSuffix];
}
+ (SecureEndPoint *)getMasterServerSecureEndPoint {
    return Environment.shared.masterServerSecureEndPoint;
}
+ (SecureEndPoint *)getSecureEndPointToDefaultRelayServer {
    return [Environment getSecureEndPointToSignalingServerNamed:Environment.shared.defaultRelayName];
}
+ (SecureEndPoint *)getSecureEndPointToSignalingServerNamed:(NSString *)name {
    ows_require(name != nil);
    Environment *env = Environment.shared;

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
        testingAndLegacyOptions:(NSArray *)testingAndLegacyOptions
                contactsManager:(FLContactsManager *)contactsManager
                 networkManager:(TSNetworkManager *)networkManager
                  messageSender:(FLMessageSender *)messageSender
{
    ows_require(errorNoter != nil);
    ows_require(testingAndLegacyOptions != nil);

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
    _contactsManager = contactsManager;
    _networkManager = networkManager;
    _messageSender = messageSender;
    _invitationService = [FLInvitationService new];
    _callService = [CallService new];
    [self callProviderDelegate];

    return self;
}

+ (id<Logging>)logging {
    // Many tests create objects that rely on Environment only for logging.
    // So we bypass the nil check in shared and silently don't log during unit testing, instead of failing hard.
    if (environment == nil)
        return nil;

    return Environment.shared.logging;
}

+ (PropertyListPreferences *)preferences {
    return [PropertyListPreferences sharedInstance];
}

-(void)setForstaViewController:(FLThreadViewController *)forstaViewController
{
    _forstaViewController = forstaViewController;
}

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

    Environment *env          = [self shared];
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
    Environment *env          = [self shared];
    FLThreadViewController *vc = env.forstaViewController;

    [vc presentThread:groupThread keyboardOnViewAppearing:YES];
}

+ (void)resetAppData
{
    [SmileAuthenticator clearPassword];
    [[TSStorageManager sharedManager] wipeSignalStorage];
    [Environment.preferences clear];
    [Environment.shared.contactsManager nukeAndPave];
    [DebugLogger.sharedLogger wipeLogs];

    exit(0);
}

+ (void)wipeCommDatabase {
    [TSStorageManager.sharedManager.writeDbConnection readWriteWithBlock:^(YapDatabaseReadWriteTransaction *transaction) {
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

-(CallKitProviderDelegate *)callProviderDelegate
{
    if (_callProviderDelegate == nil) {
        _callProviderDelegate = [[CallKitProviderDelegate alloc] initWithCallManager:self.callService];
    }
    return _callProviderDelegate;
}

// MARK: Call management
+(void)displayIncomingCall:(nonnull NSString *)callId originalorId:(nonnull NSString *)originator video:(BOOL)hasVideo completion:(void (^_Nonnull)(NSError *_Nullable))completion
{
    __block SignalRecipient *recipient = [Environment.shared.contactsManager recipientWithUserId:originator];
    __block NSUUID *callUUID = [[NSUUID alloc] initWithUUIDString:callId];
    __block UIBackgroundTaskIdentifier backgroundTaskIdentifier = [UIApplication.sharedApplication beginBackgroundTaskWithExpirationHandler:nil];

    dispatch_async(dispatch_get_main_queue(), ^{
        [Environment.shared.callProviderDelegate reportIncomingCallWithUuid:callUUID handle:recipient.fullName hasVideo:hasVideo completion:^(NSError *error) {
            [UIApplication.sharedApplication endBackgroundTask:backgroundTaskIdentifier];
            
            if (completion != nil) {
                completion(error);
            }
        }];
    });
}

+(void)displayOutgoingCall:(nonnull NSString *)callId completion:(void (^_Nonnull)(NSError *_Nullable))completion
{
    __block NSUUID *callUUID = [[NSUUID alloc] initWithUUIDString:callId];
    __block UIBackgroundTaskIdentifier backgroundTaskIdentifier = [UIApplication.sharedApplication beginBackgroundTaskWithExpirationHandler:nil];

    dispatch_async(dispatch_get_main_queue(), ^{
        RelayCall *call = [Environment.shared.callService callWithUUIDWithUuid:callUUID];
        
        [Environment.shared.forstaViewController presentCall:call];
        
        [UIApplication.sharedApplication endBackgroundTask:backgroundTaskIdentifier];
        
        if (completion != nil) {
            completion(nil);
        }
    });
    
}

+(void)endCallWithId:(NSString *)callId
{
    __block NSUUID *callUUID = [[NSUUID alloc] initWithUUIDString:callId];
    RelayCall *call = [Environment.shared.callService callWithUUIDWithUuid:callUUID];
    if (call != nil) {
        [Environment.shared.callManager endWithCall:call];
    }
}
                   
@end
