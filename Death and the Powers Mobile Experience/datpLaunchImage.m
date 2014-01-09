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
    NSDictionary *defaults;
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
    
    [self _navigateUserWhenInfoIsReceived];
}

- (void) _navigateUserWhenInfoIsReceived
{
    NSLog(@"[Launch Image] Navigating user to correct view.");
    
    defaults = [userDefaults dictionaryRepresentation];
    
    // Get network information
    [AppDelegate().wifiViewController updateNetworkInformation];
    
    // Redirected to correct screen based on certain conditions
    if (defaults[@"location"])
    {
        NSLog(@"[App Delegate Redirect] Already chose location. Skipping welcome.");
        
        // Go to wifi
        if (!AppDelegate().connectedToAWifiNetwork ||
            !AppDelegate().connectedToInternet ||
            (AppDelegate().showVenueWifi && !AppDelegate().connectedToCorrectWifiNetwork))
        {
            NSLog(@"[App Delegate Redirect] Not connected to internet or wifi or supposed to show wifi. Going to wifi.");
            [AppDelegate() transitionToViewController:AppDelegate().wifiViewController];
        }
        else
        {
            [self navigateFromWifi];
        }
    }
    else
    {
        [AppDelegate() transitionToViewController:AppDelegate().welcomeAndInfoViewController];
    }
}

- (void) navigateFromWifi
{
    NSLog(@"[App Delegate Redirect] Connected to wifi & internet. Skipping wifi.");
    
    // Go to facebook
    if (!defaults[@"downloaded_facebook_photos"] && !defaults[@"skipped_facebook"])
    {
        NSLog(@"[App Delegate Redirect] Haven't chose what to do about facebook. Going to facebook.");
        [AppDelegate() transitionToViewController:AppDelegate().facebookViewController];
    }
    else
    {
        NSLog(@"[App Delegate Redirect] Already downloaded facebook photos or chose to skip. Skipping facebook.");
        
        // Go to production
        if ([[userDefaults objectForKey:@"latest_content_version"] isEqualToString:@"false"])
        {
            NSLog(@"[App Delegate Redirect] Device doesn't have latest content version. Going to production content download.");
            [AppDelegate() transitionToViewController:AppDelegate().productionContentViewController];
        }
        else
        {
            [self navigateFromProduction];
        }
    }
}

- (void) navigateFromProduction
{
    NSLog(@"[App Delegate Redirect] Device has latest content. Skipping production content download.");
    
    // Go to holding screen
    if (AppDelegate().showHoldingScreen)
    {
        NSLog(@"[App Delegate Redirect] Showing holding screen.");
        [AppDelegate() transitionToViewController:AppDelegate().holdingViewController];
    }
    // Go to show
    else
    {
        NSLog(@"[App Delegate Redirect] Skipping holding screen. Moving straight to show.");
        [AppDelegate() transitionToViewController:AppDelegate().mainShowViewController];
    }
}


@end
