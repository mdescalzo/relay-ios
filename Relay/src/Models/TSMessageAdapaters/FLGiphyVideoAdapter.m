//
//  FLGiphyVideoAdapter.m
//  Forsta
//
//  Created by Mark Descalzo on 1/16/18.
//  Copyright © 2018 Forsta. All rights reserved.
//

//
// SOURCE: https://stackoverflow.com/questions/5361145/looping-a-video-with-avfoundation-avplayer
//

#import "FLGiphyVideoAdapter.h"
#import "MIMETypeUtil.h"
#import "JSQMessagesMediaViewBubbleImageMasker.h"
@import AVKit;

#define kNumberOfLoops 5

@interface FLGiphyVideoAdapter() <AVPlayerViewControllerDelegate>

@property (nonatomic, strong) PropertyListPreferences *prefs;
@property NSString *giphyURLString;
@property UIView *containerView;
@property AVPlayerViewController *avController;
@property AVPlayer *avPlayer;
@property NSInteger loopCount;

@end

@implementation FLGiphyVideoAdapter

-(instancetype)initWithURLString:(NSString *)giphyURLString
{
//    if (self = [super initWithFileURL:[NSURL URLWithString:videoURL] isReadyToPlay:YES]) {
    if (self = [super init]) {
        _giphyURLString = giphyURLString;
        _readyToPlay = NO;
        _loopCount = 0;
    }
    return self;
}

- (BOOL)isImage {
    return NO;
}

- (BOOL)isAudio {
    return NO;
}


- (BOOL)isVideo {
    return NO;
}

-(BOOL)isDocument {
    return NO;
}

- (BOOL)canPerformEditingAction:(nonnull SEL)action
{
    return (action == @selector(copy:));
}

- (void)performEditingAction:(nonnull SEL)action
{
    if (action == @selector(copy:)) {
        UIPasteboard.generalPasteboard.string = self.giphyURLString;
        return;
    }
}

- (NSUInteger)mediaHash
{
    return self.giphyURLString.hash;
}

- (UIView *)mediaPlaceholderView
{
    return [super mediaPlaceholderView];
}

- (UIView *)mediaView
{
    if (!self.containerView) {
        self.containerView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, self.mediaViewDisplaySize.width, self.mediaViewDisplaySize.height)];
        self.containerView.clipsToBounds = YES;
        self.containerView.backgroundColor = [self bubbleColor];
        [JSQMessagesMediaViewBubbleImageMasker applyBubbleImageMaskToMediaView:self.containerView
                                                                    isOutgoing:self.appliesMediaViewMaskAsOutgoing];
    }
    if (!self.avController) {
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(moviePlayerDidFinish:)
                                                     name:AVPlayerItemDidPlayToEndTimeNotification
                                                   object:self.avPlayer];
        
        self.avController = [[AVPlayerViewController alloc] init];
        self.avController.showsPlaybackControls = YES;
        self.avPlayer = [AVPlayer playerWithURL:[NSURL URLWithString:self.giphyURLString]];
        self.avController.player = self.avPlayer;
        self.avController.view.frame = self.containerView.bounds;
        self.avController.view.backgroundColor = [UIColor clearColor];
        [self.containerView addSubview:self.avController.view];
        [self.avController.player play];
    }
    return self.containerView;
//    return self.avController.view;
}

- (CGSize)mediaViewDisplaySize
{
//    if (self.giphyView) {
//        return self.giphyView.frame.size;
//    } else {
        return [super mediaViewDisplaySize];
//    }
}

#pragma mark - NSCoding

- (instancetype)initWithCoder:(NSCoder *)aDecoder
{
    self = [super initWithCoder:aDecoder];
    if (self) {
        self.giphyURLString = [aDecoder decodeObjectForKey:NSStringFromSelector(@selector(giphyURLString))];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)aCoder
{
    [super encodeWithCoder:aCoder];
    [aCoder encodeObject:self.giphyURLString forKey:NSStringFromSelector(@selector(giphyURLString))];
}


- (nonnull id)copyWithZone:(nullable NSZone *)zone
{
    FLGiphyVideoAdapter *copy = [[FLGiphyVideoAdapter allocWithZone:zone] initWithURLString:self.giphyURLString];
//                                                                                   incoming:!self.appliesMediaViewMaskAsOutgoing];
    copy.appliesMediaViewMaskAsOutgoing = self.appliesMediaViewMaskAsOutgoing;
    return copy;
}

- (void)moviePlayerDidFinish:(NSNotification *)note {
    if (note.object == self.avPlayer.currentItem) {
        [self.avPlayer.currentItem seekToTime:kCMTimeZero];
        self.loopCount++;

        if (self.loopCount < kNumberOfLoops) {
            [self.avPlayer play];
        } else {
            self.loopCount = 0;
            [self.avPlayer pause];
        }
    }
}

-(void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

// MARK: - Helpers

-(PropertyListPreferences *)prefs
{
    if (_prefs == nil) {
        _prefs = Environment.preferences;
    }
    return _prefs;
}

-(UIColor *)bubbleColor {
    if (self.isOutgoing) {
        return [[ForstaColors outgoingBubbleColors] objectForKey:self.prefs.outgoingBubbleColorKey];
    } else {
        return [[ForstaColors incomingBubbleColors] objectForKey:self.prefs.incomingBubbleColorKey];
    }
    
}

@end
