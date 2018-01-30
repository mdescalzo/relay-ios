//
//  AnnouncementDetailViewController.h
//  Forsta
//
//  Created by Mark Descalzo on 1/30/18.
//  Copyright © 2018 Forsta. All rights reserved.
//

@import UIKit;

@class TSIncomingMessage;

@interface AnnouncementDetailViewController : UITableViewController

@property (nonatomic, strong) TSIncomingMessage *message;

@end
