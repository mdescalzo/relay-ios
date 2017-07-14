//  TSMessageAdapter.m
//
//  Signal
//
//  Created by Frederic Jacobs on 24/11/14.
//  Copyright (c) 2014 Open Whisper Systems. All rights reserved.
//

#import "OWSCall.h"
#import "TSAttachmentPointer.h"
#import "TSAttachmentStream.h"
#import "TSCall.h"
#import "TSContactThread.h"
#import "TSContentAdapters.h"
#import "TSErrorMessage.h"
#import "TSGroupThread.h"
#import "TSIncomingMessage.h"
#import "TSInfoMessage.h"
#import "TSOutgoingMessage.h"
#import <MobileCoreServices/MobileCoreServices.h>


@interface TSMessageAdapter ()

// ---

@property (nonatomic, retain) TSContactThread *thread;

// OR for groups

@property (nonatomic, copy) NSString *senderId;
@property (nonatomic, copy) NSString *senderDisplayName;

// for InfoMessages

@property TSInfoMessageType infoMessageType;

// for ErrorMessages

@property TSErrorMessageType errorMessageType;

// for outgoing Messages only

@property NSInteger outgoingMessageStatus;

// for MediaMessages

@property JSQMediaItem<OWSMessageEditing> *mediaItem;


// -- Redeclaring properties from OWSMessageData protocol to synthesize variables
@property (nonatomic) TSMessageAdapterType messageType;
@property (nonatomic) BOOL isExpiringMessage;
@property (nonatomic) BOOL shouldStartExpireTimer;
@property (nonatomic) uint64_t expiresAtSeconds;
@property (nonatomic) uint32_t expiresInSeconds;

@property (nonatomic, copy) NSDate *messageDate;
@property (nonatomic, retain) NSString *messageBody;
@property (nonatomic, strong) NSAttributedString *attributedMessageBody;

@property NSUInteger identifier;

@end


@implementation TSMessageAdapter

- (instancetype)initWithInteraction:(TSInteraction *)interaction
{
    self = [super init];
    if (!self) {
        return self;
    }

    _interaction = interaction;
    _messageDate = interaction.date;
    // TODO casting a string to an integer? At least need a comment here explaining why we are doing this.
    // Can we just remove this? Haven't found where we're using it...
    _identifier = (NSUInteger)interaction.uniqueId;

    if ([interaction isKindOfClass:[TSMessage class]]) {
        TSMessage *message = (TSMessage *)interaction;
        _isExpiringMessage = message.isExpiringMessage;
        _expiresAtSeconds = message.expiresAt / 1000;
        _expiresInSeconds = message.expiresInSeconds;
        _shouldStartExpireTimer = message.shouldStartExpireTimer;
    } else {
        _isExpiringMessage = NO;
    }

    return self;
}

