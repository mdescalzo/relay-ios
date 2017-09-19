//
//  ImagePreviewViewController.h
//  Forsta
//
//  Created by Mark on 9/19/17.
//  Copyright © 2017 Forsta. All rights reserved.
//

#import <UIKit/UIKit.h>

@protocol ImagePreviewViewControllerDelegate;

@interface ImagePreviewViewController : UIViewController

@property (nonatomic, weak) IBOutlet UIImageView *imageView;
@property (strong) UIImage *image;
@property (nonatomic, weak) id <ImagePreviewViewControllerDelegate> delegate;

@end

@protocol ImagePreviewViewControllerDelegate
-(void)didPressCancel:(id)sender;
-(void)didPressSend:(id)sender;
@end
