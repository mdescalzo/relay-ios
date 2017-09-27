//
//  ThreadCreationViewController.m
//  Forsta
//
//  Created by Mark on 9/25/17.
//  Copyright © 2017 Forsta. All rights reserved.
//

#define KMinInputHeight 21.0
#define kMaxInputHeight 84.0

#import "ThreadCreationViewController.h"
#import "FLDirectoryCell.h"
#import "Environment.h"
#import "FLTagMathService.h"
#import "TSAccountManager.h"
#import "SlugOverLayView.h"

@interface ThreadCreationViewController () <UISearchBarDelegate, UITableViewDataSource, UITableViewDelegate, UIGestureRecognizerDelegate, SlugOverLayViewDelegate, NSLayoutManagerDelegate>

@property (nonatomic, weak) IBOutlet UISearchBar *searchBar;
@property (nonatomic, weak) IBOutlet UITableView *tableView;
@property (nonatomic, weak) IBOutlet UITextView *slugContainerView;
@property (nonatomic, weak) IBOutlet UIBarButtonItem *exitButton;
@property (nonatomic, weak) IBOutlet UIBarButtonItem *goButton;

@property (nonatomic, weak) IBOutlet NSLayoutConstraint *slugViewHeight;

@property (nonatomic, strong) UISwipeGestureRecognizer *downSwipeRecognizer;

@property (nonatomic, strong) NSMutableArray *validatedSlugs;
@property (nonatomic, strong) NSMutableArray *slugViews;
//@property (nonatomic, strong) NSMutableDictionary *slugs;

@property (nonatomic, strong) NSArray *content;
@property (nonatomic, strong) NSArray *searchResults;

@property (nonatomic, strong) FLTagMathService *tagService;

@end

@implementation ThreadCreationViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    [self tagService];
//    [self downSwipeRecognizer];
    self.slugViewHeight.constant = KMinInputHeight;
//    self.slugContainerView.layoutManager.delegate = self;
    self.slugContainerView.textContainerInset = UIEdgeInsetsMake(8, 0, 8, KMinInputHeight);
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (nonnull UITableViewCell *)tableView:(nonnull UITableView *)tableView cellForRowAtIndexPath:(nonnull NSIndexPath *)indexPath {
    FLDirectoryCell *cell = (FLDirectoryCell *)[tableView dequeueReusableCellWithIdentifier:@"slugCell" forIndexPath:indexPath];
    
    NSDictionary *tagDict = nil;
    if (self.searchResults) {
        tagDict = self.searchResults[(NSUInteger)indexPath.row];
    } else {
        tagDict = self.content[(NSUInteger)indexPath.row];
    }
    
    [cell configureCellWithTagDictionary:tagDict];
    
    if ([self.validatedSlugs containsObject:[NSString stringWithFormat:@"@%@", [tagDict objectForKey:@"slug"]]]) {
        cell.accessoryType = UITableViewCellAccessoryCheckmark;
    } else {
        cell.accessoryType = UITableViewCellAccessoryNone;
    }

    return cell;
}

-(void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    NSDictionary *selectedTagDict = nil;
    if (self.searchResults) {
        selectedTagDict = [self.searchResults objectAtIndex:(NSUInteger)indexPath.row];
    } else {
        selectedTagDict = [self.content objectAtIndex:(NSUInteger)indexPath.row];
    }
    NSString *selectedTag = [NSString stringWithFormat:@"@%@", [selectedTagDict objectForKey:@"slug"]];
    NSDictionary *orgDict = [selectedTagDict objectForKey:@"org"];
//    NSString *selectedOrg = [orgDict objectForKey:@"slug"];
    
    if ([self.validatedSlugs containsObject:selectedTag]) {
        [self removeSlug:selectedTag];
    } else {
        [self addSlug:selectedTag];
    }
}

