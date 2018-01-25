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
#define FLControlMessageThreadArchiveKey @"threadArchive"
#define FLControlMessageThreadRestoreKey @"threadRestore"
#define FLControlMessageThreadDeleteKey @"threadDelete"
#define FLControlMessageThreadSnoozeKey @"snooze"

@interface FLControlMessage : TSOutgoingMessage

@property (strong, readonly) NSString * _Nonnull controlMessageType;

-(instancetype _Nonnull)initControlMessageForThread:(TSThread *_Nonnull)thread ofType:(NSString *_Nonnull)controlType;

@end
