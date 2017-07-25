//
//  FLMessage.h
//  Forsta
//
//  Created by Mark on 7/24/17.
//  Copyright © 2017 Forsta. All rights reserved.
//

#import "TSMessage.h"

@interface FLMessage : TSMessage

@property (nullable, nonatomic, strong) NSString *plainBody;
@property (nullable, nonatomic, strong) NSAttributedString *attributedBody;
@property (nullable, nonatomic, strong) NSString *body;

@end
