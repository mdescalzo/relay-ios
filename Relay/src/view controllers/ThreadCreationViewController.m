//
//  ThreadCreationViewController.m
//  Forsta
//
//  Created by Mark on 9/25/17.
//  Copyright © 2017 Forsta. All rights reserved.
//

#define KMinInputHeight 0.0
#define kMaxInputHeight 84.0

#import "ThreadCreationViewController.h"
#import "FLDirectoryCell.h"
#import "Environment.h"
#import "TSAccountManager.h"
#import "SlugOverLayView.h"
#import "TSStorageManager.h"
#import "TSDatabaseView.h"
#import "TSThread.h"
#import <YapDatabase/YapDatabaseViewChange.h>
#import <YapDatabase/YapDatabaseViewConnection.h>
#import <YapDatabase/YapDatabaseFilteredView.h>
#import <YapDatabase/YapDatabaseFilteredViewTransaction.h>

#define kRecipientSectionIndex 0
#define kTagSectionIndex 1

@interface ThreadCreationViewController () <UISearchBarDelegate, UITableViewDataSource, UITableViewDelegate, UIGestureRecognizerDelegate, SlugOverLayViewDelegate, NSLayoutManagerDelegate>

@property (nonatomic, weak) IBOutlet UISearchBar *searchBar;
@property (nonatomic, weak) IBOutlet UITableView *tableView;
@property (nonatomic, weak) IBOutlet UITextView *slugContainerView;
@property (nonatomic, weak) IBOutlet UIBarButtonItem *exitButton;
@property (nonatomic, weak) IBOutlet UIBarButtonItem *goButton;
@property (nonatomic, weak) IBOutlet NSLayoutConstraint *slugViewHeight;
@property (weak, nonatomic) IBOutlet UIView *searchInfoContainer;
@property (weak, nonatomic) IBOutlet UILabel *searchInfoLabel;

@property (nonatomic, strong) UISwipeGestureRecognizer *downSwipeRecognizer;

@property (nonatomic, strong) NSMutableArray<NSString *> *validatedSlugs;
@property (nonatomic, strong) NSMutableArray<UIView *> *slugViews;
//@property (nonatomic, strong) NSMutableArray<FLTag *> *selectedTags;

@property (nonatomic, strong) UIRefreshControl *refreshControl;

@property (nonatomic, strong) YapDatabaseViewMappings *tagMappings;

@property (nonatomic, strong) YapDatabaseConnection *uiDbConnection;
@property (nonatomic, strong) YapDatabaseConnection *searchDbConnection;

@end

@implementation ThreadCreationViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    //    [self downSwipeRecognizer];
    self.slugViewHeight.constant = KMinInputHeight;
    //    self.slugContainerView.layoutManager.delegate = self;
    self.slugContainerView.textContainerInset = UIEdgeInsetsMake(8, 0, 8, KMinInputHeight);
    self.goButton.tintColor = [ForstaColors mediumLightGreen];
    
    self.searchBar.placeholder = NSLocalizedString(@"SEARCH_BYNAMEORNUMBER_PLACEHOLDER_TEXT", nil);
    
    self.searchInfoLabel.text = NSLocalizedString(@"SEARCH_HELP_STRING", @"Informational string for tag lookups.");
    
    self.view.backgroundColor = [ForstaColors whiteColor];
    
    // Refresh control handling
    UIView *refreshView = [UIView new];  //[[UIView alloc] initWithFrame:CGRectMake(0.0f, 8.0f, 0.0f, 0.0f)];
    [self.tableView insertSubview:refreshView atIndex:0];
    self.refreshControl = [UIRefreshControl new];
    //    self.refreshControl.attributedTitle = [[NSAttributedString alloc] initWithString:NSLocalizedString(@"REFRESHING", nil)];
    [self.refreshControl addTarget:self
                            action:@selector(refreshContentFromSource)
                  forControlEvents:UIControlEventValueChanged];
    [refreshView addSubview:self.refreshControl];
    
    self.uiDbConnection = [TSStorageManager.sharedManager.database newConnection];
    self.searchDbConnection = [TSStorageManager.sharedManager.database newConnection];
    [self.uiDbConnection beginLongLivedReadTransaction];
    
    // Notifications
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(refreshTableView)
                                                 name:FLCCSMTagsUpdated
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(refreshTableView)
                                                 name:FLCCSMUsersUpdated
                                               object:nil];
    // TODO: name:TSUIDatabaseConnectionDidUpdateNotification is incorrect.  Fixing it reveal much larger bug in the yapDatabaseModified: method.
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(yapDatabaseModified:)
                                                 name:TSUIDatabaseConnectionDidUpdateNotification
                                               object:nil];
    [self updateGoButton];
    [self updateMappings];
}

