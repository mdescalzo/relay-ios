//  Created by Frederic Jacobs on 12/11/14.
//  Copyright (c) 2014 Open Whisper Systems. All rights reserved.

#import "TSAttachment.h"
#import "MIMETypeUtil.h"

NS_ASSUME_NONNULL_BEGIN

NSUInteger const TSAttachmentSchemaVersion = 2;

@interface TSAttachment ()

@property (nonatomic, readonly) NSUInteger attachmentSchemaVersion;

@end

@implementation TSAttachment

@synthesize filename = _filename;

- (instancetype)initWithServerId:(UInt64)serverId
                   encryptionKey:(NSData *)encryptionKey
                     contentType:(NSString *)contentType
{
    self = [super init];
    if (!self) {
        return self;
    }

    _serverId = serverId;
    _encryptionKey = encryptionKey;
    _contentType = contentType;
    _attachmentSchemaVersion = TSAttachmentSchemaVersion;

    return self;
}

- (nullable instancetype)initWithCoder:(NSCoder *)coder
{
    self = [super initWithCoder:coder];
    if (!self) {
        return self;
    }

    _attachmentSchemaVersion = TSAttachmentSchemaVersion;

    return self;
}

+ (NSString *)collection {
    return @"TSAttachements";
}

- (NSString *)description {
    NSString *attachmentString = NSLocalizedString(@"ATTACHMENT", nil);

    if ([MIMETypeUtil isImage:self.contentType]) {
        return [NSString stringWithFormat:@"📷 %@", attachmentString];
    } else if ([MIMETypeUtil isVideo:self.contentType]) {
        return [NSString stringWithFormat:@"📽 %@", attachmentString];
    } else if ([MIMETypeUtil isAudio:self.contentType]) {
        return [NSString stringWithFormat:@"📻 %@", attachmentString];
    } else if ([MIMETypeUtil isAnimated:self.contentType]) {
        return [NSString stringWithFormat:@"🎡 %@", attachmentString];
    } else if ([MIMETypeUtil isDocument:self.contentType]) {
        return [NSString stringWithFormat:@"💼 %@", attachmentString];
    }

    return attachmentString;
}

#pragma mark - Logging

+ (NSString *)tag
{
    return [NSString stringWithFormat:@"[%@]", self.class];
}

- (NSString *)tag
{
    return self.class.tag;
}

@end

NS_ASSUME_NONNULL_END
