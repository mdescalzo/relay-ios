////  Created by Frederic Jacobs on 16/11/14.
////  Copyright (c) 2014 Open Whisper Systems. All rights reserved.
//
//#import "TSGroupThread.h"
//#import "NSData+Base64.h"
//#import "SignalRecipient.h"
//#import "TSAttachmentStream.h"
//#import <YapDatabase/YapDatabaseConnection.h>
//#import <YapDatabase/YapDatabaseTransaction.h>
//
//NS_ASSUME_NONNULL_BEGIN
//
//@implementation TSGroupThread
//
//#define TSGroupThreadPrefix @"g"
//
//- (instancetype)initWithGroupModel:(TSGroupModel *)groupModel
//{
//    NSString *uniqueIdentifier = [[self class] threadIdFromGroupId:groupModel.groupId];
//    self = [super initWithUniqueId:uniqueIdentifier];
//    if (!self) {
//        return self;
//    }
//
//    _groupModel = groupModel;
//
//    return self;
//}
//
//- (instancetype)initWithGroupIdData:(NSData *)groupId
//{
//    TSGroupModel *groupModel = [[TSGroupModel alloc] initWithTitle:nil memberIds:nil image:nil groupId:groupId];
//
//    self = [self initWithGroupModel:groupModel];
//    if (!self) {
//        return self;
//    }
//
//    return self;
//}
//
//+ (instancetype)threadWithGroupModel:(TSGroupModel *)groupModel transaction:(YapDatabaseReadTransaction *)transaction
//{
//    return [self fetchObjectWithUniqueID:[self threadIdFromGroupId:groupModel.groupId] transaction:transaction];
//}
//
//+ (instancetype)getOrCreateThreadWithGroupIdData:(NSData *)groupId
//{
//    TSGroupThread *thread = [self fetchObjectWithUniqueID:[self threadIdFromGroupId:groupId]];
//    if (!thread) {
//        thread = [[self alloc] initWithGroupIdData:groupId];
//        [thread save];
//    }
//    return thread;
//}
//
//+ (instancetype)getOrCreateThreadWithGroupModel:(TSGroupModel *)groupModel
//                                    transaction:(YapDatabaseReadWriteTransaction *)transaction {
//    TSGroupThread *thread =
//        [self fetchObjectWithUniqueID:[self threadIdFromGroupId:groupModel.groupId] transaction:transaction];
//
//    if (!thread) {
//        thread = [[TSGroupThread alloc] initWithGroupModel:groupModel];
//        [thread saveWithTransaction:transaction];
//    }
//    return thread;
//}
//
//+ (instancetype)getOrCreateThreadWithGroupModel:(TSGroupModel *)groupModel
//{
//    __block TSGroupThread *thread;
//    [[self dbConnection] readWriteWithBlock:^(YapDatabaseReadWriteTransaction *transaction) {
//        thread = [self getOrCreateThreadWithGroupModel:groupModel transaction:transaction];
//    }];
//    return thread;
//}
//
//+(instancetype)getOrCreateThreadWithID:(NSString *_Nonnull)threadID
//{
//    __block TSGroupThread *thread;
//    [[self dbConnection] readWriteWithBlock:^(YapDatabaseReadWriteTransaction *transaction) {
//        thread = [self getOrCreateThreadWithID:threadID transaction:transaction];
//    }];
//    
//    return thread;
//}
//
//+(instancetype)getOrCreateThreadWithID:(NSString *_Nonnull)threadID
//                           transaction:(YapDatabaseReadWriteTransaction *)transaction {
//    TSGroupThread *thread = [self fetchObjectWithUniqueID:threadID transaction:transaction];
//    
//    if (thread == nil) {
//        thread = [[TSGroupThread alloc] initWithUniqueId:threadID];
//        thread.groupModel = [[TSGroupModel alloc] init];
//        [thread saveWithTransaction:transaction];
//    }
//    return thread;
//}
//
//+ (NSString *)threadIdFromGroupId:(NSData *)groupId
//{
//    return [TSGroupThreadPrefix stringByAppendingString:[groupId base64EncodedString]];
//}
//
//+ (NSData *)groupIdFromThreadId:(NSString *)threadId
//{
//    return [NSData dataFromBase64String:[threadId substringWithRange:NSMakeRange(1, threadId.length - 1)]];
//}
//
//- (BOOL)isGroupThread
//{
//    return true;
//}
//
//- (NSString *)name
//{
//    return self.groupModel.groupName ? self.groupModel.groupName : NSLocalizedString(@"NEW_GROUP_DEFAULT_TITLE", @"");
//}
//
//- (void)updateAvatarWithAttachmentStream:(TSAttachmentStream *)attachmentStream
//{
//    self.groupModel.groupImage = [attachmentStream image];
//    [self save];
//
//    // Avatars are stored directly in the database, so there's no need
//    // to keep the attachment around after assigning the image.
//    [attachmentStream remove];
//}
//
//@end
//
//NS_ASSUME_NONNULL_END
