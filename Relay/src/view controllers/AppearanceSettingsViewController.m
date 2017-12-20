//
//  AppearanceSettingsViewController.m
//  Forsta
//
//  Created by Mark Descalzo on 12/18/17.
//  Copyright © 2017 Forsta. All rights reserved.
//

#import "AppearanceSettingsViewController.h"
#import "FLPickerCell.h"

#define kGravatarSectionIdex 0
#define KUseGravatarIndex 0
#define kMessagesSectionIndex 1
#define kOutgoingColorSettingIndex 0
#define kOutgoingColorPickerIndex 1

#define kOutgoingColorPickerTag 101

@interface AppearanceSettingsViewController () <UIPickerViewDelegate, UIPickerViewDataSource>

@property (nonatomic, strong) NSArray *sectionsHeadings;
@property (nonatomic, strong) UIColor *selectedOutgoingBubbleColor;
@property (nonatomic, strong) PropertyListPreferences *prefs;
@property (nonatomic, strong) UISwitch *gravatarSwitch;

@end

@implementation AppearanceSettingsViewController
{
    BOOL editingOutgoingBubbleColor;
}

@synthesize selectedOutgoingBubbleColor = _selectedOutgoingBubbleColor;

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    self.title = NSLocalizedString(@"SETTINGS_APPEARANCE", nil);
}

-(void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    [self.prefs addObserver:self forKeyPath:@"selectedOutgoingBubbleColor" options:NSKeyValueObservingOptionNew context:NULL];
}