+ (id<OWSMessageData>)messageViewDataWithInteraction:(TSInteraction *)interaction inThread:(TSThread *)thread contactsManager:(id<ContactsManagerProtocol>)contactsManager
{
    TSMessageAdapter *adapter = [[TSMessageAdapter alloc] initWithInteraction:interaction];

    if ([thread isKindOfClass:[TSContactThread class]]) {
        adapter.thread = (TSContactThread *)thread;
        if ([interaction isKindOfClass:[TSIncomingMessage class]]) {
            NSString *contactId       = ((TSContactThread *)thread).contactIdentifier;
            adapter.senderId          = contactId;
            adapter.senderDisplayName = [contactsManager nameStringForPhoneIdentifier:contactId];
            adapter.messageType       = TSIncomingMessageAdapter;
        } else {
            adapter.senderId          = ME_MESSAGE_IDENTIFIER;
            adapter.senderDisplayName = NSLocalizedString(@"ME_STRING", @"");
            adapter.messageType       = TSOutgoingMessageAdapter;
        }
    } else if ([thread isKindOfClass:[TSGroupThread class]]) {
        if ([interaction isKindOfClass:[TSIncomingMessage class]]) {
            TSIncomingMessage *message = (TSIncomingMessage *)interaction;
            adapter.senderId           = message.authorId;
            adapter.senderDisplayName = [contactsManager nameStringForPhoneIdentifier:message.authorId];
            adapter.messageType        = TSIncomingMessageAdapter;
        } else {
            adapter.senderId          = ME_MESSAGE_IDENTIFIER;
            adapter.senderDisplayName = NSLocalizedString(@"ME_STRING", @"");
            adapter.messageType       = TSOutgoingMessageAdapter;
        }
    }

    if ([interaction isKindOfClass:[TSIncomingMessage class]] ||
        [interaction isKindOfClass:[TSOutgoingMessage class]]) {
        TSMessage *message  = (TSMessage *)interaction;
        
#warning Add catch for attributedtext below
        NSArray *bodyArray = [self arrayFromMessageBody:message.body];
        NSString *plainString = [self plainBodyStringFromBlob:bodyArray];
        NSString *htmlString = [self htmlBodyStringFromBlob:bodyArray];
        
        if (bodyArray == nil) {
            if (message.body) {
                adapter.messageBody = message.body;
                adapter.attributedMessageBody = [[NSAttributedString alloc] initWithString:message.body
                                                                                attributes:@{ NSFontAttributeName : [UIFont preferredFontForTextStyle:UIFontTextStyleBody] }];
            }
        } else if (htmlString.length > 0) {
            adapter.messageBody = plainString;
            NSData *data = [htmlString dataUsingEncoding:NSUTF8StringEncoding];
            NSError *error = nil;
            NSDictionary *attributes;
            NSAttributedString *string = [[NSAttributedString alloc] initWithData:data
                                                                          options: @{ NSCharacterEncodingDocumentAttribute: [NSNumber numberWithInt:NSUTF8StringEncoding] }
                                                               documentAttributes:&attributes
                                                                            error:&error];
            /*@{ NSDocumentTypeDocumentAttribute: NSHTMLTextDocumentType,
             NSCharacterEncodingDocumentAttribute: [NSNumber numberWithInt:NSUTF8StringEncoding] } */
            adapter.attributedMessageBody = string;
            if (error) {
                DDLogError(@"%@", error.description);
            }
        } else {
            adapter.messageBody = plainString;
            adapter.attributedMessageBody = [[NSAttributedString alloc] initWithString:plainString
                                                                            attributes:@{ NSFontAttributeName : [UIFont preferredFontForTextStyle:UIFontTextStyleBody] }];
        }
        

        if ([message hasAttachments]) {
            for (NSString *attachmentID in message.attachmentIds) {
                TSAttachment *attachment = [TSAttachment fetchObjectWithUniqueID:attachmentID];

                if ([attachment isKindOfClass:[TSAttachmentStream class]]) {
                    TSAttachmentStream *stream = (TSAttachmentStream *)attachment;
                    if ([stream isAnimated]) {
                        adapter.mediaItem = [[TSAnimatedAdapter alloc] initWithAttachment:stream];
                        adapter.mediaItem.appliesMediaViewMaskAsOutgoing =
                            [interaction isKindOfClass:[TSOutgoingMessage class]];
                        break;
                    } else if ([stream isImage]) {
                        adapter.mediaItem = [[TSPhotoAdapter alloc] initWithAttachment:stream];
                        adapter.mediaItem.appliesMediaViewMaskAsOutgoing =
                            [interaction isKindOfClass:[TSOutgoingMessage class]];
                        break;
                    } else {
                        adapter.mediaItem = [[TSVideoAttachmentAdapter alloc]
                            initWithAttachment:stream
                                      incoming:[interaction isKindOfClass:[TSIncomingMessage class]]];
                        adapter.mediaItem.appliesMediaViewMaskAsOutgoing =
                            [interaction isKindOfClass:[TSOutgoingMessage class]];
                        break;
                    }
                } else if ([attachment isKindOfClass:[TSAttachmentPointer class]]) {
                    TSAttachmentPointer *pointer = (TSAttachmentPointer *)attachment;
                    adapter.messageType          = TSInfoMessageAdapter;

                    if (pointer.isDownloading) {
                        adapter.messageBody = NSLocalizedString(@"ATTACHMENT_DOWNLOADING", nil);
                    } else {
                        if (pointer.hasFailed) {
                            adapter.messageBody = NSLocalizedString(@"ATTACHMENT_QUEUED", nil);
                        } else {
                            adapter.messageBody = NSLocalizedString(@"ATTACHMENT_DOWNLOAD_FAILED", nil);
                        }
                    }
                } else {
                    DDLogError(@"We retrieved an attachment that doesn't have a known type : %@",
                               NSStringFromClass([attachment class]));
                }
            }
        }
    } else if ([interaction isKindOfClass:[TSCall class]]) {
        TSCall *callRecord = (TSCall *)interaction;
        return [[OWSCall alloc] initWithCallRecord:callRecord];
    } else if ([interaction isKindOfClass:[TSInfoMessage class]]) {
        TSInfoMessage *infoMessage = (TSInfoMessage *)interaction;
        adapter.infoMessageType    = infoMessage.messageType;
        adapter.messageBody        = infoMessage.description;
        adapter.messageType        = TSInfoMessageAdapter;
        if (adapter.infoMessageType == TSInfoMessageTypeGroupQuit ||
            adapter.infoMessageType == TSInfoMessageTypeGroupUpdate) {
            // repurposing call display for info message stuff for group updates, ! adapter will know because the date
            // is nil
            CallStatus status = 0;
            if (adapter.infoMessageType == TSInfoMessageTypeGroupQuit) {
                status = kGroupUpdateLeft;
            } else if (adapter.infoMessageType == TSInfoMessageTypeGroupUpdate) {
                status = kGroupUpdate;
            }
            OWSCall *call = [[OWSCall alloc] initWithInteraction:interaction
                                                        callerId:@""
                                               callerDisplayName:adapter.messageBody
                                                            date:nil
                                                          status:status
                                                   displayString:@""];
            return call;
        }
    } else {
        TSErrorMessage *errorMessage = (TSErrorMessage *)interaction;
        adapter.errorMessageType = errorMessage.errorType;
        adapter.messageBody          = errorMessage.description;
        adapter.messageType          = TSErrorMessageAdapter;
    }

    if ([interaction isKindOfClass:[TSOutgoingMessage class]]) {
        adapter.outgoingMessageStatus = ((TSOutgoingMessage *)interaction).messageState;
    }

    return adapter;
}

