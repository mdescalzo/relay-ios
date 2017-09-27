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

-(id)initWithSlug:(NSString *)slug frame:(CGRect)frame
{
    if (self = [super initWithFrame:frame]) {
        _slug = [slug copy];
        self.backgroundColor = [UIColor clearColor];
        
        _fillView = [UIView new];
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
        
//        NSLayoutConstraint *slugHeightConstraint = [NSLayoutConstraint constraintWithItem:_slugLabel
//                                                                                attribute:NSLayoutAttributeHeight
//                                                                                relatedBy:NSLayoutRelationEqual
//                                                                                   toItem:self
//                                                                                attribute:NSLayoutAttributeHeight
//                                                                               multiplier:1
//                                                                                 constant:0];
//        NSLayoutConstraint *topSlugConstraint = [NSLayoutConstraint constraintWithItem:_slugLabel
//                                                                             attribute:NSLayoutAttributeTop
//                                                                             relatedBy:NSLayoutRelationEqual
//                                                                                toItem:self
//                                                                             attribute:NSLayoutAttributeTop
//                                                                            multiplier:1
//                                                                              constant:0];
//        NSLayoutConstraint *bottomSlugConstraint = [NSLayoutConstraint constraintWithItem:_slugLabel
//                                                                                attribute:NSLayoutAttributeBottom
//                                                                                relatedBy:NSLayoutRelationEqual
//                                                                                   toItem:self
//                                                                                attribute:NSLayoutAttributeBottom
//                                                                               multiplier:1
//                                                                                 constant:0];
//        NSLayoutConstraint *leadingSlugConstraint = [NSLayoutConstraint constraintWithItem:_slugLabel
//                                                                                 attribute:NSLayoutAttributeLeft
//                                                                                 relatedBy:NSLayoutRelationEqual
//                                                                                    toItem:self
//                                                                                 attribute:NSLayoutAttributeLeft
//                                                                                multiplier:1
//                                                                                  constant:0];
//        NSLayoutConstraint *trailSlugConstraint = [NSLayoutConstraint constraintWithItem:_slugLabel
//                                                                               attribute:NSLayoutAttributeRight
//                                                                               relatedBy:NSLayoutRelationEqual
//                                                                                  toItem:_deleteButton
//                                                                               attribute:NSLayoutAttributeRight
//                                                                              multiplier:1
//                                                                                constant:0];
//        NSLayoutConstraint *topDeleteConstraint = [NSLayoutConstraint constraintWithItem:_deleteButton
//                                                                               attribute:NSLayoutAttributeTop
//                                                                               relatedBy:NSLayoutRelationEqual
//                                                                                  toItem:self
//                                                                               attribute:NSLayoutAttributeTop
//                                                                              multiplier:1
//                                                                                constant:0];
//        NSLayoutConstraint *bottomDeleteConstraint = [NSLayoutConstraint constraintWithItem:_deleteButton
//                                                                                  attribute:NSLayoutAttributeBottom
//                                                                                  relatedBy:NSLayoutRelationEqual
//                                                                                     toItem:self
//                                                                                  attribute:NSLayoutAttributeBottom
//                                                                                 multiplier:1
//                                                                                   constant:0];
//        NSLayoutConstraint *trailDeleteConstraint = [NSLayoutConstraint constraintWithItem:_deleteButton
//                                                                                 attribute:NSLayoutAttributeRight
//                                                                                 relatedBy:NSLayoutRelationEqual
//                                                                                    toItem:self
//                                                                                 attribute:NSLayoutAttributeRight
//                                                                                multiplier:1
//                                                                                  constant:0];
//        NSLayoutConstraint *ratioDeleteConstraint = [NSLayoutConstraint constraintWithItem:_deleteButton
//                                                                                 attribute:NSLayoutAttributeWidth
//                                                                                 relatedBy:NSLayoutRelationEqual
//                                                                                    toItem:_deleteButton
//                                                                                 attribute:NSLayoutAttributeHeight
//                                                                                multiplier:1
//                                                                                  constant:0];
//        [self addConstraints:@[ slugHeightConstraint, topSlugConstraint, bottomSlugConstraint, leadingSlugConstraint, trailSlugConstraint, topDeleteConstraint, bottomDeleteConstraint, trailDeleteConstraint,ratioDeleteConstraint ]];
        
    }
    return self;
}

-(void)setFrame:(CGRect)frame
{
    [super setFrame:frame];
//    self.deleteButton.frame = CGRectMake(0, 0, self.frame.size.height, self.frame.size.height);
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

