//
//  FLGiphyVideoAdapter.h
//  Forsta
//
//  Created by Mark Descalzo on 1/16/18.
//  Copyright © 2018 Forsta. All rights reserved.
//

#import "OWSMessageEditing.h"
#import <JSQMessagesViewController/JSQVideoMediaItem.h>

@interface FLGiphyVideoAdapter : JSQMediaItem <OWSMessageEditing>

@property BOOL readyToPlay;

-(instancetype)initWithURLString:(NSString *)giphyURLString;

- (BOOL)isImage;
- (BOOL)isAudio;
- (BOOL)isVideo;
-(BOOL)isDocument;

@end
