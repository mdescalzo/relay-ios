//
//  FLDocumentAdapter.h
//  Forsta
//
//  Created by Mark Descalzo on 11/2/17.
//  Copyright © 2017 Forsta. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "OWSMessageEditing.h"
#import "JSQMediaItem.h"

@class TSAttachmentStream;

@interface FLDocumentAdapter : JSQMediaItem <OWSMessageEditing, JSQMessageMediaData, NSCoding, NSCopying>

@property TSAttachmentStream *attachment;
@property NSString *attachmentId;
@property NSData *fileData;
@property BOOL isOutgoing;

- (instancetype)initWithAttachment:(TSAttachmentStream *)attachment;

- (BOOL)isImage;
- (BOOL)isAudio;
- (BOOL)isVideo;
-(BOOL)isDocument;

@end
