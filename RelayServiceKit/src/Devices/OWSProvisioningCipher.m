//  Copyright © 2016 Open Whisper Systems. All rights reserved.

#import "OWSProvisioningCipher.h"
#import <Curve25519Kit/Curve25519.h>
#import <HKDFKit/HKDFKit.h>
#import "Cryptography.h"
#import "OWSProvisioningProtos.pb.h"
#import "WhisperMessage.h"
#import "NSData+keyVersionByte.h"
#import "AES-CBC.h"
#import "AxolotlExceptions.h"

#import <CommonCrypto/CommonCrypto.h>

NS_ASSUME_NONNULL_BEGIN

@interface OWSProvisioningCipher ()

//@property (nonatomic, readonly) NSData *theirPublicKey;
@property (nonatomic, readonly) ECKeyPair *ourKeyPair;

@end

@implementation OWSProvisioningCipher

- (instancetype)init;
{
    self = [super init];
    if (!self) {
        return self;
    }

    _ourKeyPair = [Curve25519 generateKeyPair];

    return self;
}

- (NSData *)ourPublicKey
{
    return self.ourKeyPair.publicKey;
}

- (NSData *)encrypt:(nonnull NSData *)dataToEncrypt withTheirPublicKey:(nonnull NSData *)theirPublicKey
{
    NSData *sharedSecret =
        [Curve25519 generateSharedSecretFromPublicKey:theirPublicKey andKeyPair:self.ourKeyPair];

    NSData *infoData = [@"TextSecure Provisioning Message" dataUsingEncoding:NSASCIIStringEncoding];
    NSData *nullSalt = [[NSMutableData dataWithLength:32] copy];
    NSData *derivedSecret = [HKDFKit deriveKey:sharedSecret info:infoData salt:nullSalt outputSize:64];
    NSData *cipherKey = [derivedSecret subdataWithRange:NSMakeRange(0, 32)];
    NSData *macKey = [derivedSecret subdataWithRange:NSMakeRange(32, 32)];
    NSAssert(cipherKey.length == 32, @"Cipher Key must be 32 bytes");
    NSAssert(macKey.length == 32, @"Mac Key must be 32 bytes");

    u_int8_t versionByte[] = { 0x01 };
    NSMutableData *message = [NSMutableData dataWithBytes:&versionByte length:1];

    NSData *cipherText = [self encrypt:dataToEncrypt withKey:cipherKey];
    [message appendData:cipherText];

    NSData *mac = [self macForMessage:message withKey:macKey];
    [message appendData:mac];

    return [message copy];
}

- (NSData *)encrypt:(NSData *)dataToEncrypt withKey:(NSData *)cipherKey
{
    NSData *iv = [Cryptography generateRandomBytes:kCCBlockSizeAES128];
    // allow space for message + padding any incomplete block
    size_t bufferSize = dataToEncrypt.length + kCCBlockSizeAES128;
    void *buffer = malloc(bufferSize);
    size_t bytesEncrypted = 0;

    CCCryptorStatus cryptStatus = CCCrypt(kCCEncrypt,
        kCCAlgorithmAES,
        kCCOptionPKCS7Padding,
        cipherKey.bytes,
        cipherKey.length,
        iv.bytes,
        dataToEncrypt.bytes,
        dataToEncrypt.length,
        buffer,
        bufferSize,
        &bytesEncrypted);

    if (cryptStatus != kCCSuccess) {
        DDLogError(@"Encryption failed with status: %d", cryptStatus);
    }

    NSMutableData *encryptedMessage = [[NSMutableData alloc] initWithData:iv];
    [encryptedMessage appendBytes:buffer length:bytesEncrypted];

    return [encryptedMessage copy];
}

-(NSData *)decrypt:(nonnull OWSProvisioningProtosProvisionEnvelope *)envelopeProto
{
    NSData *publicKeyData = envelopeProto.publicKey;
    NSData *message = envelopeProto.body;

    NSData *keyData = [publicKeyData removeKeyType];
    
    NSData *versionData = [message subdataWithRange:NSMakeRange(0, 1)];
    int version = *(int *)(versionData.bytes);
    if (version != 1) {
        DDLogError(@"Invalid Provision Message version: %d", version);
        return nil;
    }

    NSData *iv = [message subdataWithRange:NSMakeRange(1, kCCBlockSizeAES128)];

    NSData *mac = [message subdataWithRange:NSMakeRange(message.length - 32, 32)];
    
    NSData *ivAndCiphertext = [message subdataWithRange:NSMakeRange(0, message.length - mac.length)];
    NSData *ciphertext = [message subdataWithRange:NSMakeRange(kCCBlockSizeAES128 + 1, message.length - (kCCBlockSizeAES128 + mac.length + 1))];

    NSData *sharedSecret = [Curve25519 generateSharedSecretFromPublicKey:keyData
                                                              andKeyPair:self.ourKeyPair];

    NSData *infoData = [@"TextSecure Provisioning Message" dataUsingEncoding:NSASCIIStringEncoding];
    NSData *nullSalt = [[NSMutableData dataWithLength:32] copy];

    NSData *derivedSecret = [HKDFKit deriveKey:sharedSecret info:infoData salt:nullSalt outputSize:64];
    
    NSData *cipherKey = [derivedSecret subdataWithRange:NSMakeRange(0, 32)];
    NSData *macKey = [derivedSecret subdataWithRange:NSMakeRange(32, 32)];
    NSAssert(cipherKey.length == 32, @"Cipher Key must be 32 bytes");
    NSAssert(macKey.length == 32, @"Mac Key must be 32 bytes");
    
    [self verifyMac:mac fromMessage:ivAndCiphertext withMCCKey:macKey];
    
    NSData *returnData = [AES_CBC decryptCBCMode:ciphertext withKey:cipherKey withIV:iv];
    return returnData;

}


- (NSData *)macForMessage:(NSData *)message withKey:(NSData *)macKey
{
    uint8_t hmacBytes[CC_SHA256_DIGEST_LENGTH] = { 0 };
    CCHmac(kCCHmacAlgSHA256, macKey.bytes, macKey.length, message.bytes, message.length, hmacBytes);

    return [NSData dataWithBytes:hmacBytes length:CC_SHA256_DIGEST_LENGTH];
}

- (void)verifyMac:(NSData *)mac fromMessage:(NSData *)messageData withMCCKey:(NSData *)macKey
{
    NSData *calculatedMAC = [self macForMessage:messageData withKey:macKey];

    if (![calculatedMAC isEqualToData:mac]) {
        @throw [NSException exceptionWithName:InvalidMessageException reason:@"Bad Mac!" userInfo:@{}];
    }
}

@end

NS_ASSUME_NONNULL_END