-(void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (nonnull UITableViewCell *)tableView:(nonnull UITableView *)tableView cellForRowAtIndexPath:(nonnull NSIndexPath *)indexPath {
    FLDirectoryCell *cell = (FLDirectoryCell *)[tableView dequeueReusableCellWithIdentifier:@"slugCell" forIndexPath:indexPath];
    
    switch (indexPath.section) {
        case kRecipientSectionIndex:
        {
            SignalRecipient *recipient = (SignalRecipient *) [self objectForIndexPath:indexPath];
            
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{
                [cell configureCellWithContact:recipient];
            });
            
            if ([self.validatedSlugs containsObject:recipient.flTag.displaySlug]) {
                cell.accessoryType = UITableViewCellAccessoryCheckmark;
            } else {
                cell.accessoryType = UITableViewCellAccessoryNone;
            }
        }
            break;
        case kTagSectionIndex:
        {
            FLTag *aTag = (FLTag *)[self objectForIndexPath:indexPath];
            
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{
                [cell configureCellWithTag:aTag];
            });
            
            if ([self.validatedSlugs containsObject:aTag.displaySlug]) {
                cell.accessoryType = UITableViewCellAccessoryCheckmark;
            } else {
                cell.accessoryType = UITableViewCellAccessoryNone;
            }
        }
            break;
        default:
            break;
    }

    
    return cell;
}

-(void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    NSString *tagSlug = nil;
    
    switch (indexPath.section) {
        case kRecipientSectionIndex:
        {
            SignalRecipient *recipient = (SignalRecipient *)[self objectForIndexPath:indexPath];
            tagSlug = recipient.flTag.displaySlug;
        }
            break;
        case kTagSectionIndex:
        {
            FLTag *aTag = (FLTag *)[self objectForIndexPath:indexPath];
            tagSlug = aTag.displaySlug;
        }
            break;
        default:
            break;
    }
    
    if ([self.validatedSlugs containsObject:tagSlug]) {
        [self removeSlug:tagSlug];
    } else {
        [self addSlug:tagSlug];
    }
    self.searchBar.text = @"";
    [self refreshTableView];
}

-(CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    return 60.0f;
}

-(NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return (NSInteger)[self.tagMappings numberOfSections];
    
}

- (NSInteger)tableView:(nonnull UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return (NSInteger)[self.tagMappings numberOfItemsInSection:(NSUInteger)section];
}

-(void)refreshContentFromSource
{
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.refreshControl beginRefreshing];
        [Environment.getCurrent.contactsManager refreshCCSMRecipients];
        [self refreshTableView];
        [self.refreshControl endRefreshing];
    });
}

-(void)refreshTableView
{
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.uiDbConnection beginLongLivedReadTransaction];
        [self.uiDbConnection readWithBlock:^(YapDatabaseReadTransaction *transaction) {
            [self.tagMappings updateWithTransaction:transaction];
            
            if ([self.tagMappings numberOfItemsInAllGroups] == 0) {
                self.searchInfoContainer.hidden = NO;
                self.tableView.hidden = YES;
            } else {
                self.searchInfoContainer.hidden = YES;
                self.tableView.hidden = NO;
            }
            [self.tableView reloadData];
        }];
        [self.uiDbConnection endLongLivedReadTransaction];
    });
}

