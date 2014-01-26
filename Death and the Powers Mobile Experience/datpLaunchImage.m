//
//  datpLaunchImage.m
//  Powers Live
//
//  Created by Garrett Parrish on 1/2/14.
//  Copyright (c) 2014 Opera of the Future. All rights reserved.
//

#import "datpLaunchImage.h"
#import "datpAppDelegate.h"

@implementation datpLaunchImage
{
    BOOL showInfoNotificationCalled;
    NSUserDefaults *userDefaults;
    UIActivityIndicatorView *connecting;
}

- (void) awakeFromNib
{
    userDefaults = [NSUserDefaults standardUserDefaults];

    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(showInfoDidLoad:) name:DATPShowInfoDidLoadNotification object:AppDelegate()];
}

- (void) viewWillAppear:(BOOL)animated
{
    UIImageView *splashImage = [[UIImageView alloc] initWithFrame:self.view.frame];
    
    // Set on phone
    NSString *phoneSizeFile = AppDelegate().smallPhone ? @"Default.png" : @"Default-568h@2x.png";
    
    // If iPad
    if (AppDelegate().ipad) phoneSizeFile = @"Default~ipad.png";
    
    [splashImage setImage:[UIImage imageNamed:phoneSizeFile]];
    [self.view addSubview:splashImage];
    
    // Activity Indicator
    connecting = [[UIActivityIndicatorView alloc] initWithFrame:CGRectMake(100, 100, 100, 100)];
    connecting.center = CGPointMake(AppDelegate().viewWidth/2, AppDelegate().viewHeight * .23);
    [self.view addSubview:connecting];
    [connecting startAnimating];
}

- (void) showInfoDidLoad:(NSNotification*)notification
{
    NSLog(@"[Launch Image] Show info loaded... populating pickerview.");
    
    [connecting stopAnimating];
    
    [AppDelegate().welcomeAndInfoViewController.locations removeAllObjects];
    
    [AppDelegate().welcomeAndInfoViewController.locations addObject:@""];
    
    // Populate picker array
    for (NSString* loc in AppDelegate().appShowInfo[@"locations"])
    {
        [AppDelegate().welcomeAndInfoViewController.locations addObject:loc];
    }
    
    [AppDelegate().welcomeAndInfoViewController.pickerView selectRow:0 inComponent:0 animated:NO];
    
    [AppDelegate().welcomeAndInfoViewController.pickerView reloadComponent:0];
    
    NSLog(@"[Launch Image] Done loading. Moving from launch image to main view controller");
    
    [AppDelegate() navigateUser];
}



@end
