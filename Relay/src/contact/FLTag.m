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

-(instancetype _Nullable )initWithTagDictionary:(NSDictionary *_Nonnull)tagDictionary
{
    if (![tagDictionary respondsToSelector:@selector(objectForKey:)]) {
        DDLogDebug(@"Attempted to init FLTag with bad input: %@", tagDictionary);
        return nil;
    } else {
        NSString *tagId = [tagDictionary objectForKey:FLTagIdKey];
        if (self = [super initWithUniqueId:tagId]) {
            
            _url = [tagDictionary objectForKey:FLTagURLKey];
            _tagDescription = [tagDictionary objectForKey:FLTagDescriptionKey];
            _slug = [tagDictionary objectForKey:FLTagSlugKey];
            
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
            _recipientIds = [NSCountedSet setWithArray:holdingAray];
            
            NSDictionary *orgDict = [tagDictionary objectForKey:FLTagOrgKey];
            if (orgDict) {
                _orgSlug = [orgDict objectForKey:FLTagSlugKey];
                _orgUrl = [orgDict objectForKey:FLTagURLKey];
            }
        }
    }
    return self;
}

-(NSString *)displaySlug
{
    NSString *slugDisplayString = [NSString stringWithFormat:@"@%@", self.slug];
    if (![SignalRecipient.selfRecipient.flTag.orgSlug isEqualToString:self.orgSlug]) {
        slugDisplayString = [slugDisplayString stringByAppendingString:[NSString stringWithFormat:@":%@", self.orgSlug]];
    }
    return slugDisplayString;
}

+ (NSString *)collection
{
    return NSStringFromClass([self class]);
}

@end
