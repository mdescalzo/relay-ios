//
//  FLAnnouncementViewController.m
//  Forsta
//
//  Created by Mark Descalzo on 1/29/18.
//  Copyright © 2018 Forsta. All rights reserved.
//

@import WebKit;

#import "FLAnnouncementViewController.h"
#import "TSThread.h"
#import "TSMessage.h"
#import "TSDatabaseView.h"

@interface FLAnnouncementViewController ()

@property (weak, nonatomic) IBOutlet UILabel *announcementTitleLabel;
//@property (weak, nonatomic) IBOutlet WKWebView *announcementBodyWebView;
@property (weak, nonatomic) IBOutlet UILabel *announcementBodyLabel;

@property (strong, nonatomic) TSMessage *announcementMessage;
@property (strong, nonatomic) NSString *htmlBodyString;
@property (strong, nonatomic) YapDatabaseConnection *dbConnection;

@end

@implementation FLAnnouncementViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
}

-(void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    
    [self configureWithThread];
    
    [self.dbConnection asyncReadWriteWithBlock:^(YapDatabaseReadWriteTransaction * _Nonnull transaction) {
        [self.thread markAllAsReadWithTransaction:transaction];
    }];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

-(void)configureWithThread
{
    dispatch_async(dispatch_get_main_queue(), ^{
        if (self.thread) {
            self.announcementTitleLabel.text = self.thread.displayName;
            self.announcementBodyLabel.attributedText = self.announcementMessage.attributedTextBody;
        }
    });
}

/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/

-(void)setThread:(TSThread *)thread
{
    if (thread.uniqueId.length > 0) {
        _thread = thread;
        [self configureWithThread];
    }
}

-(TSMessage *)announcementMessage
{
        __block TSInteraction *last;
        [self.dbConnection readWithBlock:^(YapDatabaseReadTransaction *transaction){
            last = [[transaction ext:TSMessageDatabaseViewExtensionName] lastObjectInGroup:self.thread.uniqueId];
        }];
        return (TSMessage *)last;

}

-(YapDatabaseConnection *)dbConnection
{
    if (_dbConnection == nil) {
        _dbConnection = [TSStorageManager.sharedManager.database newConnection];
    }
    return _dbConnection;
}

@end
