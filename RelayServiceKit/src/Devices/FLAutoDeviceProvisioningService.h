//
//  FLAutoDeviceProvisioningService.h
//  Forsta
//
//  Created by Mark Descalzo on 1/31/18.
//  Copyright © 2018 Forsta. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface FLAutoDeviceProvisioningService : NSObject

+(void)provisionDeviceWithPublicKey:(NSString *_Nonnull)keyString andUUID:(NSString *_Nonnull)uuidString;

@end
