//
//  datpWelcomeAndInfo.m
//  Death and the Powers Mobile Experience
//
//  Created by Garrett Parrish on 12/4/13.
//  Copyright (c) 2013 Opera of the Future. All rights reserved.
//

#import "datpWelcomeAndInfo.h"
#import "datpAppDelegate.h"
#import "datpWifiScreen.h"
#import "datpLaunchImage.h"
#import "TestFlight.h"

@implementation datpWelcomeAndInfo
{
    UIButton *continueButton;
    UITextView *keepInTouch;
    UITextView *chooseLocation;
    UIImageView *backgroundImage;
    UIPickerView *locationPicker;
    NSUserDefaults *userDefaults;
}

@synthesize pickerView, locations;

- (void) awakeFromNib
{
    [super awakeFromNib];
    userDefaults = [NSUserDefaults standardUserDefaults];
    locations = [[NSMutableArray alloc] initWithObjects:@"", nil];
}

- (void) viewDidLoad
{
    [super viewDidLoad];
    
    // Position UI elements manually so that view works for all phones
    [self _configureUI];

    // Disable continue button until user has chosen a location
    continueButton.enabled = [self _hasSelectedLocation];
}

- (void) _configureUI
{
    // Background image
    backgroundImage = [[UIImageView alloc] initWithFrame:self.view.frame];
    [backgroundImage setImage:[UIImage imageNamed:@"text_bg.png"]];
    
    // Allow subview to receive events
    backgroundImage.userInteractionEnabled = YES;
    
    [self.view addSubview:backgroundImage];
    
    CGFloat viewWidth = AppDelegate().viewWidth;
    CGFloat viewHeight = AppDelegate().viewHeight;
    
    // Choose location text field
    chooseLocation = [[UITextView alloc] initWithFrame:CGRectMake(viewWidth * .3, viewWidth * .7, viewWidth * .9, viewHeight * .25)];
    chooseLocation.center = CGPointMake(viewWidth/2, viewHeight*.2);
    
    NSString* text = @"You must choose the venue where you will be viewing the \nDeath and the Powers Global Simulcast on February 16, 2014, and then click Submit/Continue. (required)";
    chooseLocation.attributedText = GetFormattedText(text);
    
    [AppDelegate() formatTextField:chooseLocation];
    [backgroundImage addSubview:chooseLocation];
    
    // Continue button
    continueButton = [[UIButton alloc] initWithFrame:CGRectMake(viewWidth * .15, viewWidth * .85, viewWidth * .7, viewHeight * .05)];
    continueButton.center = CGPointMake(viewWidth/2, viewHeight*.9);
    [continueButton setTitle:@"Submit / Continue" forState:UIControlStateNormal];
    
    [AppDelegate() formatButton:continueButton];
    [continueButton addTarget:self action:@selector(_moveToNextView) forControlEvents:UIControlEventTouchUpInside];
    [backgroundImage addSubview:continueButton];
    
    [self _configurePickerView];
}

/////////////////////////////////////////////////////////////
////////////////////// PICKER VIEW //////////////////////////
/////////////////////////////////////////////////////////////

- (void) _configurePickerView
{
    // Remove the view if it already exists / was instantiated
    [pickerView removeFromSuperview];
    
    // Create frame from dimensions
    CGFloat x = (AppDelegate().ipad) ? .1 : .3;
    CGFloat y = (AppDelegate().ipad) ? .9 : .7;
    CGFloat viewWidth = AppDelegate().viewWidth;
    CGFloat viewHeight = AppDelegate().viewHeight;
    CGRect pickerViewFrame = CGRectMake(viewWidth * x, viewHeight * y, viewWidth, 216.0);
    
    // If pickerView doesn't exist yet - create it with that frame
    pickerView = [[UIPickerView alloc] initWithFrame:pickerViewFrame];
    pickerView.center = CGPointMake(viewWidth/2, viewHeight*.57);
    
    // Set the delegate and datasource for picker view
    [pickerView setDataSource: self];
    [pickerView setDelegate: self];
    pickerView.showsSelectionIndicator = YES;
    
    [self.view addSubview:pickerView];
}