- (NSString *)senderId {
    if (_senderId) {
        return _senderId;
    } else {
        return ME_MESSAGE_IDENTIFIER;
    }
}

- (NSDate *)date {
    return self.messageDate;
}

#pragma mark - OWSMessageEditing Protocol

- (BOOL)canPerformEditingAction:(SEL)action
{

    // Deletes are always handled by TSMessageAdapter
    if (action == @selector(delete:)) {
        return YES;
    }

    // Delegate other actions for media items
    if (self.isMediaMessage) {
        return [self.mediaItem canPerformEditingAction:action];
    } else if (self.messageType == TSInfoMessageAdapter || self.messageType == TSErrorMessageAdapter) {
        return NO;
    } else {
        // Text message - no media attachment
        if (action == @selector(copy:)) {
            return YES;
        }
    }
    return NO;
}

- (void)performEditingAction:(SEL)action
{
    // Deletes are always handled by TSMessageAdapter
    if (action == @selector(delete:)) {
        DDLogDebug(@"Deleting interaction with uniqueId: %@", self.interaction.uniqueId);
        [self.interaction remove];
        return;
    }

    // Delegate other actions for media items
    if (self.isMediaMessage) {
        [self.mediaItem performEditingAction:action];
        return;
    } else {
        // Text message - no media attachment
        if (action == @selector(copy:)) {
            UIPasteboard.generalPasteboard.string = self.messageBody;
            return;
        }
    }

    // Shouldn't get here, as only supported actions should be exposed via canPerformEditingAction
    NSString *actionString = NSStringFromSelector(action);
    DDLogError(@"'%@' action unsupported for TSInteraction: uniqueId=%@, mediaType=%@",
        actionString,
        self.interaction.uniqueId,
        [self.mediaItem class]);
}

- (BOOL)isMediaMessage {
    return _mediaItem ? YES : NO;
}

- (id<JSQMessageMediaData>)media {
    return _mediaItem;
}

- (NSString *)text {
    return self.messageBody;
}

-(NSAttributedString *)attributedText
{
    return self.attributedMessageBody;
}

- (NSUInteger)messageHash
{
    if (self.isMediaMessage) {
        return [self.mediaItem mediaHash];
    } else {
        return self.identifier;
    }
}

- (NSInteger)messageState {
    return self.outgoingMessageStatus;
}

- (CGFloat)mediaViewAlpha
{
    return (CGFloat)(self.isMediaBeingSent ? 0.75 : 1);
}

- (BOOL)isMediaBeingSent
{
    if ([self.interaction isKindOfClass:[TSOutgoingMessage class]]) {
        TSOutgoingMessage *outgoingMessage = (TSOutgoingMessage *)self.interaction;
        if (outgoingMessage.hasAttachments && outgoingMessage.messageState == TSOutgoingMessageStateAttemptingOut) {
            return YES;
        }
    }
    return NO;
}

- (BOOL)isOutgoingAndDelivered
{
    if ([self.interaction isKindOfClass:[TSOutgoingMessage class]]) {
        TSOutgoingMessage *outgoingMessage = (TSOutgoingMessage *)self.interaction;
        if (outgoingMessage.messageState == TSOutgoingMessageStateDelivered) {
            return YES;
        }
    }
    return NO;
}

+(nullable NSArray *)arrayFromMessageBody:(NSString *)body
{
    // Checks passed message body to see if it is JSON,
    //    If it is, return the array of contents
    //    else, return nil.
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

+(NSString *)plainBodyStringFromBlob:(NSArray *)blob
{
    if ([blob count] > 0) {
        NSDictionary *tmpDict = (NSDictionary *)[blob lastObject];
        NSDictionary *data = [tmpDict objectForKey:@"data"];
        NSArray *body = [data objectForKey:@"body"];
        for (NSDictionary *dict in body) {
            if ([(NSString *)[dict objectForKey:@"type"] isEqualToString:@"text/plain"]) {
                return (NSString *)[dict objectForKey:@"value"];
            }
        }
    }
    return @"";
}

+(NSString *)htmlBodyStringFromBlob:(NSArray *)blob
{
    if ([blob count] > 0) {
        NSDictionary *tmpDict = (NSDictionary *)[blob lastObject];
        NSDictionary *data = [tmpDict objectForKey:@"data"];
        NSArray *body = [data objectForKey:@"body"];
        for (NSDictionary *dict in body) {
            if ([(NSString *)[dict objectForKey:@"type"] isEqualToString:@"text/html"]) {
                return (NSString *)[dict objectForKey:@"value"];
            }
        }
    }
    return @"";
}

@end
