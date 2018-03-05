//  Created by Frederic Jacobs on 16/11/14.
//  Copyright (c) 2014 Open Whisper Systems. All rights reserved.

#import "TSStorageManager.h"
#import "TSAccountManager.h"
#import "TSYapDatabaseObject.h"
#import "TSAttachmentStream.h"
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@class TSInteraction;
@class TSInvalidIdentityKeyReceivingErrorMessage;

/**
 *  TSThread is the superclass of TSContactThread and TSGroupThread
 */

@interface TSThread : TSYapDatabaseObject

extern NSString *FLThreadTitleKey;
extern NSString *FLThreadIDKey;
extern NSString *FLThreadTypeKey;
extern NSString *FLDistributionKey;
extern NSString *FLExpressionKey;
extern NSString *FLThreadTypeConversation;
extern NSString *FLThreadTypeAnnouncement;

/**
 *  Whether the object is a group thread or not.
 *
 *  @return YES if is a group thread, NO otherwise.
 */
//- (BOOL)isGroupThread;

/**
 *  Returns the name of the thread.
 *
 *  @return The name of the thread.
 */
//- (NSString *)name;
@property (copy) NSString *name;

/**
 * @returns
 *   Signal Id (e164) of the contact if it's a contact thread.
 */
//- (nullable NSString *)contactIdentifier;

#if TARGET_OS_IOS

/**
 *  Returns the image representing the thread. Nil if not available.
 *
 *  @return UIImage of the thread, or nil.
 */
- (nullable UIImage *)image;
-(void)setImage:(UIImage *_Nullable)value;
//@property (strong) UIImage *_Nullable image;
#endif

#pragma mark Interactions

/**
 *  @return The number of interactions in this thread.
 */
- (NSUInteger)numberOfInteractions;

/**
 * Get all messages in the thread we weren't able to decrypt
 */
- (NSArray<TSInvalidIdentityKeyReceivingErrorMessage *> *)receivedMessagesForInvalidKey:(NSData *)key;

/**
 *  Returns whether or not the thread has unread messages.
 *
 *  @return YES if it has unread TSIncomingMessages, NO otherwise.
 */
- (BOOL)hasUnreadMessages;

- (BOOL)hasSafetyNumbers;

- (void)markAllAsRead;
- (void)markAllAsReadWithTransaction:(YapDatabaseReadWriteTransaction *)transaction;

/**
 *  Returns the latest date of a message in the thread or the thread creation date if there are no messages in that
 *thread.
 *
 *  @return The date of the last message or thread creation date.
 */
- (NSDate *)lastMessageDate;

/**
 *  Returns the string that will be displayed typically in a conversations view as a preview of the last message
 *received in this thread.
 *
 *  @return Thread preview string.
 */
- (NSString *)lastMessageLabel;

/**
 *  Updates the thread's caches of the latest interaction.
 *
 *  @param lastMessage Latest Interaction to take into consideration.
 *  @param transaction Database transaction.
 */
- (void)updateWithLastMessage:(TSInteraction *)lastMessage transaction:(YapDatabaseReadWriteTransaction *)transaction;

#pragma mark Archival

/**
 *  Returns the last date at which a string was archived or nil if the thread was never archived or brought back to the
 *inbox.
 *
 *  @return Last archival date.
 */
- (nullable NSDate *)archivalDate;

/**
 *  Archives a thread with the current date.
 *
 *  @param transaction Database transaction.
 */
- (void)archiveThreadWithTransaction:(YapDatabaseReadWriteTransaction *)transaction;

/**
 *  Archives a thread with the reference date. This is currently only used for migrating older data that has already
 * been archived.
 *
 *  @param transaction Database transaction.
 *  @param date        Date at which the thread was archived.
 */
- (void)archiveThreadWithTransaction:(YapDatabaseReadWriteTransaction *)transaction referenceDate:(NSDate *)date;

/**
 *  Unarchives a thread that was archived previously.
 *
 *  @param transaction Database transaction.
 */
- (void)unarchiveThreadWithTransaction:(YapDatabaseReadWriteTransaction *)transaction;

#pragma mark Drafts

/**
 *  Returns the last known draft for that thread. Always returns a string. Empty string if nil.
 *
 *  @param transaction Database transaction.
 *
 *  @return Last known draft for that thread.
 */
- (NSString *)currentDraftWithTransaction:(YapDatabaseReadTransaction *)transaction;

/**
 *  Sets the draft of a thread. Typically called when leaving a conversation view.
 *
 *  @param draftString Draft string to be saved.
 *  @param transaction Database transaction.
 */
- (void)setDraft:(NSString *)draftString transaction:(YapDatabaseReadWriteTransaction *)transaction;

#pragma mark - Forsta additions
@property (strong) NSArray<NSString *> *participants;
@property (strong) NSString *universalExpression;
@property (strong) NSString *prettyExpression;
@property (strong, readonly) NSString *displayName;
@property (strong) NSString *type;
@property (strong) NSCountedSet *monitorIds;
@property (strong) NSNumber *_Nullable pinPosition;

/**
 *  Get or create thread with array of participant UUIDs
 */
+(instancetype)getOrCreateThreadWithParticipants:(NSArray <NSString *> *)participantIDs;
+(instancetype)getOrCreateThreadWithParticipants:(NSArray <NSString *> *)participantIDs
                                     transaction:(YapDatabaseReadWriteTransaction *)transaction;
/**
 *  Get or create thread with thread UUID
 */
+(instancetype)getOrCreateThreadWithID:(NSString *)threadID;
+(instancetype)getOrCreateThreadWithID:(NSString *_Nonnull)threadID
                           transaction:(YapDatabaseReadWriteTransaction *)transaction;

/**
 *  Get or create thread with thread forsta payload
 */
//+(instancetype)threadWithPayload:(NSDictionary *)payload;
//+(instancetype)threadWithPayload:(NSDictionary *)payload
//                     transaction:(YapDatabaseReadWriteTransaction *)transaction;

/**
 *  Remove participant from thread
 */
-(void)removeParticipants:(NSSet *)objects;
-(void)removeParticipants:(NSSet *)objects transaction:(YapDatabaseReadWriteTransaction *)transaction;

/**
 *  Update avatar/image wiht attachment stream
 */
- (void)updateImageWithAttachmentStream:(TSAttachmentStream *)attachmentStream;

/**
 *  Update thread with its expression
 */
-(void)validate;
//-(void)validateWithTransaction:(YapDatabaseReadWriteTransaction *)transaction;

-(void)updateWithPayload:(NSDictionary *)payload;

@end

NS_ASSUME_NONNULL_END
