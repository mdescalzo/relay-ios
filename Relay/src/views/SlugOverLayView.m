//
//  SlugOverLayView.m
//  Forsta
//
//  Created by Mark on 9/27/17.
//  Copyright © 2017 Forsta. All rights reserved.
//

#import "SlugOverLayView.h"

@interface SlugOverLayView()

@property (nonatomic, strong) UIView *fillView;

@end

@implementation SlugOverLayView

-(instancetype)initWithSlug:(NSString *)slug frame:(CGRect)frame
{
    if (self = [super initWithFrame:frame]) {
        _slug = slug;
        self.backgroundColor = [UIColor clearColor];
        
        _fillView = [UIView new];
        _fillView.layer.cornerRadius = 3.0;
        [self addSubview:_fillView];
        [self sendSubviewToBack:_fillView];
        _slugLabel = [UILabel new];
        
        _slugLabel.text = _slug;
        
        _deleteButton = [UIButton buttonWithType:UIButtonTypeSystem];
        [_deleteButton setTitle:@"✕" forState:UIControlStateNormal];
        _deleteButton.tintColor = [ForstaColors mediumRed];
        [_deleteButton addTarget:self action:@selector(deleteButtonTapped:) forControlEvents:UIControlEventTouchUpInside];
        
        [self addSubview:_slugLabel];
        [self addSubview:_deleteButton];
    }
    return self;
}

// TODO: For future implementation.  Requires cross-org tag lookup implementation
//-(instancetype)initWithTag:(FLTag *)aTag frame:(CGRect)frame
//{
//    if (self = [super initWithFrame:frame]) {
//        _flTag = aTag;
//        _slug = _flTag.slug;
//        self.backgroundColor = [UIColor clearColor];
//        
//        _fillView = [UIView new];
//        _fillView.layer.cornerRadius = 3.0;
//        [self addSubview:_fillView];
//        [self sendSubviewToBack:_fillView];
//        _slugLabel = [UILabel new];
//
//        _slugLabel.text = _slug;
//        
//        _deleteButton = [UIButton buttonWithType:UIButtonTypeSystem];
//        [_deleteButton setTitle:@"✕" forState:UIControlStateNormal];
//        _deleteButton.tintColor = [ForstaColors mediumRed];
//        [_deleteButton addTarget:self action:@selector(deleteButtonTapped:) forControlEvents:UIControlEventTouchUpInside];
//        
//        [self addSubview:_slugLabel];
//        [self addSubview:_deleteButton];
//    }
//    return self;
//}

-(void)setFrame:(CGRect)frame
{
    [super setFrame:frame];
    self.deleteButton.frame = CGRectMake(self.frame.size.width - self.frame.size.height, 0, self.frame.size.height, self.frame.size.height);
    self.slugLabel.frame = CGRectMake(0, 0, self.frame.size.width - self.frame.size.height, self.frame.size.height);
    self.fillView.frame = CGRectMake(0, 2, self.frame.size.width, self.frame.size.height -4);
    [self.slugLabel sizeToFit];
}

-(void)setBackgroundColor:(UIColor *)backgroundColor
{
    self.fillView.backgroundColor = backgroundColor;
}

-(void)deleteButtonTapped:(id)sender
{
    [self.delegate deleteButtonTappedOnSlugButton:self];
}

@end

