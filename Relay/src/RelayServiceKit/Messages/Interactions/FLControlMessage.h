//
//  FLControlMessage.h
//  
//
//  Created by Mark on 10/18/17.
//

#import "TSMessage.h"

#define FLControlMessageThreadUpdateKey @"threadUpdate"
#define FLControlMessageThreadClearKey @"threadClear"
#define FLControlMessageThreadCloseKey @"threadClose"
#define FLControlMessageThreadDeleteKey @"threadDelete"
#define FLControlMessageThreadSnoozeKey @"snooze"

@interface FLControlMessage : TSMessage

@end
