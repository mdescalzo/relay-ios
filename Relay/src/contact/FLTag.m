//
//  FLTag.m
//  Forsta
//
//  Created by Mark on 9/29/17.
//  Copyright © 2017 Forsta. All rights reserved.
//

#import "FLTag.h"

@interface FLTag()

@property (nonatomic, strong) NSDictionary *tagDictionary;

@end

@implementation FLTag

-(instancetype _Nullable )tagWithTagDictionary:(NSDictionary *_Nonnull)tagDictionary
{
    __block FLTag *newTag = nil;
    [TSStorageManager.sharedManager.dbConnection readWriteWithBlock:^(YapDatabaseReadWriteTransaction *transaction) {
        newTag = [self tagWithTagDictionary:tagDictionary transaction:transaction];
    }];
    return newTag;
}

-(instancetype _Nullable )tagWithTagDictionary:(NSDictionary *_Nonnull)tagDictionary
                                   transaction:(YapDatabaseReadWriteTransaction *_Nonnull)transaction
{
    __block FLTag *newTag = nil;
    NSString *tagId = [tagDictionary objectForKey:@"id"];
    [FLTag fetchObjectWithUniqueID:tagId transaction:transaction];
    if (newTag == nil) {
        newTag = [[FLTag alloc] initWithUniqueId:tagId];
    }
    newTag.tagDescription = [tagDictionary objectForKey:@"description"];
    newTag.slug = [tagDictionary objectForKey:@"slug"];
    newTag.orgSlug = [tagDictionary objectForKey:]
    
    return newTag;
}

+ (NSString *)collection
{
    return NSStringFromClass([self class]);
}

@end
