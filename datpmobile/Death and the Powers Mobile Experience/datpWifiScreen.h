//  datpWelcomeScreen.h
//  Death and the Powers Mobile Experience
//
//  Created by Garrett Parrish on 11/21/13.
//  Copyright (c) 2013 Opera of the Future. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <CFNetwork/CFNetwork.h>
#import <SystemConfiguration/SystemConfiguration.h>
#import <SystemConfiguration/CaptiveNetwork.h>

@interface datpWifiScreen : UIViewController

- (void) updateNetworkInformation;

- (IBAction) moveOnFromWifi;

@end

