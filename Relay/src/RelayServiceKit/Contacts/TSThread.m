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

@property (nonatomic, strong) NSDate *creationDate;
@property (nonatomic, copy) NSDate *archivalDate;
@property (nonatomic, strong) NSDate *lastMessageDate;
@property (nonatomic, copy) NSString *messageDraft;
@property (nonatomic, strong) UIImage *imageBacker;

- (TSInteraction *)lastInteraction;

@end

@implementation TSThread

@synthesize name = _name;
@synthesize prettyExpression = _prettyExpression;
@synthesize universalExpression = _universalExpression;

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
    
    for (NSString *uid in thread.participants) {
        SignalRecipient *recipient = [SignalRecipient fetchObjectWithUniqueID:uid transaction:transaction];
        if (recipient == nil) {
            recipient = [Environment.getCurrent.contactsManager recipientWithUserID:uid transaction:transaction];
        }
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
    NSString *threadId = [payload objectForKey:FLThreadIDKey];
    if (![payload objectForKey:FLThreadIDKey]) {
        DDLogDebug(@"%@ - Attempted to retrieve thread with payload without a UID.", self.tag);
        return nil;
    }
    TSThread *thread = [self getOrCreateThreadWithID:threadId transaction:transaction];
    NSString *threadExpression = [(NSDictionary *)[payload objectForKey:FLDistributionKey] objectForKey:FLExpressionKey];
    NSString *threadType = [payload objectForKey:FLThreadTypeKey];
    NSString *threadTitle = [payload objectForKey:FLThreadTitleKey];
    thread.name = ((threadTitle.length > 0) ? threadTitle : nil );
    thread.type = ((threadType.length > 0) ? threadType : nil );

    [thread updateWithExpression:threadExpression transaction:transaction];

    return thread;
}

- (void)removeWithTransaction:(YapDatabaseReadWriteTransaction *)transaction
{
    [super removeWithTransaction:transaction];
    
    __block NSMutableArray<NSString *> *interactionIds = [[NSMutableArray alloc] init];
    [self enumerateInteractionsWithTransaction:transaction
                                    usingBlock:^(TSInteraction *interaction, YapDatabaseReadTransaction *trans) {
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


#pragma mark - participants
-(void)removeParticipants:(NSSet *)objects
{
    [self.dbConnection asyncReadWriteWithBlock:^(YapDatabaseReadWriteTransaction * _Nonnull transaction) {
        [self removeParticipants:objects transaction:transaction];
    }];
}

-(void)removeParticipants:(NSSet *)objects transaction:(YapDatabaseReadWriteTransaction *)transaction
{
    if (objects.count > 0) {
        NSMutableString *goingaway = [NSMutableString new];
        for (NSString *tid in objects) {
            if (goingaway.length > 0) {
                [goingaway appendString:[NSString stringWithFormat:@"+<%@>", tid]];
            } else {
                [goingaway appendString:[NSString stringWithFormat:@"<%@>", tid]];
            }
        }
        NSString *newExpression = [NSString stringWithFormat:@"%@-(%@)", self.universalExpression, goingaway];
        [self updateWithExpression:newExpression transaction:transaction];
    }
}


#pragma mark - Accessors
-(void)setName:(NSString *)value
{
    if (![_name isEqualToString:value]) {
        _name = [value copy];
    }
}

-(NSString *)name
{
    if (_name == nil) {
        _name = @"";
    }
    return _name;
}

-(void)setUniversalExpression:(NSString *)value
{
    if (![_universalExpression isEqualToString:value] && value.length > 0) {
        _universalExpression = [value copy];
    }
}

-(NSString *)universalExpression
{
    if (_universalExpression)
        return _universalExpression;
    else
        return @"";
}

-(void)setPrettyExpression:(NSString *)value
{
    if (![_prettyExpression isEqualToString:value] && value.length > 0) {
        _prettyExpression = [value copy];
    }
}

-(NSString *)prettyExpression
{
    if (_prettyExpression)
        return _prettyExpression;
    else
        return @"";
}

-(NSString *)displayName
{
    NSString *myID = TSAccountManager.sharedInstance.myself.uniqueId;
    
    if (self.name.length > 0) {
        return self.name;
    } else if (self.participants.count == 1) {
        if ([[self.participants lastObject] isEqualToString:myID]) {
            return NSLocalizedString(@"ME_STRING", @"");
        } else {
            return [[TextSecureKitEnv sharedEnv].contactsManager nameStringForContactID:[self.participants lastObject]];
        }
    } else if (self.participants.count == 2 && [self.participants containsObject:myID]) {
        NSString *userID = nil;
        for (NSString *uid in self.participants) {
            if (![uid isEqualToString:myID]) {
                userID = uid;
            }
        }
        return [[TextSecureKitEnv sharedEnv].contactsManager nameStringForContactID:userID];
    } else if (self.prettyExpression) {  // Conversation with "group"
        return self.prettyExpression;
    } else {
        return NSLocalizedString(@"Unnamed converstaion", @"");
    }
}

-(void)setImage:(UIImage *_Nullable)value
{
    if (![_imageBacker isEqual:value]) {
        _imageBacker = value;
    }
}

- (UIImage *_Nullable)image
{
    if (_imageBacker) {
        return _imageBacker;
    } else {
        switch (self.participants.count) {
            case 0:
            {
                return nil;
            }
                break;
            case 1:
            {
                return [Environment.getCurrent.contactsManager imageForIdentifier:self.participants.lastObject];
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
                return [Environment.getCurrent.contactsManager imageForIdentifier:otherId];
            }
                break;
            default:
            {
                return [UIImage imageNamed:@"empty-group-avatar-gray"];
            }
                break;
        }
    }
}

- (void)updateImageWithAttachmentStream:(TSAttachmentStream *)attachmentStream
{
    [self setImage:[attachmentStream image]];
    [self save];

    // Avatars are stored directly in the database, so there's no need
    // to keep the attachment around after assigning the image.
    [attachmentStream remove];
}

-(void)validate
{
    [self.dbConnection asyncReadWriteWithBlock:^(YapDatabaseReadWriteTransaction *transaction) {
        [self validateWithTransaction:transaction];
    }];
}
-(void)validateWithTransaction:(YapDatabaseReadWriteTransaction *)transaction
{
    [self updateWithExpression:self.universalExpression transaction:transaction];
}

-(void)updateWithExpression:(NSString *)expression
{
    [self.dbConnection asyncReadWriteWithBlock:^(YapDatabaseReadWriteTransaction *transaction) {
        [self updateWithExpression:expression transaction:transaction];
    }];
}

-(void)updateWithExpression:(NSString *)expression transaction:(YapDatabaseReadWriteTransaction *)transaction
{
    if (expression.length > 0) {
        NSDictionary *lookupDict = [FLTagMathService syncTagLookupWithString:expression];
        if (lookupDict) {
            self.participants = [lookupDict objectForKey:@"userids"];
            self.prettyExpression = [lookupDict objectForKey:@"pretty"];
            self.universalExpression = [lookupDict objectForKey:@"universal"];
            if ([lookupDict objectForKey:@"monitorids"]) {
                self.monitorIds = [NSCountedSet setWithArray:[lookupDict objectForKey:@"monitorids"]];
            }
            [self saveWithTransaction:transaction];
        }
    }
}

- (BOOL)hasSafetyNumbers
{
    return NO;
}


#pragma mark - Interactions

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
                                        usingBlock:^(TSInteraction *interaction, YapDatabaseReadTransaction *trans) {
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
