//  Created by Frederic Jacobs on 12/11/14.
//  Copyright (c) 2014 Open Whisper Systems. All rights reserved.

#import "TSMessage.h"
#import "NSDate+millisecondTimeStamp.h"
#import "OWSDisappearingMessagesJob.h"
#import "TSAttachment.h"
#import "TSAttachmentPointer.h"
#import "TSThread.h"
#import <YapDatabase/YapDatabaseTransaction.h>
#import "UIFont+OWS.h"
#import "NSAttributedString+DDHTML.h"

NS_ASSUME_NONNULL_BEGIN

static const NSUInteger OWSMessageSchemaVersion = 3;

@interface TSMessage ()

/**
 * The version of the model class's schema last used to serialize this model. Use this to manage data migrations during
 * object de/serialization.
 *
 * e.g.
 *
 *    - (id)initWithCoder:(NSCoder *)coder
 *    {
 *      self = [super initWithCoder:coder];
 *      if (!self) { return self; }
 *      if (_schemaVersion < 2) {
 *        _newName = [coder decodeObjectForKey:@"oldName"]
 *      }
 *      ...
 *      _schemaVersion = 2;
 *    }
 */
@property (nonatomic, readonly) NSUInteger schemaVersion;

@end

@implementation TSMessage

@synthesize body = _body;
@synthesize plainTextBody = _plainTextBody;
@synthesize uniqueId = _uniqueId;

- (instancetype)initWithTimestamp:(uint64_t)timestamp
{
    return [self initWithTimestamp:timestamp inThread:nil messageBody:nil];
}

- (instancetype)initWithTimestamp:(uint64_t)timestamp inThread:(nullable TSThread *)thread
{
    return [self initWithTimestamp:timestamp inThread:thread messageBody:nil attachmentIds:@[]];
}

- (instancetype)initWithTimestamp:(uint64_t)timestamp
                         inThread:(nullable TSThread *)thread
                      messageBody:(nullable NSString *)body
{
    return [self initWithTimestamp:timestamp inThread:thread messageBody:body attachmentIds:@[]];
}

- (instancetype)initWithTimestamp:(uint64_t)timestamp
                         inThread:(nullable TSThread *)thread
                      messageBody:(nullable NSString *)body
                    attachmentIds:(NSArray<NSString *> *)attachmentIds
{
    return [self initWithTimestamp:timestamp
                          inThread:thread
                       messageBody:body
                     attachmentIds:attachmentIds
                  expiresInSeconds:0];
}

- (instancetype)initWithTimestamp:(uint64_t)timestamp
                         inThread:(nullable TSThread *)thread
                      messageBody:(nullable NSString *)body
                    attachmentIds:(NSArray<NSString *> *)attachmentIds
                 expiresInSeconds:(uint32_t)expiresInSeconds
{
    return [self initWithTimestamp:timestamp
                          inThread:thread
                       messageBody:body
                     attachmentIds:attachmentIds
                  expiresInSeconds:expiresInSeconds
                   expireStartedAt:0];
}

- (instancetype)initWithTimestamp:(uint64_t)timestamp
                         inThread:(nullable TSThread *)thread
                      messageBody:(nullable NSString *)body
                    attachmentIds:(NSArray<NSString *> *)attachmentIds
                 expiresInSeconds:(uint32_t)expiresInSeconds
                  expireStartedAt:(uint64_t)expireStartedAt
{
    self = [super initWithTimestamp:timestamp inThread:thread];
    
    if (!self) {
        return self;
    }
    
    _schemaVersion = OWSMessageSchemaVersion;
    
    _body = body;
    _attachmentIds = attachmentIds ? [attachmentIds mutableCopy] : [NSMutableArray new];
    _expiresInSeconds = expiresInSeconds;
    _expireStartedAt = expireStartedAt;
    [self updateExpiresAt];
    
    return self;
}

- (nullable instancetype)initWithCoder:(NSCoder *)coder
{
    self = [super initWithCoder:coder];
    if (!self) {
        return self;
    }
    
    if (_schemaVersion < 3) {
        _expiresInSeconds = 0;
        _expireStartedAt = 0;
        _expiresAt = 0;
    }
    
    if (_schemaVersion < 2) {
        // renamed _attachments to _attachmentIds
        if (!_attachmentIds) {
            _attachmentIds = [coder decodeObjectForKey:@"attachments"];
        }
    }
    
    if (!_attachmentIds) {
        // previously allowed nil _attachmentIds
        _attachmentIds = [NSMutableArray new];
    }
    
    _schemaVersion = OWSMessageSchemaVersion;
    return self;
}