//- (void)encodeWithCoder:(nonnull NSCoder *)aCoder {
//    <#code#>
//}
//
//- (void)traitCollectionDidChange:(nullable UITraitCollection *)previousTraitCollection {
//    <#code#>
//}
//
//- (void)preferredContentSizeDidChangeForChildContentContainer:(nonnull id<UIContentContainer>)container {
//    <#code#>
//}
//
//- (CGSize)sizeForChildContentContainer:(nonnull id<UIContentContainer>)container withParentContainerSize:(CGSize)parentSize {
//    <#code#>
//}
//
//- (void)systemLayoutFittingSizeDidChangeForChildContentContainer:(nonnull id<UIContentContainer>)container {
//    <#code#>
//}
//
//- (void)viewWillTransitionToSize:(CGSize)size withTransitionCoordinator:(nonnull id<UIViewControllerTransitionCoordinator>)coordinator {
//    <#code#>
//}
//
//- (void)willTransitionToTraitCollection:(nonnull UITraitCollection *)newCollection withTransitionCoordinator:(nonnull id<UIViewControllerTransitionCoordinator>)coordinator {
//    <#code#>
//}
//
//- (void)didUpdateFocusInContext:(nonnull UIFocusUpdateContext *)context withAnimationCoordinator:(nonnull UIFocusAnimationCoordinator *)coordinator {
//    <#code#>
//}
//
//- (void)setNeedsFocusUpdate {
//    <#code#>
//}
//
//- (BOOL)shouldUpdateFocusInContext:(nonnull UIFocusUpdateContext *)context {
//    <#code#>
//}
//
//- (void)updateFocusIfNeeded {
//    <#code#>
//}

/*
 #pragma mark - Navigation
 
 // In a storyboard-based application, you will often want to do a little preparation before navigation
 - (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
 // Get the new view controller using [segue destinationViewController].
 // Pass the selected object to the new view controller.
 }
 */

#pragma mark - Database updates
- (void)yapDatabaseModified:(NSNotification *)notification {
    NSArray *notifications  = [self.uiDbConnection beginLongLivedReadTransaction];
    NSArray *sectionChanges = nil;
    NSArray *rowChanges     = nil;
    
    [[self.uiDbConnection ext:FLFilteredTagDatabaseViewExtensionName] getSectionChanges:&sectionChanges
                                                                             rowChanges:&rowChanges
                                                                       forNotifications:notifications
                                                                           withMappings:self.tagMappings];
    
    if ([sectionChanges count] == 0 && [rowChanges count] == 0) {
        return;
    }
    
    [self.tableView beginUpdates];
    
    for (YapDatabaseViewSectionChange *sectionChange in sectionChanges) {
        switch (sectionChange.type) {
            case YapDatabaseViewChangeDelete: {
                [self.tableView deleteSections:[NSIndexSet indexSetWithIndex:sectionChange.index]
                              withRowAnimation:UITableViewRowAnimationAutomatic];
                break;
            }
            case YapDatabaseViewChangeInsert: {
                [self.tableView insertSections:[NSIndexSet indexSetWithIndex:sectionChange.index]
                              withRowAnimation:UITableViewRowAnimationAutomatic];
                break;
            }
            case YapDatabaseViewChangeUpdate:
            case YapDatabaseViewChangeMove:
                break;
        }
    }
    
    for (YapDatabaseViewRowChange *rowChange in rowChanges) {
        switch (rowChange.type) {
            case YapDatabaseViewChangeDelete: {
                [self.tableView deleteRowsAtIndexPaths:@[ rowChange.indexPath ]
                                      withRowAnimation:UITableViewRowAnimationAutomatic];
            }
                break;
            case YapDatabaseViewChangeInsert: {
                [self.tableView insertRowsAtIndexPaths:@[ rowChange.newIndexPath ]
                                      withRowAnimation:UITableViewRowAnimationAutomatic];
            }
                break;
            case YapDatabaseViewChangeMove: {
                [self.tableView deleteRowsAtIndexPaths:@[ rowChange.indexPath ]
                                      withRowAnimation:UITableViewRowAnimationAutomatic];
                [self.tableView insertRowsAtIndexPaths:@[ rowChange.newIndexPath ]
                                      withRowAnimation:UITableViewRowAnimationAutomatic];
            }
                break;
                
            case YapDatabaseViewChangeUpdate: {
                [self.tableView reloadRowsAtIndexPaths:@[ rowChange.indexPath ]
                                      withRowAnimation:UITableViewRowAnimationNone];
            }
                break;
            default:
                break;
        }
    }
    
    [self.tableView endUpdates];
    [self.uiDbConnection endLongLivedReadTransaction];
}

#pragma mark - SearchBar delegate methods
-(void)searchBar:(UISearchBar *)searchBar textDidChange:(NSString *)searchText
{
    [self updateMappings];
    [self refreshTableView];
}

