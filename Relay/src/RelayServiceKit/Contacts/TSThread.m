//  Created by Frederic Jacobs on 16/11/14.
//  Copyright (c) 2014 Open Whisper Systems. All rights reserved.

#import "TSThread.h"
#import "TSDatabaseView.h"
#import "TSIncomingMessage.h"
#import "TSInteraction.h"
#import "TSInvalidIdentityKeyReceivingErrorMessage.h"
#import "TSOutgoingMessage.h"
#import "TSStorageManager.h"
#import "TSAccountManager.h"
#import "TextSecureKitEnv.h"
#import "FLTagMathService.h"

NS_ASSUME_NONNULL_BEGIN

static const NSString *FLThreadTitleKey = @"threadTitle";
static const NSString *FLThreadIDKey = @"threadId";
static const NSString *FLThreadTypeKey = @"threadType";
static const NSString *FLDistributionKey = @"distribution";
static const NSString *FLExpressionKey = @"expression";

@interface TSThread ()

@property (nonatomic, retain) NSDate *creationDate;
@property (nonatomic, copy) NSDate *archivalDate;
@property (nonatomic, retain) NSDate *lastMessageDate;
@property (nonatomic, copy) NSString *messageDraft;

- (TSInteraction *)lastInteraction;

@end

@implementation TSThread

@synthesize name = _name;
@synthesize image = _image;
@synthesize prettyExpression = _prettyExpression;

+ (NSString *)collection {
    return @"TSThread";
}

- (instancetype)initWithUniqueId:(NSString *)uniqueId {
    self = [super initWithUniqueId:uniqueId];
    
    if (self) {
        _archivalDate    = nil;
        _lastMessageDate = nil;
        _creationDate    = [NSDate date];
        _messageDraft    = nil;
    }
    
    return self;
}

+(instancetype)getOrCreateThreadWithID:(NSString *_Nonnull)threadID
{
    __block TSThread *thread;
    [[self dbConnection] readWriteWithBlock:^(YapDatabaseReadWriteTransaction *transaction) {
        thread = [self getOrCreateThreadWithID:threadID transaction:transaction];
    }];
    
    return thread;
}

+(instancetype)getOrCreateThreadWithID:(NSString *_Nonnull)threadID
                           transaction:(YapDatabaseReadWriteTransaction *)transaction {
    TSThread *thread = [self fetchObjectWithUniqueID:threadID transaction:transaction];
    
    if (thread == nil) {
        thread = [[TSThread alloc] initWithUniqueId:threadID];
        [thread saveWithTransaction:transaction];
    }
    return thread;
}

+(instancetype)getOrCreateThreadWithParticipants:(NSArray <NSString *> *)participantIDs
{
    __block TSThread *thread = nil;
    [[self dbConnection] readWriteWithBlock:^(YapDatabaseReadWriteTransaction *transaction) {
        thread = [self getOrCreateThreadWithParticipants:participantIDs transaction:transaction];
    }];

    return thread;
}

+(instancetype)getOrCreateThreadWithParticipants:(NSArray <NSString *> *)participantIDs
                                     transaction:(YapDatabaseReadWriteTransaction *)transaction {
    __block TSThread *thread = nil;
    __block NSCountedSet *testSet = [NSCountedSet setWithArray:participantIDs];
    [transaction enumerateKeysAndObjectsInCollection:[self collection] usingBlock:^(NSString *key, TSThread *aThread, BOOL *stop) {
        NSCountedSet *aSet = [NSCountedSet setWithArray:aThread.participants];
        if ([aSet isEqual:testSet]) {
            thread = aThread;
            *stop = YES;
        }
    }];
    
    if (thread == nil) {
        thread = [TSThread getOrCreateThreadWithID:[[NSUUID UUID] UUIDString] transaction:transaction];
        thread.participants = [participantIDs copy];
        [thread saveWithTransaction:transaction];
    }
    return thread;
}

+(instancetype)threadWithPayload:(NSDictionary *)payload
{
    __block TSThread *thread = nil;
    [[self dbConnection] readWriteWithBlock:^(YapDatabaseReadWriteTransaction *transaction) {
        thread = [self threadWithPayload:payload transaction:transaction];
    }];
    return thread;
}

