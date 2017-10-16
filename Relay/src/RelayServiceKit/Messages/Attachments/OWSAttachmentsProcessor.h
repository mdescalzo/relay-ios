//  Copyright © 2016 Open Whisper Systems. All rights reserved.

NS_ASSUME_NONNULL_BEGIN

@class TSMessage;
@class TSThread;
@class TSNetworkManager;
@class OWSSignalServiceProtosAttachmentPointer;
@class TSAttachmentStream;
@class TSAttachmentPointer;

/**
 * Given incoming attachment protos, determines which we support.
 * It can download those that we support and notifies threads when it receives unsupported attachments.
 */
@interface OWSAttachmentsProcessor : NSObject

@property (nullable, nonatomic, readonly) NSArray<NSString *> *attachmentIds;
@property (nonatomic, readonly) NSArray<NSString *> *supportedAttachmentIds;
@property (nonatomic, readonly) BOOL hasSupportedAttachments;

- (instancetype)init NS_UNAVAILABLE;

- (instancetype)initWithAttachmentProtos:(NSArray<OWSSignalServiceProtosAttachmentPointer *> *)attachmentProtos
                               timestamp:(uint64_t)timestamp
                                   relay:(nullable NSString *)relay
                                  thread:(TSThread *)thread
                          networkManager:(TSNetworkManager *)networkManager NS_DESIGNATED_INITIALIZER;

/*
 * Retry fetching failed attachment download
 */
- (instancetype)initWithAttachmentPointer:(TSAttachmentPointer *)attachmentPointer
                           networkManager:(TSNetworkManager *)networkManager NS_DESIGNATED_INITIALIZER;

- (void)fetchAttachmentsForMessage:(nullable TSMessage *)message
                           success:(void (^)(TSAttachmentStream *attachmentStream))successHandler
                           failure:(void (^)(NSError *error))failureHandler;
@end

NS_ASSUME_NONNULL_END
