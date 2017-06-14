//
//  FLConversationViewController.h
//  Forsta
//
//  Created by Mark on 6/13/17.
//  Copyright © 2017 Forsta. All rights reserved.
//

#import "SLKTextViewController.h"
#import <AVFoundation/AVFoundation.h>
#import <MediaPlayer/MediaPlayer.h>
#import <JSQMessagesViewController/JSQMessagesViewController.h>
#import "TSGroupModel.h"

@class TSThread;

@interface FLConversationViewController : SLKTextViewController <JSQMessagesCollectionViewDataSource,
                                                                 JSQMessagesCollectionViewDelegateFlowLayout,
                                                                 UITextViewDelegate>

@property (nonatomic, strong) TSThread *selectedThread;

@property (copy, nonatomic) NSString *senderDisplayName;
@property (copy, nonatomic) NSString *senderId;


@end
