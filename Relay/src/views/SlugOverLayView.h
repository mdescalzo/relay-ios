//
//  SlugOverLayView.h
//  Forsta
//
//  Created by Mark on 9/27/17.
//  Copyright © 2017 Forsta. All rights reserved.
//

#import <UIKit/UIKit.h>

@protocol SlugOverLayViewDelegate <NSObject>

-(void)deleteButtonTappedOnSlugButton:(id)sender;

@end


@interface SlugOverLayView : UIView

@property (nonatomic, strong) NSString *slug;
@property (nonatomic, strong) UIButton *deleteButton;
@property (nonatomic, strong) UILabel *slugLabel;

@property (nonatomic, weak) id<SlugOverLayViewDelegate>delegate;

-(id)initWithSlug:(NSString *)slug frame:(CGRect)frame;

@end
