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

@interface ThreadCreationViewController () <UISearchBarDelegate, UITableViewDataSource, UITableViewDelegate, UIGestureRecognizerDelegate, UICollectionViewDelegate, UICollectionViewDataSource>

@property (nonatomic, weak) IBOutlet UISearchBar *searchBar;
@property (nonatomic, weak) IBOutlet UITableView *tableView;
@property (nonatomic, weak) IBOutlet UICollectionView *collectionView;
@property (nonatomic, weak) IBOutlet UIBarButtonItem *exitButton;
@property (nonatomic, weak) IBOutlet UIBarButtonItem *goButton;

@property (nonatomic, weak) IBOutlet NSLayoutConstraint *slugViewHeight;

@property (nonatomic, strong) UISwipeGestureRecognizer *downSwipeRecognizer;

@property (nonatomic, strong) NSMutableArray *validatedSlugs;
@property (nonatomic, strong) NSArray *content;
@property (nonatomic, strong) NSArray *searchResults;

@property (nonatomic, strong) FLTagMathService *tagService;

@end

@implementation ThreadCreationViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    [self tagService];
    [self downSwipeRecognizer];
    self.slugViewHeight.constant = 0;
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
    NSString *selectedOrg = [orgDict objectForKey:@"slug"];
    
    if ([self.validatedSlugs containsObject:selectedTag]) {
        [self.validatedSlugs removeObject:selectedTag];
    } else {
        [self.validatedSlugs addObject:selectedTag];
    }
    [self refreshSlugView];
    [self.tableView reloadData];
    // Build Tag button
    // Spin off lookup
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
    [self.tableView reloadData];
}

-(void)searchBarSearchButtonClicked:(UISearchBar *)searchBar
{
    
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
-(void)refreshSlugView
{
    NSMutableString *tmpString = [NSMutableString new];
    for (NSString *slug in self.validatedSlugs) {
        if (tmpString.length == 0) {
            [tmpString appendString:slug];
        } else {
            [tmpString appendString:[NSString stringWithFormat:@"  %@", slug]];
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
    
    [UIView animateWithDuration:0.1 animations:^{
        self.slugViewHeight.constant = newHeight;
        self.slugContainerView.text = [NSString stringWithString:tmpString];
    }];
}

#pragma mark - Accessors
-(NSMutableArray *)validatedSlugs
{
    if (_validatedSlugs == nil) {
        _validatedSlugs = [NSMutableArray new];
    }
    return _validatedSlugs;
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
            NSPredicate *slugPred = [NSPredicate predicateWithFormat:@"%K CONTAINS %@", @"slug", [self.searchBar.text substringFromIndex:1]];
            return [self.content filteredArrayUsingPredicate:slugPred];
        } else {
            NSPredicate *descriptionPred = [NSPredicate predicateWithFormat:@"%K CONTAINS %@", @"description", self.searchBar.text];
            NSPredicate *slugPred = [NSPredicate predicateWithFormat:@"%K CONTAINS %@", @"slug", self.searchBar.text];
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

///////////////////////
#pragma mark - SlugButton
@class SlugButton;

@protocol SlugButtonDelegate <NSObject>
-(void)deleteButtonTappedOnSlugButton:(SlugButton *)sender;
@end

@interface SlugButton : UIView

@property (nonatomic, strong) NSString *slug;
@property (nonatomic, strong) UIButton *deleteButton;
@property (nonatomic, strong) UILabel *slugLabel;

@property (nonatomic, weak) id<SlugButtonDelegate>delegate;

@end

@implementation SlugButton

-(id)initWithSlug:(NSString *)slug
{
    if (self = [super init]) {
        _slug = [slug copy];
        
        _slugLabel = [UILabel new];
        _slugLabel.text = _slug;
        
        _deleteButton = [UIButton buttonWithType:UIButtonTypeSystem];
        _deleteButton.titleLabel.text = @"X";
        
        [self addSubview:_slugLabel];
        [self addSubview:_deleteButton];
        
        NSLayoutConstraint *topSlugConstraint = [NSLayoutConstraint constraintWithItem:_slugLabel
                                                                             attribute:NSLayoutAttributeTop
                                                                             relatedBy:NSLayoutRelationEqual
                                                                                toItem:self
                                                                             attribute:NSLayoutAttributeTop
                                                                            multiplier:1
                                                                              constant:0];
        NSLayoutConstraint *bottomSlugConstraint = [NSLayoutConstraint constraintWithItem:_slugLabel
                                                                                attribute:NSLayoutAttributeBottom
                                                                                relatedBy:NSLayoutRelationEqual
                                                                                   toItem:self
                                                                                attribute:NSLayoutAttributeBottom
                                                                               multiplier:1
                                                                                 constant:0];
        NSLayoutConstraint *leadingSlugConstraint = [NSLayoutConstraint constraintWithItem:_slugLabel
                                                                                 attribute:NSLayoutAttributeLeft
                                                                                 relatedBy:NSLayoutRelationEqual
                                                                                    toItem:self
                                                                                 attribute:NSLayoutAttributeLeft
                                                                                multiplier:1
                                                                                  constant:0];
        NSLayoutConstraint *trailSlugConstraint = [NSLayoutConstraint constraintWithItem:_slugLabel
                                                                               attribute:NSLayoutAttributeRight
                                                                               relatedBy:NSLayoutRelationEqual
                                                                                  toItem:_deleteButton
                                                                               attribute:NSLayoutAttributeRight
                                                                              multiplier:1
                                                                                constant:0];
        NSLayoutConstraint *topDeleteConstraint = [NSLayoutConstraint constraintWithItem:_deleteButton
                                                                               attribute:NSLayoutAttributeTop
                                                                               relatedBy:NSLayoutRelationEqual
                                                                                  toItem:self
                                                                               attribute:NSLayoutAttributeTop
                                                                              multiplier:1
                                                                                constant:0];
        NSLayoutConstraint *bottomDeleteConstraint = [NSLayoutConstraint constraintWithItem:_deleteButton
                                                                                  attribute:NSLayoutAttributeBottom
                                                                                  relatedBy:NSLayoutRelationEqual
                                                                                     toItem:self
                                                                                  attribute:NSLayoutAttributeBottom
                                                                                 multiplier:1
                                                                                   constant:0];
        NSLayoutConstraint *trailDeleteConstraint = [NSLayoutConstraint constraintWithItem:_deleteButton
                                                                                 attribute:NSLayoutAttributeRight
                                                                                 relatedBy:NSLayoutRelationEqual
                                                                                    toItem:self
                                                                                 attribute:NSLayoutAttributeRight
                                                                                multiplier:1
                                                                                  constant:0];
        NSLayoutConstraint *ratioDeleteConstraint = [NSLayoutConstraint constraintWithItem:_deleteButton
                                                                                 attribute:NSLayoutAttributeWidth
                                                                                 relatedBy:NSLayoutRelationEqual
                                                                                    toItem:_deleteButton
                                                                                 attribute:NSLayoutAttributeHeight
                                                                                multiplier:1
                                                                                  constant:0];
        [self addConstraints:@[ topSlugConstraint, bottomSlugConstraint, leadingSlugConstraint, trailSlugConstraint, topDeleteConstraint, bottomDeleteConstraint, trailDeleteConstraint,ratioDeleteConstraint ]];
        
    }
    return self;
}

-(void)deleteButtonTapped
{
    [self.delegate deleteButtonTappedOnSlugButton:self];
}

@end
