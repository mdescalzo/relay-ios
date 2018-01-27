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

#define kMinimumNumberOfLoops 5
#define kMaxRuntimeSeconds 10.0

@interface FLGiphyVideoAdapter() <AVPlayerViewControllerDelegate>

@property (nonatomic, strong) PropertyListPreferences *prefs;
@property NSString *giphyURLString;
@property UIView *containerView;
@property AVPlayerViewController *avController;
//@property AVPlayerLayer *avPlayerLayer;
@property AVQueuePlayer *avPlayer;
@property id avPlayerLooper;
@property NSInteger loopCounter;
@property NSInteger numberOfLoops;

@end

@implementation FLGiphyVideoAdapter

-(instancetype)initWithURLString:(NSString *)giphyURLString
{
    if (self = [super init]) {
        _giphyURLString = giphyURLString;
        _readyToPlay = NO;
        _loopCounter = 0;
        _numberOfLoops = kMinimumNumberOfLoops;
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
//        [[NSNotificationCenter defaultCenter] addObserver:self
//                                                 selector:@selector(moviePlayerDidFinish:)
//                                                     name:AVPlayerItemDidPlayToEndTimeNotification
//                                                   object:self.avPlayer];
        
        self.avController = [[AVPlayerViewController alloc] init];
        self.avController.showsPlaybackControls = YES;

        AVPlayerItem *playerItem = [AVPlayerItem playerItemWithURL:[NSURL URLWithString:self.giphyURLString]];
        self.avPlayer = [AVQueuePlayer playerWithPlayerItem:playerItem];
        self.avController.player = self.avPlayer;

        // Looping for iOS 10.0 and above
        if ([[UIDevice currentDevice].systemVersion floatValue] >= 10.0) {
            self.avPlayerLooper = [AVPlayerLooper playerLooperWithPlayer:self.avPlayer
                                                            templateItem:playerItem];
        }
        // Use KVO to wait until the giphy is ready before attempting to read duration
        NSKeyValueObservingOptions options = NSKeyValueObservingOptionOld | NSKeyValueObservingOptionNew;
        [self.avController.player.currentItem addObserver:self forKeyPath:@"status"
                                                  options:options
                                                  context:nil];

        self.avController.view.frame = self.containerView.bounds;
        self.avController.view.backgroundColor = [UIColor clearColor];
        [self.containerView addSubview:self.avController.view];
        
        [self.avController.player play];

    }
    return self.containerView;
}

- (CGSize)mediaViewDisplaySize
{
    return [super mediaViewDisplaySize];
}

// MARK: - KVO
// SOURCE: Apple's reference for AVPlayerItem
-(void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary<NSKeyValueChangeKey,id> *)change context:(void *)context
{
    if ([keyPath isEqualToString:@"status"]) {
        AVPlayerItemStatus status = AVPlayerItemStatusUnknown;
        // Get the status change from the change dictionary
        NSNumber *statusNumber = change[NSKeyValueChangeNewKey];
        if ([statusNumber isKindOfClass:[NSNumber class]]) {
            status = statusNumber.integerValue;
        }
        // Switch over the status
        switch (status) {
            case AVPlayerItemStatusReadyToPlay:
                // Ready to Play
            {
//                [self.avPlayer play];
//                // Computer number of loops to accomodate very short giphys
//                CGFloat giphyDurationSeconds = CMTimeGetSeconds(self.avPlayer.currentItem.duration);
//                if ((kMaxRuntimeSeconds / giphyDurationSeconds) < kMinimumNumberOfLoops ) {
//                    self.numberOfLoops = kMinimumNumberOfLoops;
//                } else {
//                    self.numberOfLoops = (NSInteger)(kMaxRuntimeSeconds / giphyDurationSeconds);
//                }
            }
                break;
            case AVPlayerItemStatusFailed:
                // Failed. Examine AVPlayerItem.error
                break;
            case AVPlayerItemStatusUnknown:
                // Not ready
                break;
        }
    }
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
    copy.appliesMediaViewMaskAsOutgoing = self.appliesMediaViewMaskAsOutgoing;
    return copy;
}

//- (void)moviePlayerDidFinish:(NSNotification *)note {
//    if (note.object == self.avPlayer.currentItem) {
//        [self.avPlayer.currentItem seekToTime:kCMTimeZero];
//        self.loopCounter++;
//        if (self.loopCounter < self.numberOfLoops) {
//            [self.avPlayer play];
//        } else {
//            self.loopCounter = 0;
//            [self.avPlayer pause];
//        }
//    }
//}

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