-(void)viewDidDisappear:(BOOL)animated
{
    [self.prefs removeObserver:self forKeyPath:@"selectedOutgoingBubbleColor"];
    [super viewDidDisappear:animated];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - Table view 

-(CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.section == kMessagesSectionIndex && indexPath.row == kOutgoingColorPickerIndex) {
        if (editingOutgoingBubbleColor) {
            return 216;
        } else {
            return 0;
        }
    } else {
        return self.tableView.rowHeight;
    }
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    return [self.sectionsHeadings objectAtIndex:(NSUInteger)section];
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return (NSInteger)self.sectionsHeadings.count;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    switch (section) {
        case kGravatarSectionIdex:  // Gravatar section
            return 1;
            break;
        case kMessagesSectionIndex: // Messages section
            return 2;
            break;
        default:
            return 0;
            break;
    }
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    NSString *cellIdentifier = @"ForstaTableViewCellIdentifier";
    NSString *pickerCellID = @"PickerCell";

    UITableViewCell *cell = nil;

    // Configure the cell...
    switch (indexPath.section) {
        case kGravatarSectionIdex:  // Gravatars
        {
            switch (indexPath.row) {
                case KUseGravatarIndex:
                {
                    cell = [tableView dequeueReusableCellWithIdentifier:cellIdentifier forIndexPath:indexPath];
                    
                    cell.textLabel.text = NSLocalizedString(@"APPEARANCE_USE_GRAVATARS", nil);
                    cell.detailTextLabel.text = nil;
                    cell.accessoryView = self.gravatarSwitch;
                }
                    break;
                default:
                    break;
            }
        }
            break;
        case kMessagesSectionIndex:  // Message bubbles
        {
            switch (indexPath.row) {
                case kOutgoingColorSettingIndex:
                {
                    cell = [tableView dequeueReusableCellWithIdentifier:cellIdentifier forIndexPath:indexPath];
                    cell.textLabel.text = NSLocalizedString(@"APPEARANCE_MESSAGE_BUBBLE_COLOR", nil);
                    cell.detailTextLabel.text = nil;
                    UILabel *colorPreview = [[UILabel alloc] initWithFrame:CGRectMake(0.0f, 0.0f, 72.0f, 30.0f)];
                    colorPreview.text = NSLocalizedString(@"SAMPLE", nil);
                    colorPreview.textAlignment = NSTextAlignmentCenter;
                    colorPreview.font = [UIFont systemFontOfSize:15.0f];
                    colorPreview.textColor = [UIColor whiteColor];
                    colorPreview.layer.cornerRadius = 12.0f;
                    colorPreview.backgroundColor = self.selectedOutgoingBubbleColor;
                    colorPreview.clipsToBounds = YES;
                    cell.accessoryView = colorPreview;
                }
                    break;
                case kOutgoingColorPickerIndex:
                {
                    FLPickerCell *tmpCell = (FLPickerCell *)[tableView dequeueReusableCellWithIdentifier:pickerCellID forIndexPath:indexPath];
                    tmpCell.pickerView.delegate = self;
                    tmpCell.pickerView.dataSource = self;
                    tmpCell.pickerView.tag = kOutgoingColorPickerTag;
                    tmpCell.pickerView.showsSelectionIndicator = YES;
                    NSString *colorKey = self.prefs.outgoingBubbleColorKey;
                    NSInteger index = (NSInteger)[[[ForstaColors outgoingBubbleColors] allKeys] indexOfObject:colorKey];
                    [tmpCell.pickerView selectRow:index
                                      inComponent:0
                                         animated:NO];
                    cell = tmpCell;
                }
                    break;
                default:
                    break;
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
    switch (indexPath.section) {
        case kGravatarSectionIdex:
        {
            self.gravatarSwitch.on = !self.gravatarSwitch.on;
            [self didToggleGravatarSwitch:self.gravatarSwitch];
            [tableView beginUpdates];
//            [self.tableView reloadRowsAtIndexPaths:@[ [NSIndexPath indexPathForRow:KUseGravatarIndex inSection:kGravatarSectionIdex] ]
//                                  withRowAnimation:UITableViewRowAnimationFade];

            [tableView deselectRowAtIndexPath:indexPath animated:YES];
            if (editingOutgoingBubbleColor) {
                editingOutgoingBubbleColor = !editingOutgoingBubbleColor;
            }
            [tableView endUpdates];
        }
            break;
        case kMessagesSectionIndex:
        {
            switch (indexPath.row) {
                case kOutgoingColorSettingIndex:
                    {
                        [tableView beginUpdates];
                        [tableView deselectRowAtIndexPath:indexPath animated:YES];
                        editingOutgoingBubbleColor = !editingOutgoingBubbleColor;
                        [tableView endUpdates];
                    }
                    break;
                    
                default:
                    break;
            }
        }
            break;
        default:
            break;
    }
}

/*
// Override to support conditional editing of the table view.
- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
    // Return NO if you do not want the specified item to be editable.
    return YES;
}
*/

/*
// Override to support editing the table view.
- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath {
    if (editingStyle == UITableViewCellEditingStyleDelete) {
        // Delete the row from the data source
        [tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationFade];
    } else if (editingStyle == UITableViewCellEditingStyleInsert) {
        // Create a new instance of the appropriate class, insert it into the array, and add a new row to the table view
    }   
}
*/

/*
// Override to support rearranging the table view.
- (void)tableView:(UITableView *)tableView moveRowAtIndexPath:(NSIndexPath *)fromIndexPath toIndexPath:(NSIndexPath *)toIndexPath {
}
*/

/*
// Override to support conditional rearranging of the table view.
- (BOOL)tableView:(UITableView *)tableView canMoveRowAtIndexPath:(NSIndexPath *)indexPath {
    // Return NO if you do not want the item to be re-orderable.
    return YES;
}
*/

/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/

#pragma mark - Picker view methods
-(CGFloat)pickerView:(UIPickerView *)pickerView rowHeightForComponent:(NSInteger)component
{
    if (pickerView.tag == kOutgoingColorPickerTag) {
        return 40.0f;
    }
    return 21.0f;
}

-(UIView *)pickerView:(UIPickerView *)pickerView viewForRow:(NSInteger)row forComponent:(NSInteger)component reusingView:(UIView *)view
{
    if (pickerView.tag == kOutgoingColorPickerTag) {
        NSArray *colors = [[ForstaColors outgoingBubbleColors] allValues];
        NSArray *colorTitles = [[ForstaColors outgoingBubbleColors] allKeys];
        UILabel *newView = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, UIScreen.mainScreen.bounds.size.width*0.75f, 37.0f)];
        newView.backgroundColor = colors[(NSUInteger)row];
        newView.layer.cornerRadius = 12.0f;
        newView.clipsToBounds = YES;
        newView.textColor = [UIColor whiteColor];
        newView.text = colorTitles[(NSUInteger)row];
        newView.textAlignment = NSTextAlignmentCenter;
        
        return newView;
    }
    return [UIView new];
}

- (NSInteger)numberOfComponentsInPickerView:(nonnull UIPickerView *)pickerView {
    if (pickerView.tag == kOutgoingColorPickerTag) {
        return 1;
    }
    return 0;
}

- (NSInteger)pickerView:(nonnull UIPickerView *)pickerView numberOfRowsInComponent:(NSInteger)component {
    if (pickerView.tag == kOutgoingColorPickerTag) {
        if (component == 0) {
            return (NSInteger)[[ForstaColors outgoingBubbleColors] allValues].count;
        }
    }
    return 0;
}

-(void)pickerView:(UIPickerView *)pickerView didSelectRow:(NSInteger)row inComponent:(NSInteger)component
{
    if (pickerView.tag == kOutgoingColorPickerTag) {
        NSString *colorKey = [[[ForstaColors outgoingBubbleColors] allKeys] objectAtIndex:(NSUInteger)row];
        self.prefs.outgoingBubbleColorKey = colorKey;
        [self.tableView reloadRowsAtIndexPaths:@[ [NSIndexPath indexPathForRow:kOutgoingColorSettingIndex inSection:kMessagesSectionIndex] ]
                              withRowAnimation:UITableViewRowAnimationFade];
    }
}

#pragma mark - KVO implementation
-(void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    if ([keyPath isEqualToString:@"selectedOutgoingBubbleColor"]) {
        [self.tableView reloadRowsAtIndexPaths:@[ [NSIndexPath indexPathForRow:kOutgoingColorSettingIndex inSection:kMessagesSectionIndex] ]
                              withRowAnimation:UITableViewRowAnimationFade];
    }
}

#pragma mark - Actions
-(void)didToggleGravatarSwitch:(UISwitch *)sender
{
    self.prefs.useGravatars = sender.on;
}

#pragma mark - Accessors
-(NSArray *)sectionsHeadings
{
    if (_sectionsHeadings == nil) {
        _sectionsHeadings = @[ NSLocalizedString(@"APPEARANCE_GRAVATAR_SECTION", nil),
                               NSLocalizedString(@"APPEARANCE_MESSAGES_SECTION", nil) ];
    }
    return _sectionsHeadings;
}

-(UISwitch *)gravatarSwitch
{
    if (_gravatarSwitch == nil) {
        _gravatarSwitch = [[UISwitch alloc] initWithFrame:CGRectZero];
        _gravatarSwitch.on = self.prefs.useGravatars;
        [_gravatarSwitch addTarget:self
                    action:@selector(didToggleGravatarSwitch:)
          forControlEvents:UIControlEventValueChanged];
    }
    return _gravatarSwitch;
}

-(UIColor *)selectedOutgoingBubbleColor
{
        NSString *colorKey = self.prefs.outgoingBubbleColorKey;
        return [[ForstaColors outgoingBubbleColors] objectForKey:colorKey];
}

-(PropertyListPreferences *)prefs
{
    if (_prefs == nil) {
        _prefs = Environment.preferences;
    }
    return _prefs;
}

@end
