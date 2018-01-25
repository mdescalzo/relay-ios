
NS_ASSUME_NONNULL_BEGIN

@interface OWSDispatch : NSObject

+ (dispatch_queue_t)attachmentsQueue;

+ (dispatch_queue_t)sendingQueue;

+ (dispatch_queue_t)serialQueue;

@end

NS_ASSUME_NONNULL_END
