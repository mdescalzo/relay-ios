//
//  FLTagMathService.h
//
//  Created by Mark on 8/28/17.
//  Copyright © 2017 Mark. All rights reserved.
//

@import Foundation;

@protocol FLTagMathServiceDelegate;

@interface FLTagMathService : NSObject

@property (nonatomic, weak, nullable) id <FLTagMathServiceDelegate> delegate;

-(void)tagLookupWithString:(NSString *_Nonnull)lookupString;

@end

@protocol FLTagMathServiceDelegate <NSObject>

-(void)successfulLookupWithResults:(NSDictionary *_Nullable)results;

-(void)failedLookupWithError:(NSError *_Nullable)error;

@end