+(instancetype)threadWithPayload:(NSDictionary *)payload
                     transaction:(YapDatabaseReadWriteTransaction *)transaction
{
    __block TSThread *thread = nil;
    __block NSString *threadExpression = [(NSDictionary *)[payload objectForKey:FLDistributionKey] objectForKey:FLExpressionKey];
    __block NSString *threadType = [payload objectForKey:FLThreadTypeKey];
    __block NSString *threadId = [payload objectForKey:FLThreadIDKey];
    __block NSString *threadTitle = [payload objectForKey:FLThreadTitleKey];
    thread = [self getOrCreateThreadWithID:threadId transaction:transaction];
    thread.name = ((threadTitle.length > 0) ? threadTitle : nil );
    thread.type = ((threadType.length > 0) ? threadType : nil );

    if (threadExpression.length > 0) {
        NSDictionary *lookupDict = [FLTagMathService syncTagLookupWithString:threadExpression];
        if (lookupDict) {
            thread.participants = [lookupDict objectForKey:@"userids"];
            thread.prettyExpression = [lookupDict objectForKey:@"pretty"];
            thread.universalExpression = [lookupDict objectForKey:@"universal"];
        }
    }
    [thread saveWithTransaction:transaction];

    return thread;
}

- (void)removeWithTransaction:(YapDatabaseReadWriteTransaction *)transaction
{
    [super removeWithTransaction:transaction];
    
    __block NSMutableArray<NSString *> *interactionIds = [[NSMutableArray alloc] init];
    [self enumerateInteractionsWithTransaction:transaction
                                    usingBlock:^(TSInteraction *interaction, YapDatabaseReadTransaction *transaction) {
                                        [interactionIds addObject:interaction.uniqueId];
                                    }];
    
    for (NSString *interactionId in interactionIds) {
        // This might seem redundant since we're fetching the interaction twice, once above to get the uniqueIds
        // and then again here. The issue is we can't remove them within the enumeration (you can't mutate an
        // enumeration source), but we also want to avoid instantiating an entire threads worth of Interaction objects
        // at once. This way we only have a threads worth of interactionId's.
        TSInteraction *interaction = [TSInteraction fetchObjectWithUniqueID:interactionId transaction:transaction];
        [interaction removeWithTransaction:transaction];
    }
}

#pragma mark To be subclassed.

-(void)setPrettyExpression:(NSString *)value
{
    if (![_prettyExpression isEqualToString:value] && value.length > 0) {
        _prettyExpression = [value copy];
    }
}

-(NSString *)prettyExpression
{
    return _prettyExpression;
}

-(NSString *)displayName {
    if (_name.length > 0) {
        return _name;
    } else if (self.participants.count == 1 &&
               [[self.participants lastObject] isEqualToString:TSAccountManager.sharedInstance.myself.uniqueId]) {   // conversation with self
        return NSLocalizedString(@"ME_STRING", @"");
//        return TSAccountManager.sharedInstance.myself.fullName;
    } else if (self.participants.count == 2) {  // One-on-one conversation
        NSString *userID = nil;
        for (NSString *uid in self.participants) {
            if (![uid isEqualToString:[TSStorageManager localNumber] ]) {
                userID = uid;
            }
        }
        return [[TextSecureKitEnv sharedEnv].contactsManager nameStringForContactID:userID];
    } else if (self.participants.count > 2 && self.prettyExpression) {  // Conversation with "group"
        return self.prettyExpression;
    } else {
        return NSLocalizedString(@"Unnamed converstaion", @"");
    }
}

-(void)setImage:(UIImage *_Nullable)value
{
    if (![_image isEqual:value]) {
        _image = value;
    }
}

- (UIImage *_Nullable)image
{
    if (_image == nil) {
        switch (self.participants.count) {
            case 0:
            {
                _image = nil;
            }
                break;
            case 1:
            {
                [Environment.getCurrent.contactsManager imageForPhoneIdentifier:self.participants.lastObject];
            }
                break;
            case 2:
            {
                NSString *otherId = nil;
                for (NSString *uid in self.participants) {
                    if (![uid isEqualToString:TSAccountManager.sharedInstance.myself.uniqueId]) {
                        otherId = uid;
                    }
                }
                return [Environment.getCurrent.contactsManager imageForPhoneIdentifier:otherId];
            }
                break;
            default:
            {
                return [UIImage imageNamed:@"empty-group-avatar-gray"];
            }
                break;
        }
    }
    return _image;
}

