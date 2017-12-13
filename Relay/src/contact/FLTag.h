//
//  FLTag.h
//  Forsta
//
//  Created by Mark on 9/29/17.
//  Copyright © 2017 Forsta. All rights reserved.
//

#import "TSYapDatabaseObject.h"

@interface FLTag : TSYapDatabaseObject

@property (nonatomic, strong) NSString * _Nonnull slug;
@property (nonatomic, strong) NSString * _Nullable tagDescription;
@property (nonatomic, strong) NSString * _Nullable url;
@property (nonatomic, strong) NSString * _Nonnull orgSlug;
@property (nonatomic, strong) NSString * _Nullable orgUrl;
//@property (nonatomic, strong) UIImage * _Nullable avatar;
@property (nonatomic, strong) NSCountedSet<SignalRecipient *> * _Nullable recpients;
@property (nonatomic, strong) NSCountedSet<NSString *> * _Nullable recipientIds;

+(instancetype _Nullable )tagWithTagDictionary:(NSDictionary *_Nonnull)tagDictionary;

@end