-(CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    return 65.0;
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

-(void)refreshTableView
{
    dispatch_async(dispatch_get_main_queue(), ^{

//    if ([self.tableView numberOfRowsInSection:0] == 0) {
//        self.tableView.alpha = 0.0;
//    } else {
//        self.tableView.alpha = 1.0;
        [self.tableView reloadData];
//    }
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
        __block NSString *searchText = [searchBar.text copy];
        [self.tagService tagLookupWithString:searchText
                                     success:^(NSDictionary *results) {
                                         DDLogDebug(@"%@", results);
                                         NSString *pretty = [results objectForKey:@"pretty"];
                                         NSArray *warnings = [results objectForKey:@"warnings"];
                                         
                                         __block NSMutableArray *badStrings = [NSMutableArray new];
                                         if (warnings.count > 0) {
                                             for (NSDictionary *warning in warnings) {
                                                 NSRange range = NSMakeRange([[warning objectForKey:@"position"] integerValue],
                                                                              [[warning objectForKey:@"length"] integerValue]);
                                                 NSString *badString = [searchText substringWithRange:range];
                                                 [badStrings addObject:badString];
                                             }
                                             dispatch_async(dispatch_get_main_queue(), ^{
                                                 NSMutableString *badStuff = [NSMutableString new];
                                                 for (NSString *string in badStrings) {
                                                     [badStuff appendFormat:@"%@\n", string];
                                                 }
                                                 NSString *message = [NSString stringWithFormat:@"%@\n%@", NSLocalizedString(@"Tag not found for:", @"Alert message for no results from taglookup"), badStuff];
                                                 UIAlertController *alert = [UIAlertController alertControllerWithTitle:nil
                                                                                                                message:message
                                                                                                         preferredStyle:UIAlertControllerStyleActionSheet];
                                                 UIAlertAction *okButton = [UIAlertAction actionWithTitle:NSLocalizedString(@"OK",)
                                                                                                    style:UIAlertActionStyleDefault
                                                                                                  handler:^(UIAlertAction *action) { /* do nothing */}];
                                                 [alert addAction:okButton];
                                                 [self presentViewController:alert animated:YES completion:nil];
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
    
}

-(IBAction)didPressExitButton:(id)sender
{
    if ([self.searchBar isFirstResponder]) {
        [self.searchBar resignFirstResponder];
    }
    [self dismissViewControllerAnimated:YES completion:^{ }];
}

-(void)didSwipeDown:(id)sender
{
    if ([self.searchBar isFirstResponder]) {
        [self.searchBar resignFirstResponder];
    }
}

#pragma mark - worker methods
-(void)addSlug:(NSString *)slug
{
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
        [self.slugContainerView scrollRangeToVisible:NSMakeRange(self.slugContainerView.text.length-1, 1)];
    });
}

-(void)removeSlug:(NSString *)slug
{
    dispatch_async(dispatch_get_main_queue(), ^{
        
        NSUInteger index = [self.validatedSlugs indexOfObject:slug];
        [self.validatedSlugs removeObjectAtIndex:index];
        UIView *aView = [self.slugViews objectAtIndex:index];
        [aView removeFromSuperview];
        [self.slugViews removeObjectAtIndex:index];
        [self refreshTableView];
        [self refreshSlugView];
    });
}

-(void)refreshSlugView
{
    dispatch_async(dispatch_get_main_queue(), ^{
        
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
        
        newHeight += 20.0;
        
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
    UITextPosition *start = [textView positionFromPosition:beginning offset:range.location];
    UITextPosition *end = [textView positionFromPosition:start offset:range.length];
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

-(NSArray *)content
{
    if (_content == nil) {
        NSArray *storedTagDicts = [Environment.getCurrent.ccsmStorage.getTags allValues];
        
        NSSortDescriptor *descriptionSD = [[NSSortDescriptor alloc] initWithKey:@"description" ascending:YES selector:@selector(localizedCaseInsensitiveCompare:)];
        NSSortDescriptor *slugSD = [[NSSortDescriptor alloc] initWithKey:@"slug" ascending:YES selector:@selector(localizedCaseInsensitiveCompare:)];
        
        _content = [storedTagDicts sortedArrayUsingDescriptors:@[ descriptionSD, slugSD ]];
    }
    return _content;
}

-(NSArray *)searchResults
{
    if (self.searchBar.text.length > 0 && ![self.searchBar.text isEqualToString:@"@"]) {
        if ([[self.searchBar.text substringToIndex:1] isEqualToString:@"@"]) {
            NSPredicate *slugPred = [NSPredicate predicateWithFormat:@"%K CONTAINS[c] %@", @"slug", [self.searchBar.text substringFromIndex:1]];
            return [self.content filteredArrayUsingPredicate:slugPred];
        } else {
            NSPredicate *descriptionPred = [NSPredicate predicateWithFormat:@"%K CONTAINS[c] %@", @"description", self.searchBar.text];
            NSPredicate *slugPred = [NSPredicate predicateWithFormat:@"%K CONTAINS[c] %@", @"slug", self.searchBar.text];
            NSCompoundPredicate *filterPred = [NSCompoundPredicate orPredicateWithSubpredicates:@[ descriptionPred, slugPred ]];
            return [self.content filteredArrayUsingPredicate:filterPred];
        }
    } else {
        return nil;
    }
}

-(FLTagMathService *)tagService
{
    if (_tagService == nil) {
        _tagService = [FLTagMathService new];
    }
    return _tagService;
}

@end
