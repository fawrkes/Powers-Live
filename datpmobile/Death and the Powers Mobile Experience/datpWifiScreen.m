//
//  datpWelcomeScreen.m
//  Death and the Powers Mobile Experience
//
//  Created by Garrett Parrish on 11/21/13.
//  Copyright (c) 2013 Opera of the Future. All rights reserved.
//

#import "datpWifiScreen.h"
#import "TestFlight.h"
#import "datpFacebookLoginViewController.h"
#import "datpProductionContentDownload.h"
#import "datpAppDelegate.h"
#import "datpLaunchImage.h"

@interface datpWifiScreen ()
{
    NSString *wifiname;
    
    BOOL *connectedToInternet;
    BOOL *connectedToWifi;
    
    UIImageView *backgroundImage;
    UIButton *continueBtn;
    UIButton *chooseVenueBtn;
    UITextView *wifiMessage;
    
    NSUserDefaults *userDefaults;
}
@property (strong, nonatomic) IBOutlet UIButton *bypassButton;
@end

@implementation datpWifiScreen

@synthesize bypassButton;

- (void) awakeFromNib
{
    [super awakeFromNib];
    
    userDefaults = [NSUserDefaults standardUserDefaults];
}

- (void) viewDidLoad
{
    [super viewDidLoad];
    
    [self _configureUI];
}

- (void) _deployWifiAlert
{
    NSLog(@"[Wifi Screen] Deploying wifi alert.");
    
    NSString* venueTitle = @"Venue Wi-Fi Access Required";
    NSString* venueMessage = @"Please connect to the Wi-Fi network provided by the venue, or ask an usher for help connecting your device.";
    
    NSString* generalTitle = @"Wi-Fi Access Required";
    NSString* generalMessage = @"Please connect to a Wi-Fi network with Internet access to proceed.";
    
    UIAlertView *wifiAlert = [[UIAlertView alloc] initWithTitle:AppDelegate().showVenueWifi ? venueTitle : generalTitle
                                                        message:AppDelegate().showVenueWifi ? venueMessage : generalMessage
                                                       delegate:nil
                                              cancelButtonTitle:@"OK"
                                              otherButtonTitles:nil];
    [wifiAlert show];
}

- (void) _configureUI
{
    float viewWidth = AppDelegate().viewWidth;
    float viewHeight = AppDelegate().viewHeight;
    
    // Background image
    backgroundImage = [[UIImageView alloc] initWithFrame:self.view.frame];
    [backgroundImage setImage:[UIImage imageNamed:@"text_bg.png"]];
    [self.view addSubview:backgroundImage];
    
    // Wifi message
    wifiMessage = [[UITextView alloc] initWithFrame:CGRectMake(viewWidth * .1, viewWidth * .9, viewWidth * .8, viewHeight * .25)];
    wifiMessage.center = CGPointMake(viewWidth/2, viewHeight * .35);
    
    [self.view addSubview:wifiMessage];
    
    // Skip button
    continueBtn = [[UIButton alloc] initWithFrame:CGRectMake(viewWidth * .15, viewWidth * .85, viewWidth * .6, viewHeight * .2)];
    continueBtn.center = CGPointMake(viewWidth/2, viewHeight * .8);
    [continueBtn setTitle:@"Continue / I'm Connected" forState:UIControlStateNormal];
    [AppDelegate() formatButton:continueBtn];
    continueBtn.hidden = NO;
    [continueBtn addTarget:self action:@selector(_checkNetworkFromWifi) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:continueBtn];
    
    chooseVenueBtn = [[UIButton alloc] initWithFrame:CGRectMake(5, 5, 150, 25)];
    chooseVenueBtn.center = CGPointMake(viewWidth/2, viewHeight * .9);
    [chooseVenueBtn setTitle:@"Start Over" forState:UIControlStateNormal];
    [AppDelegate() formatButton:chooseVenueBtn];
    [chooseVenueBtn addTarget:self action:@selector(_handleChooseVenue) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:chooseVenueBtn];
    [self.view bringSubviewToFront:chooseVenueBtn];
}

- (void) viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    NSString *location = [userDefaults objectForKey:@"location"];
    wifiname = [[AppDelegate().appShowInfo[@"locations"] objectForKey:location] objectForKey:@"ssid"];
    
    NSString *messageAtVenue = [NSString stringWithFormat:@"Connect to the “%@” network to begin your journey into The System.",wifiname];
    NSString *defaultMessage = @"You must join a Wi-Fi network with Internet, and then click Continue / I’m Connected.";
    
    wifiMessage.attributedText = GetFormattedText(AppDelegate().showVenueWifi ? messageAtVenue : defaultMessage);
    
    [AppDelegate() formatTextField:wifiMessage];
}

- (void) _handleChooseVenue
{
    [AppDelegate() transitionToViewController:AppDelegate().welcomeAndInfoViewController];
}

/////////////////////////////////////////////////////////////
///////////////////// NETWORK CHECKS ////////////////////////
/////////////////////////////////////////////////////////////

- (void) _checkNetworkFromWifi
{
    [self updateNetworkInformation];
    
    // If before show and connected to wifi & internet (prelim downloading)
    BOOL case1 = AppDelegate().connectedToInternet && AppDelegate().connectedToAWifiNetwork;
    
    // If night of show & connected to correct wifi (in venue)
    BOOL case2 = AppDelegate().showVenueWifi && AppDelegate().connectedToCorrectWifiNetwork;
    
    if (case1 || case2)
    {
        if (AppDelegate().showVenueWifi)
        {
            if (AppDelegate().connectedToCorrectWifiNetwork)
            {
                [self moveOnFromWifi];
            }
            else
            {
                [self _deployWifiAlert];
            }
        }
        else
        {
            [self moveOnFromWifi];
        }
    }
    else
    {
        [self _deployWifiAlert];
    }
}