- (UIView *) pickerView:(UIPickerView *)pickerView viewForRow:(NSInteger)row forComponent:(NSInteger)component reusingView:(UIView *)view
{
    // Create attributed string
    NSString *location = [locations objectAtIndex: row];
    
    UIColor *fontColor = AppDelegate().ios6 ? [UIColor blackColor] : [UIColor whiteColor];
    UIFont *font = AppDelegate().ipad ? [UIFont systemFontOfSize:35.0] : [UIFont systemFontOfSize:16.0];
    NSDictionary *attributes = @{NSFontAttributeName: font, NSForegroundColorAttributeName : fontColor};
    NSAttributedString *attributedString = [[NSAttributedString alloc] initWithString:location attributes:attributes];
    
    // Add the string to a label's attributedText property
    UILabel *labelView = [[UILabel alloc] init];
    labelView.attributedText = attributedString;
    labelView.textAlignment = NSTextAlignmentCenter;
    labelView.backgroundColor = [UIColor clearColor];
    
    // Return the label
    return labelView;
}

- (CGFloat)pickerView:(UIPickerView *)pickerView rowHeightForComponent:(NSInteger)component
{
    return AppDelegate().ipad ? 64 : 36;
}

// Get number of components in the picker view
- (NSInteger) numberOfComponentsInPickerView:(UIPickerView *)pickerView
{
    return 1;
}

// Get the rows of the picker view
- (NSInteger) pickerView: (UIPickerView *)pickerView numberOfRowsInComponent:(NSInteger)component
{
    return [locations count];
}

// Display each row's data
- (NSString *) pickerView:(UIPickerView *)pickerView titleForRow:(NSInteger)row forComponent:(NSInteger)component
{
    return [locations objectAtIndex: row];
}

// If a location isn't selected - disable continue button
- (void) pickerView:(UIPickerView *)pickerView didSelectRow:(NSInteger)row inComponent:(NSInteger)component
{
    continueButton.enabled = [self _hasSelectedLocation];
}

- (void) showInfoDidLoad:(NSNotification*)notification
{
    NSLog(@"[Welcome View] Show info loaded... populating pickerview.");
    
    [locations removeAllObjects];
    
    [locations addObject:@""];
    
    // Populate picker array
    for (NSString* loc in AppDelegate().appShowInfo[@"locations"])
    {
        [locations addObject:loc];
    }
    
    [pickerView selectRow:0 inComponent:0 animated:NO];
    
    [pickerView reloadComponent:0];
    
    [TestFlight passCheckpoint:@"[Welcome View] Loaded picker view and welcome view."];
}

/////////////////////////////////////////////////////////////
/////////////////////// LOCATION ////////////////////////////
/////////////////////////////////////////////////////////////

- (BOOL) _hasSelectedLocation
{
    return [pickerView selectedRowInComponent:0] > 0;
}

- (void) _setLocation:(NSString *)location
{
    NSString *locationID = AppDelegate().appShowInfo[@"locations"][location][@"id"];
    [userDefaults setObject:locationID forKey:@"locationid"];
    [userDefaults setObject:location forKey:@"location"];
    [AppDelegate().deviceInfo setValue:location forKey:@"location"];
    [AppDelegate() updateUserDefaults];
    [TestFlight passCheckpoint:[NSString stringWithFormat:@"[Welcome View] User chose location:%@", [userDefaults objectForKey:@"location"]]];
}

/////////////////////////////////////////////////////////////
////////////////////// NAVIGATION ///////////////////////////
/////////////////////////////////////////////////////////////

- (void) _moveToNextView
{
    // If a location was selected
    if ([self _hasSelectedLocation])
    {
        // Set row
        NSInteger row = [pickerView selectedRowInComponent:0];
        [self _setLocation:[locations objectAtIndex:row]];

        // Navigate user
        [AppDelegate() navigateUser];
    }
}

@end
