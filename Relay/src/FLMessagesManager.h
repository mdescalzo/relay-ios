//
//  FLMessagesManager.h
//  Forsta
//
//  Created by Mark on 9/4/17.
//  Copyright © 2017 Forsta. All rights reserved.
//

//#import <RelayServiceKit/RelayServiceKit.h>

#import "TSMessagesManager.h"

@import Foundation;

@interface FLMessagesManager : TSMessagesManager

- (TSIncomingMessage *)handleReceivedEnvelope:(OWSSignalServiceProtosEnvelope *)envelope
                              withDataMessage:(OWSSignalServiceProtosDataMessage *)dataMessage
                                attachmentIds:(NSArray<NSString *> *)attachmentIds;

@end