- (void)setexpiresInSeconds:(uint32_t)expiresInSeconds
{
    _expiresInSeconds = expiresInSeconds;
    [self updateExpiresAt];
}

- (void)setExpireStartedAt:(uint64_t)expireStartedAt
{
    _expireStartedAt = expireStartedAt;
    [self updateExpiresAt];
}

- (BOOL)shouldStartExpireTimer
{
    return self.isExpiringMessage;
}

// TODO a downloaded media doesn't start counting until download is complete.
- (void)updateExpiresAt
{
    if (_expiresInSeconds > 0 && _expireStartedAt > 0) {
        _expiresAt = _expireStartedAt + _expiresInSeconds * 1000;
    } else {
        _expiresAt = 0;
    }
}

- (BOOL)hasAttachments
{
    return self.attachmentIds ? (self.attachmentIds.count > 0) : NO;
}

- (NSString *)debugDescription
{
    if ([self hasAttachments]) {
        NSString *attachmentId = self.attachmentIds[0];
        return [NSString stringWithFormat:@"Media Message with attachmentId:%@", attachmentId];
    } else {
        return [NSString stringWithFormat:@"%@ with body:%@", [self class], self.body];
    }
}

- (NSString *)description
{
    if ([self hasAttachments]) {
        NSString *attachmentId = self.attachmentIds[0];
        TSAttachment *attachment = [TSAttachment fetchObjectWithUniqueID:attachmentId];
        if (attachment) {
            return attachment.description;
        } else {
            return NSLocalizedString(@"UNKNOWN_ATTACHMENT_LABEL", @"In Inbox view, last message label for thread with corrupted attachment.");
        }
    } else {
        return self.plainTextBody;
    }
}

- (void)removeWithTransaction:(YapDatabaseReadWriteTransaction *)transaction
{
    [super removeWithTransaction:transaction];
    
    for (NSString *attachmentId in self.attachmentIds) {
        TSAttachment *attachment = [TSAttachment fetchObjectWithUniqueID:attachmentId transaction:transaction];
        [attachment removeWithTransaction:transaction];
    };
    
    // Updates inbox thread preview
    [self touchThreadWithTransaction:transaction];
}

- (void)touchThreadWithTransaction:(YapDatabaseReadWriteTransaction *)transaction
{
    [transaction touchObjectForKey:self.uniqueThreadId inCollection:[TSThread collection]];
}

- (BOOL)isExpiringMessage
{
    return self.expiresInSeconds > 0;
}

#pragma mark - Accessors
/** Checks for self.forstaPayload are implementation of the settings within the json payload
 *   moving away from signals
 */
-(NSArray *)attachmentProperties
{
    return [[self forstaPayload] objectForKey:@"attachments"];
}

-(NSString *)messageType
{
    if (_messageType == nil) {
        if ([self.forstaPayload objectForKey:@"type"]) {
            _messageType = [self.forstaPayload objectForKey:@"type"];
        }
    }
    return _messageType;
}

-(NSString *)uniqueId
{
    if (_uniqueId == nil) {
        if ([self.forstaPayload objectForKey:@"messageId"]) {
            _uniqueId = [self.forstaPayload objectForKey:@"messageId"];
        } else {
            _uniqueId = [[NSUUID UUID] UUIDString];
        }
    }
    return _uniqueId;
}

-(void)setBody:(nullable NSString *)value {
    
    if (![_body isEqualToString:value] ) {
        _body = [value copy];
        
        // Force re-render of attributedText
        //        self.plainTextBody = nil;
        self.attributedTextBody = nil;
    }
}

-(nullable NSString *)body {
    return _body;
}

-(void)setPlainTextBody:(nullable NSString *)value
{
    if (![_plainTextBody isEqualToString:value]) {
        _plainTextBody = value;
        
        // Add the new value to the forstaPayload
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{
            if (_plainTextBody.length > 0) {
                NSMutableDictionary *dataDict = [[self.forstaPayload objectForKey:@"data"] mutableCopy];
                if (!dataDict) {
                    dataDict = [NSMutableDictionary new];
                }
                NSMutableArray *body = [[dataDict objectForKey:@"body"] mutableCopy];
                if (!body) {
                    body = [NSMutableArray new];
                }
                
                NSDictionary *oldDict = nil;
                if (body.count > 0) {
                    for (NSDictionary *dict in body) {
                        if ([(NSString *)[dict objectForKey:@"type"] isEqualToString:@"text/plain"]) {
                            oldDict = dict;
                        }
                    }
                }
                NSDictionary *newDict = @{ @"type" : @"text/plain",
                                           @"value" : value };
                [body addObject:newDict];
                
                if (oldDict) {
                    [body removeObject:oldDict];
                }
                
                [dataDict setObject:body forKey:@"body"];
                [self.forstaPayload setObject:dataDict forKey:@"data"];
            } else {
                // Empty value passed, remove the object from the payload
                NSMutableDictionary *dataDict = [[self.forstaPayload objectForKey:@"data"] mutableCopy];
                if (dataDict) {
                    [dataDict removeObjectForKey:@"body"];
                    [self.forstaPayload setObject:dataDict forKey:@"data"];
                }
            }
        });
    }
}

