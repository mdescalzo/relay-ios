//
//  ImagePreviewViewController.m
//  Forsta
//
//  Created by Mark on 9/19/17.
//  Copyright © 2017 Forsta. All rights reserved.
//

#import "ImagePreviewViewController.h"

@interface ImagePreviewViewController ()

//@property (nonatomic, weak) IBOutlet UIImageView *imageView;
// @property (nonatomic, weak) IBOutlet UINavigationBar *navBar;
@property (nonatomic, weak) IBOutlet UIButton *sendButton;
@property (nonatomic, weak) IBOutlet UIButton *cancelButton;

-(IBAction)didPressCancelButton:(id)sender;
-(IBAction)didPressSendButton:(id)sender;

@end

@implementation ImagePreviewViewController

@synthesize image = _image;

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    self.imageView.image = self.image;
}

-(void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
//    self.imageView.image = self.image;
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

-(IBAction)didPressCancelButton:(id)sender
{
    [self.delegate didPressCancel:self];
}

-(IBAction)didPressSendButton:(id)sender
{
    [self.delegate didPressSend:self];
}

/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/

-(UIImage *)image
{
    return _image;
}

-(void)setImage:(UIImage *)value
{
    if (![_image isEqual:value] && value != nil) {
        _image = [value copy];
        self.imageView.image = _image;
//        [self.view setNeedsDisplay];
    }
}

@end
