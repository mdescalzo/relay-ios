//
//  FLDeviceProvisioningService.m
//  Forsta
//
//  Created by Mark Descalzo on 1/31/18.
//  Copyright © 2018 Forsta. All rights reserved.
//

#import "FLDeviceProvisioningService.h"
#import "TSAccountManager.h"
#import "OWSDeviceProvisioner.h"
#import "ECKeyPair+OWSPrivateKey.h"
#import "NSData+Base64.h"
#import <AxolotlKit/NSData+keyVersionByte.h>
#import "OWSWebsocketSecurityPolicy.h"
#import "Cryptography.h"
#import "SRWebSocket.h"
#import "CCSMStorage.h"
#import "SubProtocol.pb.h"
#import "OWSProvisioningCipher.h"
#import "OWSProvisioningProtos.pb.h"


@interface FLDeviceProvisioningService() <SRWebSocketDelegate>

@property SRWebSocket *provisioningSocket;

@end

@implementation FLDeviceProvisioningService

+ (instancetype)sharedInstance {
    static FLDeviceProvisioningService *sharedService = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedService = [[self alloc] init];
    });
    return sharedService;
}

-(instancetype)init
{
    if (self = [super init]) {
//        NSString *provisioningPath = @"/v1/keepalive/provisioning";
//        request.timeoutInterval = 15.0;
        _provisioningSocket = [[SRWebSocket alloc]initWithURL:[self provisioningURL]];
        _provisioningSocket.delegate = self;
    }
    return self;
}

-(void)provisionThisDeviceWithCompletion:(void (^)(NSError *error))completionBlock
{
    [self.provisioningSocket open];
}

-(void)provisionOtherDeviceWithPublicKey:(NSString *_Nonnull)keyString andUUID:(NSString *_Nonnull)uuidString
{
    NSData *theirPublicKey = [[NSData dataFromBase64String:keyString] removeKeyType];
    NSData *myPublicKey = TSStorageManager.sharedManager.identityKeyPair.publicKey;
    NSData *myPrivateKey = TSStorageManager.sharedManager.identityKeyPair.ows_privateKey;
    NSString *accountIdentifier = TSAccountManager.sharedInstance.myself.uniqueId;
    
    OWSDeviceProvisioner *provisioner = [[OWSDeviceProvisioner alloc] initWithMyPublicKey:myPublicKey
                                                                             myPrivateKey:myPrivateKey
                                                                           theirPublicKey:theirPublicKey
                                                                   theirEphemeralDeviceId:uuidString
                                                                        accountIdentifier:accountIdentifier];
    [provisioner provisionWithSuccess:^{
        DDLogInfo(@"Successfully provisioned device.");
        dispatch_async(dispatch_get_main_queue(), ^{
            // TODO: Notification UI here perhaps?
//            [self.linkedDevicesTableViewController expectMoreDevices];
//            [self.navigationController popToViewController:self.linkedDevicesTableViewController animated:YES];
        });
    }
                              failure:^(NSError *error) {
                                  DDLogError(@"Failed to provision device with error: %@", error);
                                  dispatch_async(dispatch_get_main_queue(), ^{
//                                      [self presentViewController:[self retryAlertControllerWithError:error
//                                                                                           retryBlock:^{
//                                                                                               [self provisionWithParser:parser];
//                                                                                           }]
//                                                         animated:YES
//                                                       completion:nil];
                                  });
                              }];
}

// MARK: - Helpers
-(NSURL *)provisioningURL
{
    NSString *tssURLString = [[[CCSMStorage alloc] init] textSecureURL];
    NSString *socketString = [tssURLString stringByReplacingOccurrencesOfString:@"http"
                                                                     withString:@"ws"];
    NSString *urlString = [socketString stringByAppendingString:@"/v1/websocket/provisioning/"];
//    getProvisioningWebSocketURL () {
//        return this.url.replace('https://', 'wss://').replace('http://', 'ws://') +
//        '/v1/websocket/provisioning/';
//    }
    NSURL *url = [NSURL URLWithString:urlString];
    
    return url;
}

- (void)sendWebSocketMessageAcknowledgement:(WebSocketRequestMessage *)request {
    WebSocketResponseMessageBuilder *response = [WebSocketResponseMessage builder];
    [response setStatus:200];
    [response setMessage:@"OK"];
    [response setId:request.id];
    
    WebSocketMessageBuilder *message = [WebSocketMessage builder];
    [message setResponse:response.build];
    [message setType:WebSocketMessageTypeResponse];
    
    NSError *error;
    [self.provisioningSocket sendDataNoCopy:message.build.data error:&error];
    if (error) {
        DDLogWarn(@"Error while trying to write on websocket %@", error);
    }
}

// MARK: - SocketRocket delegate methods
- (void)webSocketDidOpen:(SRWebSocket *)webSocket
{
    DDLogInfo(@"Provisioning socket opened.");
}

- (void)webSocket:(SRWebSocket *)webSocket didReceiveMessageWithString:(NSString *)string
{
    DDLogInfo(@"Provisioning socket received string message: %@", string);
}

- (void)webSocket:(SRWebSocket *)webSocket didReceiveMessageWithData:(NSData *)data
{
    DDLogInfo(@"Provisioning socket received data message.");

    WebSocketMessage *message = [WebSocketMessage parseFromData:data];
    
    OWSProvisioningCipher *cipher = [[OWSProvisioningCipher alloc] init];
    NSData *ourPublicKeyData = cipher.ourPublicKey;
    NSString *ourPublicKeyString  = [ourPublicKeyData base64EncodedString];
    
    if (message.hasRequest) {
        WebSocketRequestMessage *request = message.request;

        if ([request.path isEqualToString:@"/v1/address"] && [request.verb isEqualToString:@"PUT"]) {
            OWSProvisioningProtosProvisioningUuid *proto = [OWSProvisioningProtosProvisioningUuid parseFromData:request.body];
            [self sendWebSocketMessageAcknowledgement:request];
            
            NSDictionary *payload = @{ @"uuid" : proto.uuid,
                                       @"key" : ourPublicKeyString
                                       };
            
            [CCSMCommManager sendDeviceProvisioningRequestWithPayload:payload];
        } else if ([request.path isEqualToString:@"/v1/message"] && [request.verb isEqualToString:@"PUT"]) {
            // TODO: Got a message envelope.  Process it.
            [self.provisioningSocket close];
       } else {
            DDLogInfo(@"Unhandled provisioning socket request message.");
        }
    }
    
}

- (void)webSocket:(SRWebSocket *)webSocket didFailWithError:(NSError *)error
{
    DDLogInfo(@"Provisioning socket failed with Error: %@", error.description);
}

- (void)webSocket:(SRWebSocket *)webSocket didCloseWithCode:(NSInteger)code reason:(nullable NSString *)reason wasClean:(BOOL)wasClean
{
    DDLogInfo(@"Provisioning socket closed. Reason: %@", reason);
}

@end
