//
//  datpViewController.h
//  Death and the Powers Mobile Experience
//
//  Created by Garrett Parrish on 11/11/13.
//  Copyright (c) 2013 Opera of the Future. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "SRWebSocket.h"
#import <MediaPlayer/MediaPlayer.h>
#import <AVFoundation/AVFoundation.h>
#import <CoreFoundation/CoreFoundation.h>
#import <SystemConfiguration/SystemConfiguration.h>
#import <SystemConfiguration/CaptiveNetwork.h>

@interface datpViewController : UIViewController

- (void) interpretSocketMessage:(id) message;
- (void) loadShowWebPage;

@end