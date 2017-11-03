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

static const CGFloat cellPadding = 5.0f;
//static const CGFloat iconSize = 40.0f;
static const CGFloat iconInset = 5.0f;
static const CGFloat viewHeight = 50.0f;
static const CGFloat spacing = 3.0f;

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
        return [UIColor blackColor];
    } else {
        return [UIColor jsq_messageBubbleLightGrayColor];
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

#pragma mark - JSQMessageMediaData protocol

- (UIView *)mediaView
{
    CGRect imageFrame = CGRectMake(cellPadding + iconInset,
                                   cellPadding + iconInset,
                                   [self mediaViewDisplaySize].height - ((cellPadding + iconInset)*2),
                                   [self mediaViewDisplaySize].height - ((cellPadding + iconInset)*2));
    UIImageView *docImageView = [[UIImageView alloc] initWithFrame:imageFrame];
    docImageView.image = [self attachmentImage];
    docImageView.contentMode = UIViewContentModeScaleAspectFit;
    
    CGRect filenameFrame = CGRectMake(imageFrame.origin.x + imageFrame.size.width + spacing,
                                      cellPadding,
                                      [self mediaViewDisplaySize].width - ((cellPadding + iconInset)*2) - (imageFrame.size.width + cellPadding),
                                      ([self mediaViewDisplaySize].height - ((cellPadding + iconInset)*2)) * 0.6f);
    UILabel *filenameLabel = [[UILabel alloc] initWithFrame:filenameFrame];
    NSString *filename = [[self.attachment filePath] lastPathComponent];
    filenameLabel.font = [UIFont ows_regularFontWithSize:15.0];
    filenameLabel.textColor = self.textColor;
    filenameLabel.text = filename;
    filenameLabel.lineBreakMode = NSLineBreakByTruncatingMiddle;
    filenameLabel.backgroundColor = [UIColor clearColor];
    
    CGRect filesizeFrame = CGRectMake(imageFrame.origin.x + imageFrame.size.width  + (spacing * 3),
                                      filenameFrame.origin.y + filenameFrame.size.height,
                                      [self mediaViewDisplaySize].width - ((cellPadding + iconInset)*2) - imageFrame.size.width - (spacing * 3),
                                      ([self mediaViewDisplaySize].height - ((cellPadding + iconInset)*2)) * 0.4f);
    unsigned long long fileSize =
    [[NSFileManager defaultManager] attributesOfItemAtPath:[self.attachment filePath] error:nil].fileSize;
    NSString *fileSizeString = [self formatFileSize:fileSize];
    UILabel *filesizeLabel = [[UILabel alloc] initWithFrame:filesizeFrame];
    filesizeLabel.font = [UIFont ows_regularFontWithSize:12.0];
    filesizeLabel.textColor = self.textColor;
    filesizeLabel.text = fileSizeString;
    filesizeLabel.backgroundColor = [UIColor clearColor];

    UIView *mediaView = [[UIView alloc] initWithFrame:CGRectMake(0.0f, 0.0f, [self mediaViewDisplaySize].width, [self mediaViewDisplaySize].height)];
    [mediaView addSubview:docImageView];
    [mediaView addSubview:filenameLabel];
    [mediaView addSubview:filesizeLabel];
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