-(void)searchBarSearchButtonClicked:(UISearchBar *)searchBar
{
    if (searchBar.text.length > 0) {
        // process the string before sending to tagMath
        NSString *originalString = [searchBar.text copy];
        __block NSMutableString *searchText = [NSMutableString new];
        
        for (NSString *subString in [originalString componentsSeparatedByCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]]) {
            if (subString.length > 0 && ![subString isEqualToString:@"@"]) {
                if ([[subString substringToIndex:1] isEqualToString:@"@"]) {
                    [searchText appendString:[NSString stringWithFormat:@"%@ ", subString]];
                } else {
                    [searchText appendString:[NSString stringWithFormat:@"@%@ ", subString]];
                }
            }
        }
        
        // Do the lookup
        [CCSMCommManager asyncTagLookupWithString:searchText
                                          success:^(NSDictionary *results) {
                                              DDLogDebug(@"%@", results);
                                              NSString *pretty = [results objectForKey:@"pretty"];
                                              NSArray *warnings = [results objectForKey:@"warnings"];
                                              
                                              __block NSMutableArray *badStrings = [NSMutableArray new];
                                              if (warnings.count > 0) {
                                                  for (NSDictionary *warning in warnings) {
                                                      NSRange range = NSMakeRange((NSUInteger)[[warning objectForKey:@"position"] intValue]+1,
                                                                                  (NSUInteger)[[warning objectForKey:@"length"] intValue]-1);
                                                      NSString *badString = [searchText substringWithRange:range];
                                                      [badStrings addObject:badString];
                                                  }
                                                  NSMutableString *badStuff = [NSMutableString new];
                                                  for (NSString *string in badStrings) {
                                                      [badStuff appendFormat:@"%@\n", string];
                                                  }
                                                  NSString *message = [NSString stringWithFormat:@"%@\n%@", NSLocalizedString(@"Tag not found for:", @"Alert message for no results from taglookup"), badStuff];
                                                  dispatch_async(dispatch_get_main_queue(), ^{
                                                      UIAlertController *alert = [UIAlertController alertControllerWithTitle:nil
                                                                                                                     message:message
                                                                                                              preferredStyle:UIAlertControllerStyleActionSheet];
                                                      UIAlertAction *okButton = [UIAlertAction actionWithTitle:NSLocalizedString(@"OK",)
                                                                                                         style:UIAlertActionStyleDefault
                                                                                                       handler:^(UIAlertAction *action) { /* do nothing */}];
                                                      [alert addAction:okButton];
                                                      [self.navigationController presentViewController:alert animated:YES completion:nil];
                                                  });
                                              }
                                              if (pretty.length > 0) {
                                                  NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:@"@[a-zA-Z0-9-.:]+(\\b|$)"
                                                                                                                         options:(NSRegularExpressionCaseInsensitive | NSRegularExpressionAnchorsMatchLines)
                                                                                                                           error:nil];
                                                  NSArray *matches = [regex matchesInString:pretty options:0 range:NSMakeRange(0, pretty.length)];
                                                  for (NSTextCheckingResult *result in matches) {
                                                      NSString *newSlug = [pretty substringWithRange:result.range];
                                                      [self addSlug:newSlug];
                                                  }
                                              }
                                              
                                              // Update the searchbar with remainder text
                                              NSMutableString *badStuff = [NSMutableString new];
                                              for (NSString *string in badStrings) {
                                                  [badStuff appendFormat:@"%@ ", string];
                                              }
                                              dispatch_async(dispatch_get_main_queue(), ^{
                                                  self.searchBar.text = [NSString stringWithString:badStuff];
                                                  [self updateMappings];
                                              });
                                              
                                              // take this opportunity to store any userids
                                              NSArray *userids = [results objectForKey:@"userids"];
                                              if (userids.count > 0) {
                                                  [self.searchDbConnection asyncReadWriteWithBlock:^(YapDatabaseReadWriteTransaction * _Nonnull transaction) {
                                                      for (NSString *uid in userids) {
                                                          [Environment.getCurrent.contactsManager recipientWithUserID:uid transaction:transaction];
                                                      }
                                                  } completionBlock:^{
                                                      [self refreshTableView];
                                                  }];
                                              }
                                          }
                                          failure:^(NSError *error) {
                                              DDLogDebug(@"Tag Lookup failed with error: %@", error.description);
                                              dispatch_async(dispatch_get_main_queue(), ^{
                                                  
                                                  UIAlertController *alert = [UIAlertController alertControllerWithTitle:nil
                                                                                                                 message:NSLocalizedString(@"ERROR_DESCRIPTION_SERVER_FAILURE", nil)
                                                                                                          preferredStyle:UIAlertControllerStyleActionSheet];
                                                  UIAlertAction *okAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"OK", nil)
                                                                                                     style:UIAlertActionStyleDefault
                                                                                                   handler:^(UIAlertAction *action) {}];
                                                  [alert addAction:okAction];
                                                  [self.navigationController presentViewController:alert animated:YES completion:nil];
                                              });
                                          }];
    }
}

