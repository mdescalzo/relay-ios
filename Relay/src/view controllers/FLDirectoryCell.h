//
//  FLDirectoryCell.h
//  Forsta
//
//  Created by Mark on 7/31/17.
//  Copyright © 2017 Forsta. All rights reserved.
//

#import "SignalRecipient.h"
#import "FLTag.h"

#import <UIKit/UIKit.h>

@interface FLDirectoryCell : UITableViewCell

@property (nonatomic, weak) IBOutlet UILabel *nameLabel;
@property (nonatomic, weak) IBOutlet UILabel *detailLabel;
@property (nonatomic, weak) IBOutlet UIImageView *avatarImageView;

-(void)configureCellWithContact:(SignalRecipient *)recipient;
-(void)configureCellWithTag:(FLTag *)aTag;

@end
