#import <Foundation/Foundation.h>
#import "Environment.h"

@interface Release : NSObject

/// Connects to actual production infrastructure
+ (Environment *)releaseEnvironmentWithLogging:(id<Logging>)logging;

+ (Environment *)stagingEnvironmentWithLogging:(id<Logging>)logging;

/// Fake environment with no logging
+ (Environment *)unitTestEnvironment:(NSArray *)testingAndLegacyOptions;


@end