-(void)textViewDidChange:(UITextView *)textView
{
    //  Handle dynamic size
    CGRect boundingRect = [textView.text boundingRectWithSize:CGSizeMake(350, CGFLOAT_MAX)
                                                      options:(NSStringDrawingUsesLineFragmentOrigin|NSStringDrawingUsesFontLeading)
                                                   attributes:@{ NSFontAttributeName: textView.font }
                                                      context:nil];
    __block CGSize boundingSize = boundingRect.size;
    
    CGFloat newHeight = KMinInputHeight;
    if (boundingSize.height < KMinInputHeight) {
        newHeight = KMinInputHeight;
    } else if (boundingSize.height > kMaxInputHeight) {
        newHeight = kMaxInputHeight;
    } else {
        newHeight = boundingSize.height;
    }
    
    [UIView animateWithDuration:0.25 animations:^{
        self.slugViewHeight.constant = newHeight;
    }];
}

#pragma mark - UI actions
-(IBAction)didPressGoButton:(id)sender
{
    if (self.validatedSlugs.count > 0) {
        NSMutableString *threadSlugs =[NSMutableString new];
        for (NSString *slug in self.validatedSlugs) {
            if (threadSlugs.length == 0) {
                [threadSlugs appendString:slug];
            } else {
                [threadSlugs appendFormat:@" + %@", slug];
            }
        }
        [CCSMCommManager asyncTagLookupWithString:threadSlugs
                                          success:^(NSDictionary *results) {
                                              [self buildThreadWithResults:results];
                                              //                                         [self storeUsersInResults:results];
                                          }
                                          failure:^(NSError *error) {
                                              DDLogDebug(@"Tag Lookup failed with error: %@", error.description);
                                              dispatch_async(dispatch_get_main_queue(), ^{
                                                  
                                                  UIAlertController *alert = [UIAlertController alertControllerWithTitle:nil
                                                                                                                 message:NSLocalizedString(@"ERROR_DESCRIPTION_SERVER_FAILURE", nil)
                                                                                                          preferredStyle:UIAlertControllerStyleActionSheet];
                                                  UIAlertAction *okAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"OK", nil)
                                                                                                     style:UIAlertActionStyleDefault
                                                                                                   handler:^(UIAlertAction *action) {}];
                                                  [alert addAction:okAction];
                                                  [self.navigationController presentViewController:alert animated:YES completion:nil];
                                              });
                                          }];
    }
}

-(IBAction)didPressExitButton:(id)sender
{
    if ([self.searchBar isFirstResponder]) {
        [self.searchBar resignFirstResponder];
    }
    [self.navigationController dismissViewControllerAnimated:YES completion:^{ }];
}

-(void)didSwipeDown:(id)sender
{
    if ([self.searchBar isFirstResponder]) {
        [self.searchBar resignFirstResponder];
    }
}

#pragma mark - worker methods
- (id)objectForIndexPath:(NSIndexPath *)indexPath {
    __block id object = nil;
    [self.uiDbConnection readWithBlock:^(YapDatabaseReadTransaction *transaction) {
        object = [[transaction extension:FLFilteredTagDatabaseViewExtensionName] objectAtIndexPath:indexPath
                                                                                    withMappings:self.tagMappings];
    }];
    return object;
}

