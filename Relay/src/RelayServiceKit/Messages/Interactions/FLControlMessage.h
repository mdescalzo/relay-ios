//
//  FLControlMessage.h
//  
//
//  Created by Mark on 10/18/17.
//

#import "TSOutgoingMessage.h"

#define FLControlMessageThreadUpdateKey @"threadUpdate"
#define FLControlMessageThreadClearKey @"threadClear"
#define FLControlMessageThreadCloseKey @"threadClose"
#define FLControlMessageThreadDeleteKey @"threadDelete"
#define FLControlMessageThreadSnoozeKey @"snooze"

@interface FLControlMessage : TSOutgoingMessage

-(instancetype _Nonnull)initThreadUpdateControlMessageForThread:(TSThread *_Nonnull)thread;

@end
