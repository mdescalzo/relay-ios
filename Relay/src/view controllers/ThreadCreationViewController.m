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
#import "TSStorageManager.h"
#import "TSDatabaseView.h"
#import "TSThread.h"
#import <YapDatabase/YapDatabaseViewChange.h>
#import <YapDatabase/YapDatabaseViewConnection.h>
#import <YapDatabase/YapDatabaseFilteredView.h>
#import <YapDatabase/YapDatabaseFilteredViewTransaction.h>
#import "OWSDispatch.h"

#define kRecipientSectionIndex 0
#define kTagSectionIndex 1

#define kHiddenSectionIndex 0
#define kMonitorSectionIndex 1

#define kSelectorVisibleIndex 0
#define kSelectorHiddenIndex 1

@interface ThreadCreationViewController () <UISearchBarDelegate,
                                            UITableViewDataSource,
                                            UITableViewDelegate,
                                            UICollectionViewDelegate,
                                            UICollectionViewDataSource,
                                            NSLayoutManagerDelegate>

@property (nonatomic, weak) IBOutlet UISearchBar *searchBar;
@property (nonatomic, weak) IBOutlet UITableView *tableView;
@property (nonatomic, weak) IBOutlet UICollectionView *slugContainerView;
@property (nonatomic, weak) IBOutlet UIBarButtonItem *exitButton;
@property (nonatomic, weak) IBOutlet UIBarButtonItem *goButton;
@property (nonatomic, weak) IBOutlet NSLayoutConstraint *slugViewHeight;
@property (weak, nonatomic) IBOutlet UIView *searchInfoContainer;
@property (weak, nonatomic) IBOutlet UILabel *searchInfoLabel;
@property (weak, nonatomic) IBOutlet UISegmentedControl *visibilitySelector;

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
    
    self.slugViewHeight.constant = KMinInputHeight;
    //    self.slugContainerView.layoutManager.delegate = self;
//    self.slugContainerView.textContainerInset = UIEdgeInsetsMake(8, 0, 8, KMinInputHeight);
    self.goButton.tintColor = [ForstaColors mediumLightGreen];
    
    self.searchBar.placeholder = NSLocalizedString(@"SEARCH_BYNAMEORNUMBER_PLACEHOLDER_TEXT", nil);
    
    self.searchInfoLabel.text = NSLocalizedString(@"SEARCH_HELP_STRING", @"Informational string for tag lookups.");
    
    [self.visibilitySelector setTitle:NSLocalizedString(@"VISIBLE", nil) forSegmentAtIndex:kSelectorVisibleIndex];
    [self.visibilitySelector setTitle:NSLocalizedString(@"HIDDEN", nil) forSegmentAtIndex:kSelectorHiddenIndex];
    
    self.view.backgroundColor = [ForstaColors whiteColor];
    
    // Refresh control handling
    UIView *refreshView = [UIView new];
    [self.tableView insertSubview:refreshView atIndex:0];
    self.refreshControl = [UIRefreshControl new];
//    self.refreshControl.attributedTitle = [[NSAttributedString alloc] initWithString:NSLocalizedString(@"REFRESHING", nil)];
    [self.refreshControl addTarget:self
                            action:@selector(refreshContentFromSource)
                  forControlEvents:UIControlEventValueChanged];
    [refreshView addSubview:self.refreshControl];

    [self updateGoButton];

    // Removing hide/unhide per request.
//    [self visibilitySelectorDidChange:self.visibilitySelector];
    [self changeMappingsGroupsTo:@[ FLVisibleRecipientGroup, FLActiveTagsGroup ]];
    self.visibilitySelector.hidden = YES;
}

-(void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    [self refreshTableView];
    
    [self.uiDbConnection beginLongLivedReadTransaction];
    
    [self.uiDbConnection readWithBlock:^(YapDatabaseReadTransaction *transaction)  {
        [self.tagMappings updateWithTransaction:transaction];
    }];
    
    //     Notifications
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(yapDatabaseModified:)
                                                 name:YapDatabaseModifiedNotification
                                               object:nil];
}