- (BOOL)hasSafetyNumbers
{
    return NO;
}

#pragma mark Interactions

/**
 * Iterate over this thread's interactions
 */
- (void)enumerateInteractionsWithTransaction:(YapDatabaseReadWriteTransaction *)transaction
                                  usingBlock:(void (^)(TSInteraction *interaction,
                                                       YapDatabaseReadTransaction *transaction))block
{
    void (^interactionBlock)(NSString *, NSString *, id, id, NSUInteger, BOOL *) = ^void(NSString *_Nonnull collection,
                                                                                         NSString *_Nonnull key,
                                                                                         id _Nonnull object,
                                                                                         id _Nonnull metadata,
                                                                                         NSUInteger index,
                                                                                         BOOL *_Nonnull stop) {
        
        TSInteraction *interaction = object;
        block(interaction, transaction);
    };
    
    YapDatabaseViewTransaction *interactionsByThread = [transaction ext:TSMessageDatabaseViewExtensionName];
    [interactionsByThread enumerateRowsInGroup:self.uniqueId usingBlock:interactionBlock];
}

/**
 * Enumerates all the threads interactions. Note this will explode if you try to create a transaction in the block.
 * If you need a transaction, use the sister method: `enumerateInteractionsWithTransaction:usingBlock`
 */
- (void)enumerateInteractionsUsingBlock:(void (^)(TSInteraction *interaction))block
{
    [self.dbConnection readWriteWithBlock:^(YapDatabaseReadWriteTransaction *transaction) {
        [self enumerateInteractionsWithTransaction:transaction
                                        usingBlock:^(
                                                     TSInteraction *interaction, YapDatabaseReadTransaction *transaction) {
                                            
                                            block(interaction);
                                        }];
    }];
}

/**
 * Useful for tests and debugging. In production use an enumeration method.
 */
- (NSArray<TSInteraction *> *)allInteractions
{
    NSMutableArray<TSInteraction *> *interactions = [NSMutableArray new];
    [self enumerateInteractionsUsingBlock:^(TSInteraction *_Nonnull interaction) {
        [interactions addObject:interaction];
    }];
    
    return [interactions copy];
}

- (NSArray<TSInvalidIdentityKeyReceivingErrorMessage *> *)receivedMessagesForInvalidKey:(NSData *)key
{
    NSMutableArray *errorMessages = [NSMutableArray new];
    [self enumerateInteractionsUsingBlock:^(TSInteraction *interaction) {
        if ([interaction isKindOfClass:[TSInvalidIdentityKeyReceivingErrorMessage class]]) {
            TSInvalidIdentityKeyReceivingErrorMessage *error = (TSInvalidIdentityKeyReceivingErrorMessage *)interaction;
            if ([[error newIdentityKey] isEqualToData:key]) {
                [errorMessages addObject:(TSInvalidIdentityKeyReceivingErrorMessage *)interaction];
            }
        }
    }];
    
    return [errorMessages copy];
}

- (NSUInteger)numberOfInteractions
{
    __block NSUInteger count;
    [[self dbConnection] readWithBlock:^(YapDatabaseReadTransaction *_Nonnull transaction) {
        YapDatabaseViewTransaction *interactionsByThread = [transaction ext:TSMessageDatabaseViewExtensionName];
        count = [interactionsByThread numberOfItemsInGroup:self.uniqueId];
    }];
    return count;
}

- (BOOL)hasUnreadMessages {
    TSInteraction *interaction = self.lastInteraction;
    BOOL hasUnread = NO;
    
    if ([interaction isKindOfClass:[TSIncomingMessage class]]) {
        hasUnread = ![(TSIncomingMessage *)interaction wasRead];
    }
    
    return hasUnread;
}

- (NSArray<TSIncomingMessage *> *)unreadMessagesWithTransaction:(YapDatabaseReadTransaction *)transaction
{
    NSMutableArray<TSIncomingMessage *> *messages = [NSMutableArray new];
    [[transaction ext:TSUnreadDatabaseViewExtensionName]
     enumerateRowsInGroup:self.uniqueId
     usingBlock:^(
                  NSString *collection, NSString *key, id object, id metadata, NSUInteger index, BOOL *stop) {
         
         if (![object isKindOfClass:[TSIncomingMessage class]]) {
             DDLogError(@"%@ Unexpected object in unread messages: %@", self.tag, object);
         }
         [messages addObject:(TSIncomingMessage *)object];
     }];
    
    return [messages copy];
}

