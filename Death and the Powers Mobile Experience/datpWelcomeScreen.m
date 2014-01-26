//
//  datpWelcomeScreen.m
//  Death and the Powers Mobile Experience
//
//  Created by Garrett Parrish on 11/21/13.
//  Copyright (c) 2013 Opera of the Future. All rights reserved.
//

#import "datpWelcomeScreen.h"
#import "TestFlight.h"
@interface datpWelcomeScreen ()
{
    NSString *wifiname;
}
@end

@implementation datpWelcomeScreen

@synthesize continueBtn;

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self)
    {
    }
 
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
 
    [TestFlight passCheckpoint:@"Welcome Screen"];
    
    continueBtn.enabled = YES;
    
    wifiname = @"Parrish's Network";
    
    // if connected
    if ([self checkWifiName])
    {
        NSLog(@"You may continue.");
        continueBtn.enabled = YES;
    }

}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (BOOL) checkWifiName
{
    UIDevice *currentDevice = [UIDevice currentDevice];
    if ([[currentDevice model] isEqualToString:@"iPhone Simulator"] || [[currentDevice model] isEqualToString:@"iPad Simulator"] )
    {
        NSLog(@"iPhone Simulator ... don't check for wifi");
        return TRUE;
    }
    else
    {
        // getWifiInfo
        CFArrayRef myArray = CNCopySupportedInterfaces();
        
        // Get the dictionary containing the captive network infomation
        CFDictionaryRef captiveNtwrkDict = CNCopyCurrentNetworkInfo(CFArrayGetValueAtIndex(myArray, 0));
        NSLog(@"Information of the network this device is connected to: %@", captiveNtwrkDict);
        
        NSDictionary *dict = (__bridge NSDictionary*) captiveNtwrkDict;
        NSString* ssid = [dict objectForKey:@"SSID"];
        
        
        NSLog(@"Network name: %@",ssid);
        
        if ([ssid isEqualToString:wifiname])
        {
            NSLog(@"You're connected to what you should be!");
            return TRUE;
        }
        
        else
        {
            NSLog(@"You're not connected to what you should be!");
            return FALSE;
        }
    }
}


@end