-(void)viewWillDisappear:(BOOL)animated
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [self.uiDbConnection endLongLivedReadTransaction];
    
    [super viewWillDisappear:animated];
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
    FLDirectoryCell *cell = (FLDirectoryCell *)[tableView dequeueReusableCellWithIdentifier:@"ContactCell" forIndexPath:indexPath];
    
    __block id object = [self objectForIndexPath:indexPath];
    if ([object isKindOfClass:[SignalRecipient class]]) {
        SignalRecipient *recipient = (SignalRecipient *)object;
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
            [cell configureCellWithContact:recipient];
        });
        if ([self.validatedSlugs containsObject:recipient.flTag.displaySlug]) {
            cell.accessoryType = UITableViewCellAccessoryCheckmark;
        } else {
            cell.accessoryType = UITableViewCellAccessoryNone;
        }
    } else if ([object isKindOfClass:[FLTag class]]) {
        FLTag *aTag = (FLTag *)object;
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
            [cell configureCellWithTag:aTag];
        });
        if ([self.validatedSlugs containsObject:aTag.displaySlug]) {
            cell.accessoryType = UITableViewCellAccessoryCheckmark;
        } else {
            cell.accessoryType = UITableViewCellAccessoryNone;
        }
    } else {
        return [UITableViewCell new];
    }
    
    return cell;
}

-(void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    NSString *tagSlug = nil;
    
    id object = [self objectForIndexPath:indexPath];
    if ([object isKindOfClass:[SignalRecipient class]]) {
        SignalRecipient *recipient = (SignalRecipient *)object;
        tagSlug = recipient.flTag.displaySlug;
    } else if ([object isKindOfClass:[FLTag class]]) {
        FLTag *aTag = (FLTag *)object;
        tagSlug = aTag.displaySlug;
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

-(NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
    if ([self tableView:tableView numberOfRowsInSection:section] > 0) {
        if (self.visibilitySelector.selectedSegmentIndex == kSelectorVisibleIndex) {
            if (section == kRecipientSectionIndex) {
                return NSLocalizedString(@"THREAD_SECTION_CONTACTS", nil);
            } else if (section == kTagSectionIndex) {
                return NSLocalizedString(@"THREAD_SECTION_TAGS", nil);
            }
        } else if (self.visibilitySelector.selectedSegmentIndex == kSelectorHiddenIndex) {
            if (section == kHiddenSectionIndex) {
                return NSLocalizedString(@"THREAD_SECTION_HIDDEN", nil);
            } else if (section == kMonitorSectionIndex) {
                return NSLocalizedString(@"THREAD_SECTION_MONITORS", nil);
            }
        }
    }
    return nil;
}

-(NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return (NSInteger)[self.tagMappings numberOfSections];
    
}

- (NSInteger)tableView:(nonnull UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return (NSInteger)[self.tagMappings numberOfItemsInSection:(NSUInteger)section];
}

// Removing hide/unhide per request.
//- (NSArray *)tableView:(UITableView *)tableView editActionsForRowAtIndexPath:(NSIndexPath *)indexPath
//{
//    switch (self.visibilitySelector.selectedSegmentIndex) {
//        case kSelectorVisibleIndex:
//        {
//            UITableViewRowAction *hideAction = [UITableViewRowAction rowActionWithStyle:UITableViewRowActionStyleNormal
//                                                                                  title:NSLocalizedString(@"HIDE", nil)
//                                                                                handler:^(UITableViewRowAction * _Nonnull action, NSIndexPath * _Nonnull tappedIndexPath) {
//                                                                                    id object = [self objectForIndexPath:tappedIndexPath];
//                                                                                    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
//                                                                                        if ([object isKindOfClass:[SignalRecipient class]]) {
//                                                                                            SignalRecipient *recipient = (SignalRecipient *)object;
//                                                                                            recipient.hiddenDate = [NSDate date];
//                                                                                            [recipient save];
//                                                                                        } else if ([object isKindOfClass:[FLTag class]]) {
//                                                                                            FLTag *aTag = (FLTag *)object;
//                                                                                            aTag.hiddenDate = [NSDate date];
//                                                                                            [aTag save];
//                                                                                        }
//                                                                                    });
//                                                                                }];
//            hideAction.backgroundColor = [ForstaColors darkGray];
//            return @[ hideAction];
//
//        }
//            break;
//        case kSelectorHiddenIndex:
//        {
//            if (indexPath.section == kMonitorSectionIndex) {
//                return @[];  // Monitors stay put.
//            } else {
//                UITableViewRowAction *unhideAction = [UITableViewRowAction rowActionWithStyle:UITableViewRowActionStyleNormal
//                                                                                        title:NSLocalizedString(@"UNHIDE", nil)
//                                                                                      handler:^(UITableViewRowAction * _Nonnull action, NSIndexPath * _Nonnull tappedIndexPath) {
//                                                                                          id object = [self objectForIndexPath:tappedIndexPath];
//                                                                                          dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
//                                                                                              if ([object isKindOfClass:[SignalRecipient class]]) {
//                                                                                                  SignalRecipient *recipient = (SignalRecipient *)object;
//                                                                                                  recipient.hiddenDate = nil;
//                                                                                                  [recipient save];
//                                                                                              } else if ([object isKindOfClass:[FLTag class]]) {
//                                                                                                  FLTag *aTag = (FLTag *)object;
//                                                                                                  aTag.hiddenDate = nil;
//                                                                                                  [aTag save];
//                                                                                              }
//                                                                                          });
//                                                                                      }];
//                unhideAction.backgroundColor = [ForstaColors darkGray];
//                return @[ unhideAction];
//            }
//        }
//            break;
//        default:
//        {
//            return @[];
//        }
//            break;
//    }
//}

-(void)refreshContentFromSource
{
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.refreshControl beginRefreshing];
        [Environment.getCurrent.contactsManager refreshCCSMRecipients];
        [self.refreshControl endRefreshing];
    });
}

