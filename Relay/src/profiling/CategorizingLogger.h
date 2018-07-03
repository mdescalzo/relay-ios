#import <Foundation/Foundation.h>
#import "Logging.h"

@interface CategorizingLogger : NSObject <Logging> {
   @private
    NSMutableArray *callbacks;
   @private
    NSMutableDictionary *indexDic;
}

+ (CategorizingLogger *)categorizingLogger;
- (void)addLoggingCallback:(void (^)(NSString *category, id details, NSUInteger index))callback;

@end
