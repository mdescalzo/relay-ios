#import "UIUtil.h"

#define CONTACT_PICTURE_VIEW_BORDER_WIDTH 0.5f

// TODO: Customize more clearly/thoroughly for Forsta look and feel.
@implementation UIUtil

+ (void)applyRoundedBorderToImageView:(UIImageView *__strong *)imageView {
    [[*imageView layer] setBorderWidth:CONTACT_PICTURE_VIEW_BORDER_WIDTH];
    [[*imageView layer] setBorderColor:[[UIColor clearColor] CGColor]];
    [[*imageView layer] setCornerRadius:CGRectGetWidth([*imageView frame]) / 2];
    [[*imageView layer] setMasksToBounds:YES];
}


+ (void)removeRoundedBorderToImageView:(UIImageView *__strong *)imageView {
    [[*imageView layer] setBorderWidth:0];
    [[*imageView layer] setCornerRadius:0];
}

+ (completionBlock)modalCompletionBlock {
    completionBlock block = ^void() {
      [[UIApplication sharedApplication] setStatusBarStyle:UIStatusBarStyleLightContent];
    };

    return block;
}

+ (void)applyDefaultSystemAppearence
{
    [[UIApplication sharedApplication] setStatusBarStyle:UIStatusBarStyleDefault];
    [[UINavigationBar appearance] setBarStyle:UIBarStyleDefault];
    [[UINavigationBar appearance] setTintColor:[UIColor blackColor]];
    [[UIBarButtonItem appearance] setTintColor:[UIColor blackColor]];
    [[UINavigationBar appearance] setTitleTextAttributes:@{
                                                           NSForegroundColorAttributeName : [UIColor blackColor],
                                                           }];
}

+ (void)applyForstaAppearence
{
    [[UIApplication sharedApplication] setStatusBarStyle:UIStatusBarStyleLightContent];
    [[UINavigationBar appearance] setBarTintColor:[UIColor ows_materialBlueColor]];
    [[UINavigationBar appearance] setTintColor:[UIColor whiteColor]];
    
    [[UIBarButtonItem appearanceWhenContainedIn:[UISearchBar class], nil] setTintColor:[UIColor ows_materialBlueColor]];
    
    [[UISwitch appearance] setOnTintColor:[UIColor ows_materialBlueColor]];
    [[UIToolbar appearance] setTintColor:[UIColor ows_materialBlueColor]];
    [[UIBarButtonItem appearance] setTintColor:[UIColor whiteColor]];
    
    // If we set NSShadowAttributeName, the NSForegroundColorAttributeName value is ignored.
    [[UINavigationBar appearance] setTitleTextAttributes:@{
                                                           NSForegroundColorAttributeName : [UIColor whiteColor],
                                                           }];
}

@end
