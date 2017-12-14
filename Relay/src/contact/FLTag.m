//
//  FLTag.m
//  Forsta
//
//  Created by Mark on 9/29/17.
//  Copyright © 2017 Forsta. All rights reserved.
//

#import "FLTag.h"

#define FLTagDescriptionKey @"description"
#define FLTagIdKey @"id"
#define FLTagURLKey @"url"
#define FLTagSlugKey @"slug"
#define FLTagOrgKey @"org"
#define FLTagUsersKey @"users"

@interface FLTag()

@property (nonatomic, strong) NSDictionary *tagDictionary;

@end

@implementation FLTag

+(instancetype _Nullable )tagWithTagDictionary:(NSDictionary *_Nonnull)tagDictionary
{
    if ([tagDictionary respondsToSelector:@selector(objectForKey:)]) {
        NSString *tagId = [tagDictionary objectForKey:FLTagIdKey];
        FLTag *newTag = [[FLTag alloc] initWithUniqueId:tagId];
        newTag.url = [tagDictionary objectForKey:FLTagURLKey];
        newTag.tagDescription = [tagDictionary objectForKey:FLTagDescriptionKey];
        newTag.slug = [tagDictionary objectForKey:FLTagSlugKey];
        
        NSArray *users = [tagDictionary objectForKey:FLTagUsersKey];
        NSMutableArray *holdingAray = [NSMutableArray new];
        id object = [tagDictionary objectForKey:@"user"];
        if (![[object class] isEqual:[NSNull class]]) {
            NSDictionary *singleUser = (NSDictionary *)object;
            NSString *uid = [singleUser objectForKey:FLTagIdKey];
            if (uid) {
                [holdingAray addObject:uid];
            }
        }
        [users enumerateObjectsUsingBlock:^(NSDictionary *obj, NSUInteger idx, BOOL * _Nonnull stop) {
            id associationType = [obj objectForKey:@"association_type"];
            if (![[associationType class] isEqual:[NSNull class]]) {
                if ([associationType isEqualToString:@"MEMBEROF"]) {
                    NSDictionary *user = [obj objectForKey:@"user"];
                    if (user) {
                        [holdingAray addObject:[user objectForKey:FLTagIdKey]];
                    }
                }
            }
        }];
        newTag.recipientIds = [NSCountedSet setWithArray:holdingAray];
        
        NSDictionary *orgDict = [tagDictionary objectForKey:FLTagOrgKey];
        if (orgDict) {
            newTag.orgSlug = [orgDict objectForKey:FLTagSlugKey];
            newTag.orgUrl = [orgDict objectForKey:FLTagURLKey];
        }
        
        return newTag;
    }else {
        DDLogDebug(@"tagWithTagDictionary called with bad input: %@", tagDictionary);
        return nil;
    }
}

//-(UIImage *)avatar
//{
//    if (self.recipientIds.count == 1) {
//        NSString *recId = [self.recipientIds anyObject];
//        SignalRecipient *rec = [Environment.getCurrent.contactsManager recipientWithUserID:recId];
//        return rec.avatar;
//    } else {
//        // TODO: Make call to avatar factory with description?
//        return nil;
//    }
//}

+ (NSString *)collection
{
    return NSStringFromClass([self class]);
}

@end
