//  Copyright © 2016 Open Whisper Systems. All rights reserved.

#import "OWSContactsOutputStream.h"
#import "SignalRecipient.h"
#import "MIMETypeUtil.h"
#import "OWSSignalServiceProtos.pb.h"
#import <ProtocolBuffers/CodedOutputStream.h>

NS_ASSUME_NONNULL_BEGIN

@implementation OWSContactsOutputStream

- (void)writeContact:(SignalRecipient *)recipient
{
    OWSSignalServiceProtosContactDetailsBuilder *contactBuilder = [OWSSignalServiceProtosContactDetailsBuilder new];
    [contactBuilder setName:recipient.fullName];
    [contactBuilder setNumber:recipient.textSecureIdentifier];
    
    NSData *avatarPng;
    if (recipient.avatar) {
        OWSSignalServiceProtosContactDetailsAvatarBuilder *avatarBuilder =
        [OWSSignalServiceProtosContactDetailsAvatarBuilder new];
        
        [avatarBuilder setContentType:OWSMimeTypeImagePng];
        avatarPng = UIImagePNGRepresentation(recipient.avatar);
        [avatarBuilder setLength:(uint32_t)avatarPng.length];
        [contactBuilder setAvatarBuilder:avatarBuilder];
    }
    
    NSData *contactData = [[contactBuilder build] data];
    
    uint32_t contactDataLength = (uint32_t)contactData.length;
    [self.delegateStream writeRawVarint32:contactDataLength];
    [self.delegateStream writeRawData:contactData];
    
    if (recipient.avatar) {
        [self.delegateStream writeRawData:avatarPng];
    }
}

@end

NS_ASSUME_NONNULL_END