- (NSArray<TSIncomingMessage *> *)unreadMessages
{
    __block NSArray<TSIncomingMessage *> *messages;
    [self.dbConnection readWithBlock:^(YapDatabaseReadTransaction *_Nonnull transaction) {
        messages = [self unreadMessagesWithTransaction:transaction];
    }];
    
    return messages;
}

- (void)markAllAsReadWithTransaction:(YapDatabaseReadWriteTransaction *)transaction
{
    for (TSIncomingMessage *message in [self unreadMessagesWithTransaction:transaction]) {
        [message markAsReadLocallyWithTransaction:transaction];
    }
}

- (void)markAllAsRead
{
    for (TSIncomingMessage *message in [self unreadMessages]) {
        [message markAsReadLocally];
    }
}

- (TSInteraction *) lastInteraction {
    __block TSInteraction *last;
    [TSStorageManager.sharedManager.dbConnection readWithBlock:^(YapDatabaseReadTransaction *transaction){
        last = [[transaction ext:TSMessageDatabaseViewExtensionName] lastObjectInGroup:self.uniqueId];
    }];
    return (TSInteraction *)last;
}

- (NSDate *)lastMessageDate {
    if (_lastMessageDate) {
        return _lastMessageDate;
    } else {
        return _creationDate;
    }
}

- (NSString *)lastMessageLabel {
    if (self.lastInteraction == nil) {
        return @"";
    } else {
        return [self lastInteraction].description;
    }
}

- (void)updateWithLastMessage:(TSInteraction *)lastMessage transaction:(YapDatabaseReadWriteTransaction *)transaction {
    NSDate *lastMessageDate = lastMessage.date;
    
    if ([lastMessage isKindOfClass:[TSIncomingMessage class]]) {
        TSIncomingMessage *message = (TSIncomingMessage *)lastMessage;
        lastMessageDate            = message.receivedAt;
    }
    
    if (!_lastMessageDate || [lastMessageDate timeIntervalSinceDate:self.lastMessageDate] > 0) {
        _lastMessageDate = lastMessageDate;
        
        [self saveWithTransaction:transaction];
    }
}

#pragma mark Archival

- (nullable NSDate *)archivalDate
{
    return _archivalDate;
}

- (void)archiveThreadWithTransaction:(YapDatabaseReadWriteTransaction *)transaction {
    [self archiveThreadWithTransaction:transaction referenceDate:[NSDate date]];
}

- (void)archiveThreadWithTransaction:(YapDatabaseReadWriteTransaction *)transaction referenceDate:(NSDate *)date {
    [self markAllAsReadWithTransaction:transaction];
    _archivalDate = date;
    
    [self saveWithTransaction:transaction];
}

- (void)unarchiveThreadWithTransaction:(YapDatabaseReadWriteTransaction *)transaction {
    _archivalDate = nil;
    [self saveWithTransaction:transaction];
}

#pragma mark Drafts

- (NSString *)currentDraftWithTransaction:(YapDatabaseReadTransaction *)transaction {
    TSThread *thread = [TSThread fetchObjectWithUniqueID:self.uniqueId transaction:transaction];
    if (thread.messageDraft) {
        return thread.messageDraft;
    } else {
        return @"";
    }
}

- (void)setDraft:(NSString *)draftString transaction:(YapDatabaseReadWriteTransaction *)transaction {
    TSThread *thread    = [TSThread fetchObjectWithUniqueID:self.uniqueId transaction:transaction];
    thread.messageDraft = draftString;
    [thread saveWithTransaction:transaction];
}

#pragma mark - Lazy instantiation
//-(NSString *)forstaThreadID
//{
//    if (_forstaThreadID == nil) {
//        _forstaThreadID = [[NSUUID UUID] UUIDString];
//    }
//    return _forstaThreadID;
//}

#pragma mark - Logging

+ (NSString *)tag
{
    return [NSString stringWithFormat:@"[%@]", self.class];
}

- (NSString *)tag
{
    return self.class.tag;
}

@end

NS_ASSUME_NONNULL_END
