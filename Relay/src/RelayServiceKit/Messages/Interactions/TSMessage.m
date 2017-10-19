//  Created by Frederic Jacobs on 12/11/14.
//  Copyright (c) 2014 Open Whisper Systems. All rights reserved.

#import "TSMessage.h"
#import "NSDate+millisecondTimeStamp.h"
#import "OWSDisappearingMessagesJob.h"
#import "TSAttachment.h"
#import "TSAttachmentPointer.h"
#import "TSThread.h"
#import <YapDatabase/YapDatabaseTransaction.h>

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

#pragma mark - Lazy instantiation
/** Checks for self.forstaPayload are implementation of the settings within the json payload
 *   moving away from signals
 */

-(NSString *)forstaMessageType
{
    if (_forstaMessageType == nil) {
        if ([self.forstaPayload objectForKey:@"type"]) {
            _forstaMessageType = [self.forstaPayload objectForKey:@"type"];
        }
    }
    return _forstaMessageType;
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
        
        // Not JSON, assign value to plainTextBody
        //        if (![NSJSONSerialization JSONObjectWithData:[value dataUsingEncoding:NSUTF8StringEncoding] options:0 error:nil]) {
        //            self.plainTextBody = value;
        //        }
        // Force re-render of attributedText
        self.attributedTextBody = nil;
    }
}

-(nullable NSString *)body {
    return _body;
}

-(void)setPlainTextBody:(nullable NSString *)value
{
    if (![_plainTextBody isEqualToString:value]) {
        _plainTextBody = [value copy];
        
        // Add the new value to the forstaPayload
        NSMutableDictionary *data = [[self.forstaPayload objectForKey:@"data"] mutableCopy];
        if (!data) {
            data = [NSMutableDictionary new];
        }
        NSMutableArray *body = [[data objectForKey:@"body"] mutableCopy];
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
        
        [data setObject:body forKey:@"body"];
        [self.forstaPayload setObject:data forKey:@"data"];
    }
}

-(nullable NSString *)plainTextBody {
    if (_plainTextBody == nil) {
        if (self.forstaPayload) {
            NSDictionary *data = [self.forstaPayload objectForKey:@"data"];
            NSArray *body = [data objectForKey:@"body"];
            for (NSDictionary *dict in body) {
                if ([(NSString *)[dict objectForKey:@"type"] isEqualToString:@"text/plain"]) {
                    NSString *value = [dict objectForKey:@"value"];
                    if (value.length > 0) {
                        _plainTextBody = value;
                    }
                }
            }
        }
    }
    return _plainTextBody;
}


-(nullable NSAttributedString *)attributedTextBody {
    if (_attributedTextBody == nil) {
        if (self.forstaPayload) {
            NSString *plainString = [self plainBodyStringFromPayload];
            NSString *htmlString = [self htmlBodyStringFromPayload];
            
            if (htmlString.length > 0) {
                //                    htmlString = [NSString stringWithFormat:@"<font size=\"17\">%@</font>", htmlString];
                NSData *data = [htmlString dataUsingEncoding:NSUTF8StringEncoding];
                
                __block NSError *error = nil;
                //            NSDictionary *attributes;
                __block NSAttributedString *atrString;
                
                atrString = [[NSAttributedString alloc] initWithData:data
                                                             options: @{ NSDocumentTypeDocumentAttribute: NSHTMLTextDocumentType,
                                                                         NSCharacterEncodingDocumentAttribute: [NSNumber numberWithInt:NSUTF8StringEncoding] }
                                                  documentAttributes:nil
                                                               error:&error];
                if (error) {
                    DDLogError(@"%@", error.description);
                }
                
                // hack to deal with appended newline on attributedStrings
                NSString *lastChar = [atrString.string substringWithRange:NSMakeRange(atrString.string.length-1, 1)];
                if ([lastChar isEqualToString:[NSString stringWithFormat:@"\n"]]) {
                    atrString = [atrString attributedSubstringFromRange:NSMakeRange(0, atrString.string.length-1)];
                }
                
                // Enumerate and change to correct font size and face.
                NSMutableAttributedString *tmpAtrString = [atrString mutableCopy];
                
                [tmpAtrString beginEditing];
                UIFontDescriptor *baseDescriptor = [UIFont systemFontOfSize:17.0].fontDescriptor;
                [tmpAtrString enumerateAttribute:NSFontAttributeName
                                         inRange:NSMakeRange(0, tmpAtrString.length)
                                         options:0
                                      usingBlock:^(id value, NSRange range, BOOL *stop) {
                                          if (value) {
                                              UIFont *oldFont = (UIFont *)value;
                                              
                                              // adapting to font size variations....scale up to relative to 17.0
                                              CGFloat oldSize = oldFont.pointSize;
                                              CGFloat multiplier = oldSize/12.0;
                                              CGFloat size = multiplier * 17.0;
                                              
                                              UIFontDescriptorSymbolicTraits traits = oldFont.fontDescriptor.symbolicTraits;
                                              UIFontDescriptor *descriptor = [baseDescriptor fontDescriptorWithSymbolicTraits:traits];
                                              if (descriptor) {
                                                  UIFont *newFont = [UIFont fontWithDescriptor:descriptor size:size];
                                                  [tmpAtrString removeAttribute:NSFontAttributeName range:range];
                                                  [tmpAtrString addAttribute:NSFontAttributeName value:newFont range:range];
                                              }
                                          }
                                      }];
                
                _attributedTextBody = [[NSMutableAttributedString alloc] initWithAttributedString:tmpAtrString];
                
            } else  if (plainString.length > 0) {
                _attributedTextBody = [[NSAttributedString alloc] initWithString:plainString
                                                                      attributes:@{ NSFontAttributeName : [UIFont preferredFontForTextStyle:UIFontTextStyleBody] }];
            }
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