-(void)updateMappings
{
    __block NSString *filterString = [self.searchBar.text lowercaseString];
    __block YapDatabaseViewFiltering *filtering = [YapDatabaseViewFiltering withObjectBlock:^BOOL(YapDatabaseReadTransaction * _Nonnull transaction,
                                                                                                  NSString * _Nonnull group,
                                                                                                  NSString * _Nonnull collection,
                                                                                                  NSString * _Nonnull key,
                                                                                                  id  _Nonnull object) {
        FLTag *aTag = (FLTag *)object;
        if (filterString.length > 0) {
            return ([[aTag.displaySlug lowercaseString] containsString:filterString] ||
                    [[aTag.slug lowercaseString] containsString:filterString] ||
                    [[aTag.tagDescription lowercaseString] containsString:filterString] ||
                    [[aTag.orgSlug lowercaseString] containsString:filterString]);
        } else {
            return YES;
        }
    }];
    
    [self.searchDbConnection readWriteWithBlock:^(YapDatabaseReadWriteTransaction *transaction) {
        
        [[transaction ext:FLFilteredTagDatabaseViewExtensionName] setFiltering:filtering
                                                                    versionTag:filterString];
        
    }];
    
    
    [self.uiDbConnection beginLongLivedReadTransaction];
    [self.uiDbConnection readWithBlock:^(YapDatabaseReadTransaction *transaction) {
        [self.tagMappings updateWithTransaction:transaction];
    }];
    [self.uiDbConnection endLongLivedReadTransaction];
}

-(void)updateGoButton
{
    if (self.validatedSlugs.count == 0) {
        self.goButton.enabled = NO;
    } else {
        self.goButton.enabled = YES;
    }
}

// Lookup and refresh/store discovered users
-(void)storeUsersInResults:(NSDictionary *)results
{
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{
        [self.searchDbConnection asyncReadWriteWithBlock:^(YapDatabaseReadWriteTransaction * _Nonnull transaction) {
            NSArray *userIds = [[results objectForKey:@"userids"] copy];
            for (NSString *uid in userIds) {
                // do the lookup things
                [CCSMCommManager recipientFromCCSMWithID:uid transaction:transaction];
            }
        }];
    });
}

-(void)buildThreadWithResults:(NSDictionary *)results
{
    // Check to see if myself is included
    NSArray *userIds = [[results objectForKey:@"userids"] copy];
    if (![userIds containsObject:TSAccountManager.sharedInstance.myself.uniqueId]) {
        // add self run again
        NSMutableString *pretty = [[results objectForKey:@"pretty"] mutableCopy];
        [pretty appendFormat:@" + @%@", TSAccountManager.sharedInstance.myself.flTag.slug];
        [CCSMCommManager asyncTagLookupWithString:pretty
                                          success:^(NSDictionary *newResults){
                                              [self buildThreadWithResults:newResults];
                                          }
                                          failure:^(NSError *error) {
                                              DDLogDebug(@"Tag Lookup failed with error: %@", error.description);
                                              dispatch_async(dispatch_get_main_queue(), ^{
                                                  
                                                  UIAlertController *alert = [UIAlertController alertControllerWithTitle:nil
                                                                                                                 message:NSLocalizedString(@"ERROR_DESCRIPTION_SERVER_FAILURE", nil)
                                                                                                          preferredStyle:UIAlertControllerStyleActionSheet];
                                                  UIAlertAction *okAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"OK", nil)
                                                                                                     style:UIAlertActionStyleDefault
                                                                                                   handler:^(UIAlertAction *action) {}];
                                                  [alert addAction:okAction];
                                                  [self.navigationController presentViewController:alert animated:YES completion:nil];
                                              });
                                          }];
    } else {
        // build thread and go
        [self.navigationController dismissViewControllerAnimated:YES
                                                      completion:^() {
                                                          __block TSThread *thread = nil;
                                                          [[TSStorageManager.sharedManager newDatabaseConnection] readWriteWithBlock:^(YapDatabaseReadWriteTransaction *transaction) {
                                                              thread = [TSThread getOrCreateThreadWithParticipants:userIds transaction:transaction];
                                                              thread.type = @"conversation";
                                                              thread.prettyExpression = [[results objectForKey:@"pretty"] copy];
                                                              thread.universalExpression = [[results objectForKey:@"universal"] copy];
                                                              [thread saveWithTransaction:transaction];
                                                          }];
                                                          [Environment messageGroup:thread];
                                                      }];
    }
}

-(void)addSlug:(NSString *)slug
{
    if (![[slug substringToIndex:1] isEqualToString:@"@"]) {
        slug = [NSString stringWithFormat:@"@%@", slug];
    }
    
    dispatch_async(dispatch_get_main_queue(), ^{
        CGRect hiddenFrame = CGRectMake(self.slugContainerView.frame.size.width/2,
                                        self.slugContainerView.frame.size.height*2,
                                        0, 0);
        SlugOverLayView *aView = [[SlugOverLayView alloc] initWithSlug:slug frame:hiddenFrame];
        aView.delegate = self;
        aView.backgroundColor = [ForstaColors lightGreen];
        [self.slugContainerView addSubview:aView];
        [self.slugContainerView bringSubviewToFront:aView];
        [self.slugViews addObject:aView];
        [self.validatedSlugs addObject:slug];
        [self refreshTableView];
        [self refreshSlugView];
        [self updateGoButton];
        [self.slugContainerView scrollRangeToVisible:NSMakeRange(self.slugContainerView.text.length-1, 1)];
    });
}

