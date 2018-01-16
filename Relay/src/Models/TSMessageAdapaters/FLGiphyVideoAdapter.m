//
//  FLGiphyVideoAdapter.m
//  Forsta
//
//  Created by Mark Descalzo on 1/16/18.
//  Copyright © 2018 Forsta. All rights reserved.
//

#import "FLGiphyVideoAdapter.h"
#import "MIMETypeUtil.h"

@interface FLGiphyVideoAdapter()

@property (nonatomic) BOOL incoming;

@end

@implementation FLGiphyVideoAdapter

-(instancetype)initWithURLString:(NSString *)videoURL incoming:(BOOL)incoming
{
    if (self = [super initWithFileURL:[NSURL URLWithString:videoURL] isReadyToPlay:YES]) {
        
    }
    return self;
}

- (BOOL)isImage {
    return NO;
}

- (BOOL)isAudio {
    return [MIMETypeUtil isSupportedAudioMIMEType:_contentType];
}


- (BOOL)isVideo {
    return [MIMETypeUtil isSupportedVideoMIMEType:_contentType];
}

-(BOOL)isDocument {
    return NO;
}

- (BOOL)canPerformEditingAction:(nonnull SEL)action {
    <#code#>
}

- (void)performEditingAction:(nonnull SEL)action {
    <#code#>
}

- (NSUInteger)mediaHash {
    <#code#>
}

- (UIView *)mediaPlaceholderView {
    <#code#>
}

- (UIView *)mediaView {
    <#code#>
}

- (CGSize)mediaViewDisplaySize {
    <#code#>
}

- (void)encodeWithCoder:(nonnull NSCoder *)aCoder {
    <#code#>
}

- (nullable instancetype)initWithCoder:(nonnull NSCoder *)aDecoder {
    <#code#>
}

- (nonnull id)copyWithZone:(nullable NSZone *)zone {
    <#code#>
}

@end
