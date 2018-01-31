//
//  FLAutoDeviceProvisioningService.m
//  Forsta
//
//  Created by Mark Descalzo on 1/31/18.
//  Copyright © 2018 Forsta. All rights reserved.
//

#import "FLAutoDeviceProvisioningService.h"
#import "TSAccountManager.h"
#import "OWSDeviceProvisioner.h"
#import "ECKeyPair+OWSPrivateKey.h"
#import "NSData+Base64.h"
#import <AxolotlKit/NSData+keyVersionByte.h>

@implementation FLAutoDeviceProvisioningService

+(void)provisionDeviceWithPublicKey:(NSString *_Nonnull)keyString andUUID:(NSString *_Nonnull)uuidString
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

@end
