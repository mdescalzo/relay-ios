//
//  FLGiphyVideoAdapter.m
//  Forsta
//
//  Created by Mark Descalzo on 1/16/18.
//  Copyright © 2018 Forsta. All rights reserved.
//

#import "FLGiphyVideoAdapter.h"
#import "MIMETypeUtil.h"
#import "JSQMessagesMediaViewBubbleImageMasker.h"
@import WebKit;

@interface FLGiphyVideoAdapter() <WKUIDelegate, WKNavigationDelegate>

@property (nonatomic, strong) PropertyListPreferences *prefs;
@property NSString *giphyURLString;
@property WKWebView *giphyView;
@property UIView *containerView;
@end

@implementation FLGiphyVideoAdapter

-(instancetype)initWithURLString:(NSString *)giphyURLString
{
//    if (self = [super initWithFileURL:[NSURL URLWithString:videoURL] isReadyToPlay:YES]) {
    if (self = [super init]) {
        _giphyURLString = giphyURLString;
        _readyToPlay = NO;
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
//    return [super mediaView];
//    if (!self.giphyView || [self.giphyView isLoading]) {
//        return nil;
//    }

    if (!self.containerView ) {
        self.containerView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, self.mediaViewDisplaySize.width, self.mediaViewDisplaySize.height)];
        self.containerView.backgroundColor = [self bubbleColor];
        self.containerView.autoresizesSubviews = YES;
        
        if (!self.giphyView) {
            WKWebViewConfiguration *config = [[WKWebViewConfiguration alloc] init];
            config.allowsInlineMediaPlayback = YES;
            self.giphyView = [[WKWebView alloc] initWithFrame:CGRectMake(0, 0, self.mediaViewDisplaySize.width, self.mediaViewDisplaySize.height)
                                                configuration:config];
            self.giphyView.UIDelegate = self;
            self.giphyView.navigationDelegate = self;
            self.giphyView.allowsBackForwardNavigationGestures = NO;
            
            [self.giphyView loadHTMLString:self.giphyURLString baseURL:nil];
            [self.giphyView sizeToFit];
            self.giphyView.scrollView.scrollEnabled = NO;
            self.giphyView.clipsToBounds = YES;
            self.giphyView.userInteractionEnabled = NO;
            self.giphyView.autoresizesSubviews = YES;
            self.giphyView.translatesAutoresizingMaskIntoConstraints = YES;
            self.giphyView.autoresizingMask =  UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
            
            [self.containerView addSubview:self.giphyView];
        }
    }
    [JSQMessagesMediaViewBubbleImageMasker applyBubbleImageMaskToMediaView:self.containerView
                                                                isOutgoing:self.appliesMediaViewMaskAsOutgoing];
    return self.containerView;
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

// MARK: - WebKitView delegate methods
-(void)webView:(WKWebView *)webView didFinishNavigation:(WKNavigation *)navigation
{
    [webView evaluateJavaScript:@"document.readyState"
              completionHandler:^(id complete, NSError * _Nullable error) {
                  if (complete) {
                      [webView evaluateJavaScript:@"document.body.offsetHeight"
                                completionHandler:^(NSNumber *height, NSError * _Nullable err) {
//                                    CGRect aFrame = CGRectMake(0, 0, self.giphyView.frame.size.width, [height floatValue]);
//                                    self.giphyView.frame = aFrame;
                                    [webView evaluateJavaScript:@"document.body.offsetWidth"
                                              completionHandler:^(NSNumber *width, NSError * _Nullable err2) {
                                                  CGFloat viewRatio = self.containerView.frame.size.width / self.containerView.frame.size.height;
                                                  CGFloat giphyRatio = [width floatValue] / [height floatValue];

                                                  CGFloat finalWidth;
                                                  CGFloat finalHeight;
                                                  if (viewRatio > giphyRatio) {
                                                      finalWidth = self.containerView.frame.size.width;
                                                      finalHeight = finalWidth * self.containerView.frame.size.height / self.containerView.frame.size.width;
                                                  } else {
                                                      finalHeight = self.containerView.frame.size.height;
                                                      finalWidth = finalHeight * self.containerView.frame.size.width / self.containerView.frame.size.height;
                                                  }
                                                  CGRect aFrame = CGRectMake(0, 0, finalWidth, finalHeight);
                                                  self.giphyView.frame = aFrame;
                                                  [self.giphyView setNeedsLayout];
                                                  [self.containerView setNeedsLayout];
                                               }];
                                }];
                  }
              }];
//    webView.evaluateJavaScript("document.readyState", completionHandler: { (complete, error) in
//        if complete != nil {
//            self.webView.evaluateJavaScript("document.body.offsetHeight", completionHandler: { (height, error) in
//                self.containerHeight.constant = height as! CGFloat
//            })
//        }
//
//    })
//    self.giphyView.frame = CGRectMake(0, 0, self.mediaViewDisplaySize.width, self.mediaViewDisplaySize.height);
//    DDLogDebug(@"Size of giphyView: %f, %f", self.giphyView.frame.size.width, self.giphyView
//               .frame.size.height);
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
