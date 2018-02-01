//  Copyright © 2016 Open Whisper Systems. All rights reserved.

NS_ASSUME_NONNULL_BEGIN

@interface OWSProvisioningCipher : NSObject

@property (nonatomic, readonly) NSData *ourPublicKey;

- (NSData *)encrypt:(nonnull NSData *)dataToEncrypt withTheirPublicKey:(nonnull NSData *)theirPublicKey;
-(NSData *)decrypt:(nonnull NSData *)dataToDecrypt;

@end

NS_ASSUME_NONNULL_END