-(nullable NSString *)plainTextBody {
    if (_plainTextBody == nil) {
        if (self.forstaPayload) {
            _plainTextBody = [self plainBodyStringFromPayload];
        }
    }
    return _plainTextBody;
}


-(nullable NSAttributedString *)attributedTextBody
{
    if (_attributedTextBody.length == 0) {
        if (self.forstaPayload) {
            NSString *htmlString = [self htmlBodyStringFromPayload];
            
            if (htmlString.length > 0) {
                // hack to deal with appended <br> on strings from web client
                if (htmlString.length > 4) {
                    NSString *tailString = [htmlString substringWithRange:NSMakeRange(htmlString.length-4, 4)];
                    if ([tailString isEqualToString:[NSString stringWithFormat:@"<br>"]]) {
                        htmlString = [htmlString substringToIndex:htmlString.length-4];
                    }
                }
                
                _attributedTextBody = [NSAttributedString attributedStringFromHTML:htmlString
                                                                        normalFont:[UIFont ows_regularFontWithSize:FLMessageViewFontSize]
                                                                          boldFont:[UIFont ows_boldFontWithSize:FLMessageViewFontSize]
                                                                        italicFont:[UIFont ows_italicFontWithSize:FLMessageViewFontSize]];
            }
        }
        
        // Couldn't part the html string so fall back to plain
        if (_attributedTextBody.length == 0 && self.plainTextBody.length > 0) {
            _attributedTextBody = [NSAttributedString attributedStringFromHTML:self.plainTextBody
                                                                    normalFont:[UIFont ows_regularFontWithSize:FLMessageViewFontSize]
                                                                      boldFont:[UIFont ows_boldFontWithSize:FLMessageViewFontSize]
                                                                    italicFont:[UIFont ows_italicFontWithSize:FLMessageViewFontSize]];
        }
        
        // hack to deal with appended newline on attributedStrings
        NSString *lastChar = [_attributedTextBody.string substringWithRange:NSMakeRange(_attributedTextBody.string.length-1, 1)];
        if ([lastChar isEqualToString:[NSString stringWithFormat:@"\n"]]) {
            _attributedTextBody = [_attributedTextBody attributedSubstringFromRange:NSMakeRange(0, _attributedTextBody.string.length-1)];
        }
    }
    return _attributedTextBody;
}

-(NSMutableDictionary *)forstaPayload
{
    if (_forstaPayload == nil) {
        _forstaPayload = [NSMutableDictionary new];
    }
    return _forstaPayload;
}

-(nullable NSArray *)arrayFromMessageBody:(NSString *)body
{
    // Checks passed message body to see if it is JSON,
    //    If it is, return the array of contents
    //    else, return nil.
    if (body.length == 0) {
        return nil;
    }
    
    NSError *error =  nil;
    NSData *data = [body dataUsingEncoding:NSUTF8StringEncoding];
    
    if (data == nil) { // Not parseable.  Bounce out.
        return nil;
    }
    
    NSArray *output = [NSJSONSerialization JSONObjectWithData:data options:0 error:&error];
    
    if (error) {
        return nil;
    } else {
        return output;
    }
}

-(NSString *)plainBodyStringFromPayload
{
    NSString *returnString = nil;
    if (self.forstaPayload) {
        NSDictionary *data = [self.forstaPayload objectForKey:@"data"];
        NSArray *body = [data objectForKey:@"body"];
        for (NSDictionary *dict in body) {
            if ([(NSString *)[dict objectForKey:@"type"] isEqualToString:@"text/plain"]) {
                returnString = (NSString *)[dict objectForKey:@"value"];
            }
        }
    }
    return returnString;
}

-(NSString *)htmlBodyStringFromPayload;
{
    NSString *returnString = nil;
    if (self.forstaPayload) {
        NSDictionary *data = [self.forstaPayload objectForKey:@"data"];
        NSArray *body = [data objectForKey:@"body"];
        for (NSDictionary *dict in body) {
            if ([(NSString *)[dict objectForKey:@"type"] isEqualToString:@"text/html"]) {
                returnString = (NSString *)[dict objectForKey:@"value"];
            }
        }
    }
    return returnString;
}

@end


NS_ASSUME_NONNULL_END
