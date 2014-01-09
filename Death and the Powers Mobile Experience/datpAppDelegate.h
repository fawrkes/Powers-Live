//
//  datpAppDelegate.h
//  Death and the Powers Mobile Experience
//
//  Created by Garrett Parrish on 11/11/13.
//  Copyright (c) 2013 Opera of the Future. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <FacebookSDK/FacebookSDK.h>
#import "SRWebSocket.h"
#import "datpWifiScreen.h"
#import "datpFacebookLoginViewController.h"
#import "datpProductionContentDownload.h"
#import "datpViewController.h"
#import "datpWelcomeAndInfo.h"
#import "datpHoldingView.h"
#import "datpLaunchImage.h"

extern NSString *const DATPShowInfoDidLoadNotification; // nil

@class datpAppDelegate;

/*!
 *  Gets the global application delegate.
 */
datpAppDelegate* AppDelegate();

/*!
 *  Returns a formatted version of the provided string, formatting any known keywords such as
 *  "Death and the Powers" in italics.
 */

NSAttributedString* GetFormattedText(NSString*);

@interface datpAppDelegate : UIResponder <UIApplicationDelegate, SRWebSocketDelegate, UIAlertViewDelegate>

// Main window
@property (strong, nonatomic) UIWindow *window;

// Show info (cue list)
@property NSDictionary *appShowInfo;
@property(nonatomic) NSDictionary *cueList;
- (void) pullDownShowInfo:(int)contentVersion;

@property NSString *assetHost;
@property NSString *assetHostPath;

// Wifi settings
@property BOOL connectedToInternet;
@property BOOL connectedToAWifiNetwork;
@property BOOL connectedToCorrectWifiNetwork;

// Device info
@property BOOL smallPhone;
@property BOOL ios6;

// Show info
@property NSString *clientWebViewUrl;
@property int currentShowContentVersion;

// User Defaults
@property NSMutableDictionary *deviceInfo;
- (void) updateUserDefaults;

// Show-dependent navigation decisions
@property BOOL showVenueWifi;
@property BOOL showHoldingScreen;

// View characteristics
@property BOOL ipad;
@property UIStoryboard *storyBoard;

@property UIFont *mainTextFont;
@property UIFont *mainTextItalicFont;

@property float viewWidth;
@property float viewHeight;

@property UIColor *buttonColorNormal;
@property UIColor *buttonColorPressed;

- (void) transitionToViewController:(UIViewController*)viewController;

// UI Standardizations
- (void) formatButton: (UIButton *) button;
- (void) formatTextField: (UITextView *) textView;
- (void) formatProgressBar: (UIProgressView *) progressView;
- (void) formatLabel: (UILabel *) label;

// View controllers
@property datpWelcomeAndInfo *welcomeAndInfoViewController;
@property datpWifiScreen *wifiViewController;
@property datpFacebookLoginViewController *facebookViewController;
@property datpProductionContentDownload *productionContentViewController;
@property datpHoldingView *holdingViewController;
@property datpViewController *mainShowViewController;
@property datpLaunchImage *launchImageController;

@end