// TODO: For future implementation.  Requires cross-org tag lookup implementation
//-(void)addTagToSelection:(FLTag *)aTag
//{
//    [self.selectedTags addObject:aTag];
//
//    NSString *tagSlug = aTag.slug;
//    if (![[tagSlug substringToIndex:1] isEqualToString:@"@"]) {
//        tagSlug = [NSString stringWithFormat:@"@%@", tagSlug];
//    }
//
//    CGRect hiddenFrame = CGRectMake(self.slugContainerView.frame.size.width/2,
//                                    self.slugContainerView.frame.size.height*2,
//                                    0, 0);
//    SlugOverLayView *aView = [[SlugOverLayView alloc] initWithSlug:tagSlug frame:hiddenFrame];
//    aView.delegate = self;
//    [self.slugViews addObject:aView];
//
//    dispatch_async(dispatch_get_main_queue(), ^{
//        aView.backgroundColor = [ForstaColors lightGreen];
//        [self.slugContainerView addSubview:aView];
//        [self.slugContainerView bringSubviewToFront:aView];
//        [self refreshTableView];
//        [self refreshSlugView];
//        [self updateGoButton];
//        [self.slugContainerView scrollRangeToVisible:NSMakeRange(self.slugContainerView.text.length-1, 1)];
//    });
//}

-(void)removeSlug:(NSString *)slug
{
    if (![[slug substringToIndex:1] isEqualToString:@"@"]) {
        slug = [NSString stringWithFormat:@"@%@", slug];
    }
    dispatch_async(dispatch_get_main_queue(), ^{
        NSUInteger index = [self.validatedSlugs indexOfObject:slug];
        [self.validatedSlugs removeObjectAtIndex:index];
        UIView *aView = [self.slugViews objectAtIndex:index];
        [aView removeFromSuperview];
        [self.slugViews removeObjectAtIndex:index];
        [self refreshTableView];
        [self refreshSlugView];
        [self updateGoButton];
    });
}

// TODO: For future implementation.  Requires cross-org tag lookup implementation
//-(void)removeTagFromSelection:(FLTag *)aTag
//{
//    NSUInteger index = [self.selectedTags indexOfObject:aTag];
//    [self.selectedTags removeObjectAtIndex:index];
//    UIView *aView = [self.slugViews objectAtIndex:index];
//    [self.slugViews removeObjectAtIndex:index];
//
//    NSString *tagSlug = aTag.slug;
//    if (![[tagSlug substringToIndex:1] isEqualToString:@"@"]) {
//        tagSlug = [NSString stringWithFormat:@"@%@", tagSlug];
//    }
//    dispatch_async(dispatch_get_main_queue(), ^{
//        [aView removeFromSuperview];
//        [self refreshTableView];
//        [self refreshSlugView];
//        [self updateGoButton];
//    });
//}

-(void)refreshSlugView
{
    
    NSMutableString *tmpString = [NSMutableString new];
    for (NSString *slug in self.validatedSlugs) {
        if (tmpString.length == 0) {
            [tmpString appendString:slug];
        } else {
            [tmpString appendString:[NSString stringWithFormat:@"      %@", slug]];
        }
    }
    
    //  Handle dynamic size
    CGRect boundingRect = [tmpString boundingRectWithSize:CGSizeMake(350, CGFLOAT_MAX)
                                                  options:(NSStringDrawingUsesLineFragmentOrigin|NSStringDrawingUsesFontLeading)
                                               attributes:@{ NSFontAttributeName: self.slugContainerView.font }
                                                  context:nil];
    CGSize boundingSize = boundingRect.size;
    CGFloat newHeight = KMinInputHeight;
    if (boundingSize.height < KMinInputHeight) {
        newHeight = KMinInputHeight;
    } else if (boundingSize.height > kMaxInputHeight) {
        newHeight = kMaxInputHeight;
    } else {
        newHeight = boundingSize.height;
    }
    
    if (self.validatedSlugs.count > 0) {
        newHeight += 20.0;
    } else {
        newHeight = 0.0;
    }
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [UIView animateWithDuration:0.25 animations:^{
            self.slugViewHeight.constant = newHeight;
            self.slugContainerView.text = [NSString stringWithString:tmpString];
            
            for (UIView *aView in self.slugViews) {
                aView.frame = [self frameForSlug:[self.validatedSlugs objectAtIndex:[self.slugViews indexOfObject:aView]]];
            }
        }];
    });
}

