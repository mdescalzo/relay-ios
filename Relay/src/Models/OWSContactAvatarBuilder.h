//
//  Copyright (c) 2017 Open Whisper Systems. All rights reserved.
//

#import "OWSAvatarBuilder.h"

NS_ASSUME_NONNULL_BEGIN

@class OWSContactsManager;
@class TSThread;

@interface OWSContactAvatarBuilder : OWSAvatarBuilder

- (instancetype)initWithContactId:(NSString *)contactId
                             name:(NSString *)name
                  contactsManager:(OWSContactsManager *)contactsManager
                         diameter:(CGFloat)diameter;

- (instancetype)initWithThread:(TSThread *)thread
               contactsManager:(OWSContactsManager *)contactsManager
                      diameter:(CGFloat)diameter;

@end

NS_ASSUME_NONNULL_END
