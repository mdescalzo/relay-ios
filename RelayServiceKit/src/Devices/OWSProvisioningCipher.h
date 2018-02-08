//  Copyright © 2016 Open Whisper Systems. All rights reserved.

NS_ASSUME_NONNULL_BEGIN

@class OWSProvisioningProtosProvisionEnvelope;

@interface OWSProvisioningCipher : NSObject

@property (nonatomic, readonly) NSData *ourPublicKey;

- (NSData *)encrypt:(nonnull NSData *)dataToEncrypt withTheirPublicKey:(nonnull NSData *)theirPublicKey;
-(NSData *)decrypt:(nonnull OWSProvisioningProtosProvisionEnvelope *)envelopeProto;

@end

NS_ASSUME_NONNULL_END
