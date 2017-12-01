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

+(instancetype _Nullable )tagWithTagDictionary:(NSDictionary *_Nonnull)tagDictionary
{
    if ([tagDictionary respondsToSelector:@selector(objectForKey:)]) {
        NSString *tagId = [tagDictionary objectForKey:@"id"];
        FLTag *newTag = [[FLTag alloc] initWithUniqueId:tagId];
        newTag.url = [tagDictionary objectForKey:@"url"];
        newTag.tagDescription = [tagDictionary objectForKey:@"description"];
        newTag.slug = [tagDictionary objectForKey:@"slug"];
        NSDictionary *orgDict = [tagDictionary objectForKey:@"org"];
        if (orgDict) {
            newTag.orgSlug = [orgDict objectForKey:@"slug"];
            newTag.orgUrl = [orgDict objectForKey:@"url"];
        }
        
        return newTag;
    }else {
        DDLogDebug(@"tagWithTagDictionary called with bad input: %@", tagDictionary);
        return nil;
    }
}

+ (NSString *)collection
{
    return NSStringFromClass([self class]);
}

@end
