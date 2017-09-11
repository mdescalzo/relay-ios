//
//  FLTagMathService.h
//
//  Created by Mark on 8/28/17.
//  Copyright © 2017 Mark. All rights reserved.
//

@import Foundation;

@interface FLTagMathService : NSObject


-(void)tagLookupWithString:(NSString *_Nonnull)lookupString
                   success:(void (^_Nonnull)(NSDictionary *_Nonnull))successBlock
                   failure:(void (^_Nonnull)(NSError *_Nonnull))failureBlock;

@end
