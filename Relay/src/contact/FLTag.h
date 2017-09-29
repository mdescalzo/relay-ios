//
//  FLTag.h
//  Forsta
//
//  Created by Mark on 9/29/17.
//  Copyright © 2017 Forsta. All rights reserved.
//

#import "TSYapDatabaseObject.h"

@import Foundation;

@interface FLTag : TSYapDatabaseObject

@property (nonatomic, strong) NSString * _Nonnull slug;
@property (nonatomic, strong) NSString * _Nonnull tagDescription;
@property (nonatomic, strong) NSString * _Nonnull orgSlug;

-(instancetype _Nullable )tagWithTagDictionary:(NSDictionary *_Nonnull)tagDictionary;
-(instancetype _Nullable )tagWithTagDictionary:(NSDictionary *_Nonnull)tagDictionary
                                   transaction:(YapDatabaseReadWriteTransaction *_Nonnull)transaction;

@end
