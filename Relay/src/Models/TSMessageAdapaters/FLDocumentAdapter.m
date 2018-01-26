//
//  FLDocumentAdapter.m
//  Forsta
//
//  Created by Mark on 11/2/17.
//  Copyright © 2017 Forsta. All rights reserved.
//

#import "FLDocumentAdapter.h"
#import "TSAttachmentStream.h"
#import "JSQMediaItem+OWS.h"
#import "UIFont+OWS.h"
#import "JSQMessagesMediaViewBubbleImageMasker.h"
#import "UIColor+JSQMessages.h"
#import "MIMETypeUtil.h"

static const CGFloat cellPadding = 5.0f;
static const CGFloat iconInset = 5.0f;
static const CGFloat viewHeight = 60.0f;
static const CGFloat spacing = 3.0f;
static const CGFloat insetFactor = 0.45f;

@interface FLDocumentAdapter()

@property (nonatomic, strong) PropertyListPreferences *prefs;

@end

@implementation FLDocumentAdapter

- (instancetype)initWithAttachment:(TSAttachmentStream *)attachment {
    if (self = [super init]) {
        _attachment = attachment;
        _attachmentId = attachment.uniqueId;
        _fileData = [NSData dataWithContentsOfURL:[attachment mediaURL]];

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
    return YES;
}

- (BOOL)isMediaMessage {
    return YES;
}

-(UIColor *)textColor
{
    if (self.isOutgoing) {
        return [UIColor whiteColor];
    } else {
        return [UIColor blackColor];
    }
}

-(UIColor *)bubbleColor {
    if (self.isOutgoing) {
        return [[ForstaColors outgoingBubbleColors] objectForKey:self.prefs.outgoingBubbleColorKey];
    } else {
        return [[ForstaColors incomingBubbleColors] objectForKey:self.prefs.incomingBubbleColorKey];
    }

}

-(UIImage *)attachmentImage
{
    if (self.isOutgoing) {
        return [UIImage imageNamed:@"file-white-40"];
    } else {
        return [UIImage imageNamed:@"file-black-40"];
    }
}

-(PropertyListPreferences *)prefs
{
    if (_prefs == nil) {
        _prefs = Environment.preferences;
    }
    return _prefs;
}

#pragma mark - JSQMessageMediaData protocol

- (UIView *)mediaView
{
    CGRect imageFrame = CGRectMake(cellPadding + iconInset,
                                   cellPadding + iconInset,
                                   [self mediaViewDisplaySize].height - ((cellPadding + iconInset)*2.0f),
                                   [self mediaViewDisplaySize].height - ((cellPadding + iconInset)*2.0f));
    UIImageView *docImageView = [[UIImageView alloc] initWithFrame:imageFrame];
    docImageView.image = [self attachmentImage];
    docImageView.contentMode = UIViewContentModeScaleAspectFit;
    
    CGRect filenameFrame = CGRectMake(imageFrame.origin.x + imageFrame.size.width + spacing,
                                      cellPadding,
                                      [self mediaViewDisplaySize].width - ((cellPadding + iconInset)*2.0f) - (imageFrame.size.width + cellPadding*2.0f),
                                      ([self mediaViewDisplaySize].height - ((cellPadding + iconInset)*2.0f)) * 0.6f);
    UILabel *filenameLabel = [[UILabel alloc] initWithFrame:filenameFrame];
    NSString *filename = [[self.attachment filePath] lastPathComponent];
    filenameLabel.font = [UIFont ows_regularFontWithSize:15.0f];
    filenameLabel.textColor = self.textColor;
    filenameLabel.text = filename;
    filenameLabel.lineBreakMode = NSLineBreakByTruncatingMiddle;
    filenameLabel.backgroundColor = [UIColor clearColor];
    
    CGRect filesizeFrame = CGRectMake(imageFrame.origin.x + imageFrame.size.width  + (spacing * 3.0f),
                                      filenameFrame.origin.y + filenameFrame.size.height,
                                      [self mediaViewDisplaySize].width - ((cellPadding + iconInset)*2.0f) - imageFrame.size.width - (spacing * 3.0f),
                                      ([self mediaViewDisplaySize].height - ((cellPadding + iconInset)*2.0f)) * 0.4f);
    unsigned long long fileSize =
    [[NSFileManager defaultManager] attributesOfItemAtPath:[self.attachment filePath] error:nil].fileSize;
    NSString *fileSizeString = [self formatFileSize:fileSize];
    UILabel *filesizeLabel = [[UILabel alloc] initWithFrame:filesizeFrame];
    filesizeLabel.font = [UIFont ows_boldFontWithSize:12.0f];
    filesizeLabel.textColor = self.textColor;
    filesizeLabel.text = fileSizeString;
    filesizeLabel.backgroundColor = [UIColor clearColor];
    
    NSString *fileExtension = filename.pathExtension;
    if (fileExtension.length < 1) {
        [MIMETypeUtil getSupportedExtensionFromDocumentMIMEType:self.attachment.contentType];
    }
    if (fileExtension.length < 1) {
        fileExtension = @"?";
    }
    CGRect extensionFrame = CGRectMake(docImageView.frame.origin.x + (docImageView.frame.size.width * (1.0f-insetFactor)/2.0f),
                                       docImageView.frame.origin.y + (docImageView.frame.size.height * (1.0f-insetFactor)/2.0f),
                                       docImageView.frame.size.width * insetFactor,
                                       docImageView.frame.size.height * insetFactor);
    UILabel *extensionLabel = [[UILabel alloc] initWithFrame:extensionFrame];
    extensionLabel.text = fileExtension.uppercaseString;
    extensionLabel.textColor = self.textColor;
    extensionLabel.adjustsFontSizeToFitWidth = YES;
    extensionLabel.textAlignment = NSTextAlignmentCenter;
    extensionLabel.baselineAdjustment = UIBaselineAdjustmentAlignCenters;

    UIView *mediaView = [[UIView alloc] initWithFrame:CGRectMake(0.0f, 0.0f, [self mediaViewDisplaySize].width, [self mediaViewDisplaySize].height)];
    [mediaView addSubview:docImageView];
    [mediaView addSubview:filenameLabel];
    [mediaView addSubview:filesizeLabel];
    [mediaView addSubview:extensionLabel];
    
    mediaView.backgroundColor = self.bubbleColor;
    mediaView.clipsToBounds = YES;
    
    [JSQMessagesMediaViewBubbleImageMasker applyBubbleImageMaskToMediaView:mediaView
                                                                isOutgoing:self.appliesMediaViewMaskAsOutgoing];
    
    return mediaView;
}

- (CGSize)mediaViewDisplaySize
{
    if ([UIDevice currentDevice].userInterfaceIdiom == UIUserInterfaceIdiomPad) {
        return CGSizeMake(315.0f, viewHeight);
    }
    
    return CGSizeMake(210.0f, viewHeight);
}

- (NSUInteger)mediaHash
{
    return self.attachment.hash;
}

#pragma mark - OWSMessageEditing Protocol

- (BOOL)canPerformEditingAction:(SEL)action
{
    return (action == NSSelectorFromString(@"share:"));
}

- (void)performEditingAction:(SEL)action
{
    NSString *actionString = NSStringFromSelector(action);
    
    if ([self isDocument]) {
        if (action == NSSelectorFromString(@"share:")) {
            NSURL *documentURL = self.attachment.mediaURL;
            UIActivityViewController *activityController = [[UIActivityViewController alloc] initWithActivityItems:@[ documentURL ]
                                                                                             applicationActivities:nil];
            UIWindow *window = [UIApplication sharedApplication].keyWindow;
            UIViewController *rootVC = window.rootViewController;
            [rootVC presentViewController:activityController animated:YES completion:nil];
        }
        // TODO: Implement this:
//    } else if (action == NSSelectorFromString(@"save:")) {
//        UIImageWriteToSavedPhotosAlbum(self.image, nil, nil, nil);
//        return;

    } else {
        // Shouldn't get here, as only supported actions should be exposed via canPerformEditingAction
        DDLogError(@"'%@' action unsupported for %@: attachmentId=%@", actionString, self.class, self.attachmentId);
    }
}

#pragma mark - NSCoding

- (instancetype)initWithCoder:(NSCoder *)aDecoder
{
    self = [super initWithCoder:aDecoder];
    if (self) {
        _attachment = [aDecoder decodeObjectForKey:NSStringFromSelector(@selector(attachment))];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)aCoder
{
    [super encodeWithCoder:aCoder];
    [aCoder encodeObject:self.attachment forKey:NSStringFromSelector(@selector(attachment))];
}


#pragma mark - NSCopying

- (instancetype)copyWithZone:(NSZone *)zone
{
    FLDocumentAdapter *copy = [[FLDocumentAdapter allocWithZone:zone] initWithAttachment:self.attachment];
    copy.appliesMediaViewMaskAsOutgoing = self.appliesMediaViewMaskAsOutgoing;
    return copy;
}

#pragma mark - worker methods
// Lifted from OWS Signal ViewControllerUtils class
-(NSString *)formatFileSize:(unsigned long)fileSize
{
    const unsigned long kOneKilobyte = 1024;
    const unsigned long kOneMegabyte = kOneKilobyte * kOneKilobyte;
    
    NSNumberFormatter *numberFormatter = [NSNumberFormatter new];
    numberFormatter.numberStyle = NSNumberFormatterDecimalStyle;
    
    if (fileSize > kOneMegabyte * 10) {
        return [[numberFormatter stringFromNumber:@((int)round(fileSize / (CGFloat)kOneMegabyte))]
                stringByAppendingString:@" MB"];
    } else if (fileSize > kOneKilobyte * 10) {
        return [[numberFormatter stringFromNumber:@((int)round(fileSize / (CGFloat)kOneKilobyte))]
                stringByAppendingString:@" KB"];
    } else {
        return [NSString stringWithFormat:@"%lu Bytes", fileSize];
    }
}

@end
