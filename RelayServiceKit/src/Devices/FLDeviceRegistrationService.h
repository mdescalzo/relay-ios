//
//  FLDeviceRegistrationService.h
//  Forsta
//
//  Created by Mark Descalzo on 1/31/18.
//  Copyright © 2018 Forsta. All rights reserved.
//

#import "SRWebSocket.h"

@import Foundation;

@interface FLDeviceRegistrationService : NSObject

+(instancetype _Nonnull)sharedInstance;

-(void)provisionThisDeviceWithCompletion:(void (^_Nullable)(NSError * _Nullable error))completionBlock;

-(void)provisionOtherDeviceWithPublicKey:(NSString *_Nonnull)keyString andUUID:(NSString *_Nonnull)uuidString;

@end