-(void)refreshTableView
{
    dispatch_async(dispatch_get_main_queue(), ^{
        if ([self.tagMappings numberOfItemsInAllGroups] == 0) {
            self.searchInfoContainer.hidden = NO;
            self.tableView.hidden = YES;
        } else {
            self.searchInfoContainer.hidden = YES;
            self.tableView.hidden = NO;
        }
        [self.tableView reloadData];
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

#pragma mark - Database updates
- (void)yapDatabaseModified:(NSNotification *)notification
{
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
}

#pragma mark - SearchBar delegate methods
-(void)searchBar:(UISearchBar *)searchBar textDidChange:(NSString *)searchText
{
    [self updateFilteredMappingsForce:NO];
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
                                                  [self updateFilteredMappingsForce:NO];
                                                  [self refreshTableView];
                                              });
                                              
                                              // take this opportunity to store any userids
                                              NSArray *userids = [results objectForKey:@"userids"];
                                              if (userids.count > 0) {
                                                  dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{
                                                      for (NSString *uid in userids) {
                                                          [Environment.getCurrent.contactsManager recipientWithUserId:uid];
                                                      }
                                                  });
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

#pragma mark - UI Actions
// Removing hide/unhide per request.
- (IBAction)visibilitySelectorDidChange:(UISegmentedControl *)sender
{
    if (self.visibilitySelector.selectedSegmentIndex == kSelectorVisibleIndex) {
//        [self changeMappingsGroupsTo:@[ FLVisibleRecipientGroup, FLActiveTagsGroup ]];
    } else if (self.visibilitySelector.selectedSegmentIndex == kSelectorHiddenIndex) {
//        [self changeMappingsGroupsTo:@[ FLHiddenContactsGroup, FLMonitorGroup ]];
    }
}

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
                                              [self storeUsersInResults:results];
                                              [self buildThreadWithResults:results];
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

#pragma mark - worker methods
- (id)objectForIndexPath:(NSIndexPath *)indexPath {
    __block id object = nil;
    [self.uiDbConnection readWithBlock:^(YapDatabaseReadTransaction *transaction) {
        object = [[transaction extension:FLFilteredTagDatabaseViewExtensionName] objectAtIndexPath:indexPath
                                                                                      withMappings:self.tagMappings];
    }];
    return object;
}

-(void)updateFilteredMappingsForce:(BOOL)forced
{
    __block NSString *filterString = [self.searchBar.text lowercaseString];
    __block YapDatabaseViewFiltering *filtering = [YapDatabaseViewFiltering withObjectBlock:^BOOL(YapDatabaseReadTransaction * _Nonnull transaction,
                                                                                                  NSString * _Nonnull group,
                                                                                                  NSString * _Nonnull collection,
                                                                                                  NSString * _Nonnull key,
                                                                                                  id  _Nonnull object) {
        if (!([object isKindOfClass:[SignalRecipient class]] || [object isKindOfClass:[FLTag class]])) {
            return NO;
        }
        if (filterString.length > 0) {
            if ([object isKindOfClass:[FLTag class]]) {
                FLTag *aTag = (FLTag *)object;
                return ([[aTag.displaySlug lowercaseString] containsString:filterString] ||
                        [[aTag.slug lowercaseString] containsString:filterString] ||
                        [[aTag.tagDescription lowercaseString] containsString:filterString] ||
                        [[aTag.orgSlug lowercaseString] containsString:filterString]);
            } else if ([object isKindOfClass:[SignalRecipient class]]) {
                SignalRecipient *recipient = (SignalRecipient *)object;
                return ([[recipient.fullName lowercaseString] containsString:filterString] ||
                        [[recipient.flTag.displaySlug lowercaseString] containsString:filterString] ||
                        [[recipient.orgSlug lowercaseString] containsString:filterString]);
            } else {
                // We don't know what it is so we don't want it.
                return NO;
            }
        } else {
            return YES;
        }
    }];
    
    __block NSString *versionTag = filterString;
    if (forced) {
        versionTag = [NSString stringWithFormat:@"%u", arc4random()];
    }
    
    
    [self.searchDbConnection readWriteWithBlock:^(YapDatabaseReadWriteTransaction *transaction) {
        [[transaction ext:FLFilteredTagDatabaseViewExtensionName] setFiltering:filtering
                                                                    versionTag:versionTag];
    }];
    [self refreshTableView];
}

// Removing hide/unhide per request.
-(void)changeMappingsGroupsTo:(NSArray<NSString *> *)groups
{
    self.tagMappings = [[YapDatabaseViewMappings alloc] initWithGroups:groups
                                                                  view:FLFilteredTagDatabaseViewExtensionName];
    for (NSString *group in groups) {
        [self.tagMappings setIsReversed:YES forGroup:group];
    }

    [self.uiDbConnection readWithBlock:^(YapDatabaseReadTransaction *transaction)  {
        @try {
        [self.tagMappings updateWithTransaction:transaction];
        }
        @catch (NSException *exception) {
            NSLog(@"Exception: %@", exception);
        }
    }];
    [self refreshTableView];
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
            NSArray *userIds = [[results objectForKey:@"userids"] copy];
            for (NSString *uid in userIds) {
                [Environment.getCurrent.contactsManager recipientWithUserId:uid];
            }
//        }];
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
                                                          dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{
                                                              for (NSString *uid in thread.participants) {
                                                                  [Environment.getCurrent.contactsManager updateRecipient:uid];
                                                              }
                                                          });
                                                          
                                                          thread = [TSThread getOrCreateThreadWithParticipants:userIds];// transaction:transaction];
                                                          thread.type = @"conversation";
                                                          thread.prettyExpression = [[results objectForKey:@"pretty"] copy];
                                                          thread.universalExpression = [[results objectForKey:@"universal"] copy];
                                                          [thread save];
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
//        [self.slugContainerView scrollRangeToVisible:NSMakeRange(self.slugContainerView.text.length-1, 1)];
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
- (YapDatabaseConnection *)uiDbConnection {
    NSAssert([NSThread isMainThread], @"Must access uiDatabaseConnection on main thread!");
    if (!_uiDbConnection) {
        YapDatabase *database = TSStorageManager.sharedManager.database;
        _uiDbConnection = [database newConnection];
        [_uiDbConnection beginLongLivedReadTransaction];
//        [[NSNotificationCenter defaultCenter] addObserver:self
//                                                 selector:@selector(yapDatabaseModified:)
//                                                     name:YapDatabaseModifiedNotification
//                                                   object:database];
    }
    return _uiDbConnection;
}

-(YapDatabaseConnection *)searchDbConnection
{
    if (_searchDbConnection == nil) {
        YapDatabase *database = TSStorageManager.sharedManager.database;
        _searchDbConnection = [database newConnection];
    }
    return _searchDbConnection;
}

//-(YapDatabaseViewMappings *)tagMappings
//{
//    if (_tagMappings == nil) {
//        _tagMappings = [[YapDatabaseViewMappings alloc] initWithGroups:@[ FLVisibleRecipientGroup, FLActiveTagsGroup ]
//                                                                  view:FLFilteredTagDatabaseViewExtensionName];
//        [_tagMappings setIsReversed:NO forGroup:FLActiveTagsGroup];
//        [self.uiDbConnection asyncReadWithBlock:^(YapDatabaseReadTransaction * _Nonnull transaction) {
//            [_tagMappings updateWithTransaction:transaction];
//            dispatch_async(dispatch_get_main_queue(), ^{
//                [self.tableView reloadData];
//            });
//        }];
//    }
//    return _tagMappings;
//}

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



// MARK: - CollectionView protocol methods
- (nonnull __kindof UICollectionViewCell *)collectionView:(nonnull UICollectionView *)collectionView cellForItemAtIndexPath:(nonnull NSIndexPath *)indexPath
{
    SlugCell *cell = (SlugCell *)[collectionView dequeueReusableCellWithReuseIdentifier:"SlugCell" forIndexPath:indexPath];
    
    
    return cell;
}

- (NSInteger)collectionView:(nonnull UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section { 
    if (section == 0) {
        return (NSInteger)self.validatedSlugs.count;
    }
    return 0;
}

@end