-(CGRect)frameForSlug:(NSString *)slug
{
    // Use regex to avoid UI problems from slugs which are substrings of other slugs
    NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:[NSString stringWithFormat:@"%@(\\b|$)", slug]
                                                                           options:(NSRegularExpressionCaseInsensitive | NSRegularExpressionAnchorsMatchLines)
                                                                             error:nil];
    NSArray *matches = [regex matchesInString:self.slugContainerView.text options:0 range:NSMakeRange(0, self.slugContainerView.text.length)];
    NSRange range = ((NSTextCheckingResult *)[matches lastObject]).range;
    
    CGRect aFrame = [self frameOfTextRange:range inTextView:self.slugContainerView];
    CGFloat heightMod = 1.5;
    return CGRectMake(aFrame.origin.x, aFrame.origin.y + heightMod, aFrame.size.width + aFrame.size.height - (2*heightMod), aFrame.size.height);
    
}

// Source https://stackoverflow.com/questions/10313689/how-to-find-position-or-get-rect-of-any-word-in-textview-and-place-buttons-over
- (CGRect)frameOfTextRange:(NSRange)range inTextView:(UITextView *)textView
{
    UITextPosition *beginning = textView.beginningOfDocument;
    UITextPosition *start = [textView positionFromPosition:beginning offset:(NSInteger)range.location];
    UITextPosition *end = [textView positionFromPosition:start offset:(NSInteger)range.length];
    UITextRange *textRange = [textView textRangeFromPosition:start toPosition:end];
    CGRect rect = [textView firstRectForRange:textRange];
    return [textView convertRect:rect fromView:textView.textInputView];
}

#pragma mark - SlugOverlay delegate method
-(void)deleteButtonTappedOnSlugButton:(id)sender
{
    if ([sender isKindOfClass:[SlugOverLayView class]]) {
        SlugOverLayView *view = (SlugOverLayView *)sender;
        [self removeSlug:view.slug];
    }
}

#pragma mark - Accessors
-(YapDatabaseViewMappings *)tagMappings
{
    if (_tagMappings == nil) {
        _tagMappings = [[YapDatabaseViewMappings alloc] initWithGroups:@[ FLVisibleRecipientGroup, FLActiveTagsGroup ]
                                                                  view:FLFilteredTagDatabaseViewExtensionName];
        [_tagMappings setIsReversed:NO forGroup:FLActiveTagsGroup];
        [self.uiDbConnection asyncReadWithBlock:^(YapDatabaseReadTransaction * _Nonnull transaction) {
            [_tagMappings updateWithTransaction:transaction];
            dispatch_async(dispatch_get_main_queue(), ^{
                [self.tableView reloadData];
            });
        }];
    }
    return _tagMappings;
}

-(NSMutableArray *)validatedSlugs
{
    if (_validatedSlugs == nil) {
        _validatedSlugs = [NSMutableArray new];
    }
    return _validatedSlugs;
}

// TODO: For future implementation.  Requires cross-org tag lookup implementation
//-(NSMutableArray *)selectedTags
//{
//    if (_selectedTags == nil) {
//        _selectedTags = [NSMutableArray new];
//    }
//    return _selectedTags;
//}

-(NSMutableArray *)slugViews
{
    if (_slugViews == nil) {
        _slugViews = [NSMutableArray new];
    }
    return _slugViews;
}

-(UISwipeGestureRecognizer *)downSwipeRecognizer
{
    if (_downSwipeRecognizer == nil) {
        _downSwipeRecognizer = [[UISwipeGestureRecognizer alloc] initWithTarget:self action:@selector(didSwipeDown:)];
        _downSwipeRecognizer.direction = UISwipeGestureRecognizerDirectionRight;
        [self.tableView addGestureRecognizer:_downSwipeRecognizer];
    }
    return _downSwipeRecognizer;
}

@end