- (void) updateNetworkInformation
{
    NSLog(@"[Wifi Screen] Checking wifi ... ");
    
    // Set specific SSID name
    wifiname = [[AppDelegate().appShowInfo[@"locations"] objectForKey:[userDefaults objectForKey:@"location"]] objectForKey:@"ssid"];
    
    NSLog(@"[Wifi Screen] Wifi this device is supposed to be connected to: %@", wifiname);
    
    // Check connections to wifi and internet
    [self _checkWifiConnection];
    [self _checkInternetConnection];
}

- (BOOL) _checkWifiConnection
{
    // If on the iOS simulator - set all to true and move on
    UIDevice *currentDevice = [UIDevice currentDevice];
    if ([[currentDevice model] isEqualToString:@"iPhone Simulator"] || [[currentDevice model] isEqualToString:@"iPad Simulator"] )
    {
        NSLog(@"[Wifi Screen] iPhone Simulator ... don't check for wifi");
        AppDelegate().connectedToCorrectWifiNetwork = YES;
        AppDelegate().connectedToInternet = YES;
        AppDelegate().connectedToAWifiNetwork = YES;
    }
    
    // If device is a piece of hardware
    else
    {
        AppDelegate().connectedToAWifiNetwork = NO;
        AppDelegate().connectedToCorrectWifiNetwork = NO;
        
        // Get wifi information
        NSArray* supportedInterfaces = CFBridgingRelease(CNCopySupportedInterfaces());
		
		// Check all interfaces
		for (NSString* interfaceName in supportedInterfaces)
		{
			// Get the dictionary containing the captive network infomation
			NSDictionary* captiveNtwrkDict = CFBridgingRelease(CNCopyCurrentNetworkInfo((__bridge CFStringRef)interfaceName));
			NSString* ssid = [captiveNtwrkDict objectForKey:@"SSID"];
			if (ssid)
			{
				AppDelegate().connectedToAWifiNetwork = YES;
				
                NSString *location = [userDefaults objectForKey:@"location"];
                BOOL wifiRequired = [AppDelegate().appShowInfo[@"locations"][location][@"wifi-required"] boolValue];

                if (wifiRequired)
                {
                    NSLog(@"[Wifi Screen] Wifi required for %@.", location);
                    if ([ssid isEqualToString:wifiname])
                    {
                        // We're done looking--bail out.
                        AppDelegate().connectedToCorrectWifiNetwork = YES;
                        [TestFlight passCheckpoint:[NSString stringWithFormat:@"[Wifi View] Device is connected to the correct wifi network (%@).", wifiname]];
                        break;
                    }
                }
                else
                {
                    NSLog(@"[Wifi Screen] Wifi not required for %@.", ssid);
                    AppDelegate().connectedToCorrectWifiNetwork = YES;
                    break;
                }
			}
		}
		
		if (!AppDelegate().connectedToAWifiNetwork)
		{
			NSLog(@"Device not connected to a wifi network.");
            [TestFlight passCheckpoint:@"[Wifi View] Device is not connected to a wifi network."];
		}
		else if (!AppDelegate().connectedToCorrectWifiNetwork)
		{
			NSLog(@"Device not connected to the correct wifi network.");
            [TestFlight passCheckpoint:@"[Wifi View] Device is not connected to the correct wifi network."];
		}
    }
    
    return AppDelegate().connectedToAWifiNetwork;
}

- (BOOL) _checkInternetConnection
{
    UIDevice *currentDevice = [UIDevice currentDevice];
    if (![[currentDevice model] isEqualToString:@"iPhone Simulator"] || ![[currentDevice model] isEqualToString:@"iPad Simulator"] )
    {
        // Ping Google and see if a resonse is received
        NSURLConnection *urlConnection;
        urlConnection= [[NSURLConnection alloc] init];
        NSURL *url = [[NSURL alloc] initWithString:@"http://www.google.com"];
        NSURLRequest *someRequest = [[NSURLRequest alloc] initWithURL:url cachePolicy:
                                     NSURLRequestReloadIgnoringLocalCacheData timeoutInterval:8.0];
        
        // If positive response
        if ([NSURLConnection sendSynchronousRequest:someRequest returningResponse:nil error:nil])
        {
            NSLog(@"[Wifi Screen] Device is connected to the internet.");
            [TestFlight passCheckpoint:@"[Wifi View] Device is connected to internet."];
            AppDelegate().connectedToInternet = YES;
            return YES;
        }
        else
        {
            NSLog(@"[Wifi Screen] Device is not connected to the internet.");
            [TestFlight passCheckpoint:@"[Wifi View] Device is not connected to internet."];
            AppDelegate().connectedToInternet = NO;
            return NO;
        }
    }
    else
    {
        NSLog(@"[Wifi Screen] Running on simulator ... don't check for internet.");
    }
    return YES;
}

/////////////////////////////////////////////////////////////
/////////////////////// NAVIGATION //////////////////////////
/////////////////////////////////////////////////////////////

- (void) moveOnFromWifi
{
    [AppDelegate() navigateUser];
}

@end
