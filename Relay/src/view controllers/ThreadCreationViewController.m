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
#import "FLTagMathService.h"
#import "TSAccountManager.h"
#import "SlugOverLayView.h"
#import "TSStorageManager.h"
#import "TSThread.h"

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

@property (nonatomic, strong) NSArray<FLTag *> *content;
@property (nonatomic, strong) NSArray<FLTag *> *searchResults;

@property (nonatomic, strong) UIRefreshControl *refreshControl;

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
    
    // Notifications
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(contentRefreshed)
                                                 name:FLCCSMTagsUpdated
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(contentRefreshed)
                                                 name:FLCCSMUsersUpdated
                                               object:nil];

    [self updateGoButton];
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
    
    FLTag *aTag = nil;
    
    if (self.searchResults) {
        aTag = [self.searchResults objectAtIndex:(NSUInteger)[indexPath row]];
    } else {
        aTag = [self.content objectAtIndex:(NSUInteger)[indexPath row]];
    }
    
    [cell configureCellWithTag:aTag];
    
    if ([self.validatedSlugs containsObject:aTag.displaySlug]) {
        cell.accessoryType = UITableViewCellAccessoryCheckmark;
    } else {
        cell.accessoryType = UITableViewCellAccessoryNone;
    }

    return cell;
}

-(void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    FLTag *aTag = nil;
    if (self.searchResults) {
        aTag = [self.searchResults objectAtIndex:(NSUInteger)[indexPath row]];
    } else {
        aTag = [self.content objectAtIndex:(NSUInteger)[indexPath row]];
    }
    
    if ([self.validatedSlugs containsObject:aTag.displaySlug]) {
        [self removeSlug:aTag.displaySlug];
//        [self removeTagFromSelection:aTag];
    } else {
        [self addSlug:aTag.displaySlug];
//        [self addTagToSelection:aTag];
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
    return 1;
}

- (NSInteger)tableView:(nonnull UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    switch (section) {
        case 0:
        {
            if (self.searchResults) {
                return (NSInteger)self.searchResults.count;
            } else {
                return (NSInteger)self.content.count;
            }
        }
            break;
            
        default:
            return 0;
            break;
    }
}

-(void)refreshContentFromSource
{
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.refreshControl beginRefreshing];
        [CCSMCommManager refreshCCSMData];
        [Environment.getCurrent.contactsManager refreshRecipients];
        [self.tableView reloadData];
        [self.refreshControl endRefreshing];
    });
}

-(void)refreshTableView
{
    dispatch_async(dispatch_get_main_queue(), ^{
        if (self.searchBar.text.length > 0 && self.searchResults.count == 0) {
            self.searchInfoContainer.hidden = NO;
            self.tableView.hidden = YES;
        } else {
            self.searchInfoContainer.hidden = YES;
            self.tableView.hidden = NO;
        }
        [self.tableView reloadData];
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

#pragma mark - SearchBar delegate methods
-(void)searchBar:(UISearchBar *)searchBar textDidChange:(NSString *)searchText
{
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
        [FLTagMathService asyncTagLookupWithString:searchText
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
                                         });

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
        [FLTagMathService asyncTagLookupWithString:threadSlugs
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
-(void)contentRefreshed
{
    self.content = nil;
    [self.tableView reloadData];
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
            // do the lookup things
            [CCSMCommManager asyncRecipientFromCCSMWithID:uid
                                                  success:^(SignalRecipient *recipient) {
                                                      if (recipient) {
                                                          [recipient save];
                                                          DDLogDebug(@"CCSM lookup succeeded for: %@", recipient.fullName);
                                                      }
                                                  } failure:^(NSError *error) {
                                                      DDLogDebug(@"CCSM lookup failed for uid: %@", uid);
                                                  }];
            
        }
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
        [FLTagMathService asyncTagLookupWithString:pretty
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

-(NSArray<FLTag *> *)content
{
    if (_content == nil) {
        NSArray *allTags = [FLTag allObjectsInCollection];

        NSSortDescriptor *descriptionSD = [[NSSortDescriptor alloc] initWithKey:@"tagDescription" ascending:YES selector:@selector(localizedCaseInsensitiveCompare:)];
        NSSortDescriptor *slugSD = [[NSSortDescriptor alloc] initWithKey:@"slug" ascending:YES selector:@selector(localizedCaseInsensitiveCompare:)];

        // Filter out monitors
        _content = [allTags sortedArrayUsingDescriptors:@[ descriptionSD, slugSD ]];
    }
    return _content;
}

-(NSArray<FLTag *> *)searchResults
{
    if (self.searchBar.text.length > 0 && ![self.searchBar.text isEqualToString:@"@"]) {
        if ([[self.searchBar.text substringToIndex:1] isEqualToString:@"@"]) {
            NSPredicate *slugPred = [NSPredicate predicateWithFormat:@"%K CONTAINS[c] %@", @"displaySlug", [self.searchBar.text substringFromIndex:1]];
            return [self.content filteredArrayUsingPredicate:slugPred];
        } else {
            NSPredicate *descriptionPred = [NSPredicate predicateWithFormat:@"%K CONTAINS[c] %@", @"tagDescription", self.searchBar.text];
            NSPredicate *slugPred = [NSPredicate predicateWithFormat:@"%K CONTAINS[c] %@", @"displaySlug", self.searchBar.text];
            NSCompoundPredicate *filterPred = [NSCompoundPredicate orPredicateWithSubpredicates:@[ descriptionPred, slugPred ]];
            return [self.content filteredArrayUsingPredicate:filterPred];
        }
    } else {
        return nil;
    }
}

@end
