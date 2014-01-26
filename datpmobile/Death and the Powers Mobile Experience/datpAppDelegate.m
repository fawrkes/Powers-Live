//
//  datpAppDelegate.m
//  Death and the Powers Mobile Experience
//
//  Created by Garrett Parrish on 11/11/13.
//  Copyright (c) 2013 Opera of the Future. All rights reserved.
//

#import "datpAppDelegate.h"
#import "datpFacebookLoginViewController.h"
#import "TestFlight.h"
#import "datpViewController.h"
#import "datpWifiScreen.h"
#import "datpHoldingView.h"

NSString* const DATPShowInfoDidLoadNotification = @"DATPShowInfoDidLoadNotification";

NSString* const WEBSOCKETURL = @"ws://oscar.media.mit.edu:80";

static const int MAX_SOCKETCONNECTIONATTEMPTS = 5;

datpAppDelegate* AppDelegate()
{
    return (datpAppDelegate*) [[UIApplication sharedApplication] delegate];
}

NSAttributedString* GetFormattedText(NSString* text)
{
    NSMutableAttributedString* attributedText = [[NSMutableAttributedString alloc] initWithString:text attributes:@{NSFontAttributeName : AppDelegate().mainTextFont}];
    [attributedText setAttributes:@{NSFontAttributeName : AppDelegate().mainTextItalicFont} range:[text rangeOfString:@"Death and the Powers"]];
    return attributedText;
}

static NSString* DictionaryToJSON (NSDictionary* dict)
{
    NSError* error = nil;
    NSData* data = [NSJSONSerialization dataWithJSONObject:dict options:0 error:&error];
    if (error)
    {
        NSLog(@"[App Delegate] Error converting dictionary to JSON: %@\n", error);
    }
    return [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
}

static NSDictionary* JSONToDictionary (NSString* json)
{
    NSError* error = nil;
    id dict = [NSJSONSerialization JSONObjectWithData:[json dataUsingEncoding:NSUTF8StringEncoding] options:0 error:&error];
    if (error)
    {
        NSLog(@"[App Delegate] Error converting JSON to dictionary: %@\n", error);
    }
    return dict;
}

@interface datpAppDelegate () <SRWebSocketDelegate, UIAlertViewDelegate>

@property UIViewController *currentActiveViewController;
@property BOOL transitionInProgress;

@end

@implementation datpAppDelegate
{
    // Socket
    SRWebSocket *datpSocket;
    BOOL socketOpen;
    NSTimer *socketCheck;
    
    // Content version
    int deviceContentVersion;
    NSString *showInfoUrl;
    
    // Device info
    NSUserDefaults *userDefaults;
    
    // Socket connection attempts
    int socketConnectionAttempts;
    
    // Wifi Alert
    BOOL alertPresented;
}

@synthesize appShowInfo, cueList, currentShowContentVersion;
@synthesize assetHostPath, assetHost, clientWebViewUrl, deviceInfo;
@synthesize transitionInProgress, currentActiveViewController;

/////////////////////////////////////////////////////////////
//////////////////// GENERAL APP METHODS ////////////////////
/////////////////////////////////////////////////////////////

- (void) applicationWillResignActive: (UIApplication*) aApplication
{
    [datpSocket close];
    [self updateUserDefaults];
    [TestFlight passCheckpoint:@"[App Delegate] Application closed."];
}

- (void) applicationDidBecomeActive:(UIApplication *)application
{
    userDefaults = [NSUserDefaults standardUserDefaults];
    
    [TestFlight passCheckpoint:@"[App Delegate] Application became active."];
    
    // Set brightness of screen to high
    [[UIScreen mainScreen] setBrightness:BRIGHT];
    
    [self updateUserDefaults];
    
    // Always update content version
    [self _requestContentVersion];
}

- (BOOL) application:(UIApplication *)application willFinishLaunchingWithOptions: (NSDictionary *) launchOptions
{
    userDefaults = [NSUserDefaults standardUserDefaults];
    
    // Set brightness of screen to high
    [[UIScreen mainScreen] setBrightness:BRIGHT];
    
    // Start Testflight
    [TestFlight takeOff:@"a0eacfa5-5071-4ea9-a4dc-46a6e8c6ae4c"];
    
    NSLog(@"[App Delegate] User Defaults: %@", [userDefaults dictionaryRepresentation]);
    
    // Only copy files from bundle to documents if it hasn't been done already
    if (![userDefaults objectForKey:@"copied_resources_to_documents"])
    {
        NSLog(@"[App Delegate] Copying files from resources to documents.");
        [self _copyFilesFromResourcesToDocuments];
    }
    
    // Generate UUID if needed
    [self _generateUUIDIfNeeded];
    
    // Set UI element colors
    [self _initializeUIAttributes];
    
    // Initialize device settings (iPad vs. iPhone)
    [self _initalizeDeviceSpecificSettings];
    
    // Make all view controllers after storybaord is identified
    [self _instantiateAllViewControllers];
    
    // Load cached cue list into memory
    [self _loadCachedCueList];

    // Set base content version
    [self _setBaseContentVersion];

    // Update userdefaults
    [self updateUserDefaults];

    // Instantiate facebook profile picture view
    [FBProfilePictureView class];
    
    return YES;
}

- (void) applicationDidFinishLaunching:(UIApplication *)application
{
    [self _openWebSocket];
    [self _startBackgroundSocketCheck];
}

/////////////////////////////////////////////////////////////
/////////////////////// CUE LIST ////////////////////////////
/////////////////////////////////////////////////////////////

- (NSString*) _cueListPath
{
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentsDirectory = [paths objectAtIndex:0];
    return [documentsDirectory stringByAppendingPathComponent:@"default_cuelist.json"];
}

- (void) setCueList:(NSDictionary *)c
{
    cueList = c;
    
    NSString* json = DictionaryToJSON(cueList);
    NSError* error = NULL;
    [json writeToFile:[self _cueListPath] atomically:YES encoding:NSUTF8StringEncoding error:&error];
    if (error)
    {
        NSLog(@"[App Delegate] Error saving cue list: %@\n", error);
    }
}

- (void) _loadCachedCueList
{
    // Load the last cue list
    NSLog(@"[App Delegate] Loading cue list to user defaults");
    NSError* error = NULL;
    NSString *myJSON = [[NSString alloc] initWithContentsOfFile:[self _cueListPath] encoding:NSUTF8StringEncoding error:&error];
    if (error)
    {
        NSLog(@"[App Delegate] Error loading cue list: %@\n", error);
        cueList = [NSDictionary dictionary];
    }
    else
    {
        cueList = JSONToDictionary(myJSON);
    }
}

/////////////////////////////////////////////////////////////
//////////////////////// ASSETS /////////////////////////////
/////////////////////////////////////////////////////////////

- (void) _copyFilesFromResourcesToDocuments
{
    // Copy files from bundle to documents
    NSString  *bundleFilePath = [[NSBundle mainBundle] resourcePath];
    NSArray   *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString  *documentsDirectory = [paths objectAtIndex:0];
    
    NSArray* preloadedResources = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:bundleFilePath error:NULL];
    
    // Copy the cue list first on main thread before copying all other files on background thread
    [[NSFileManager defaultManager] copyItemAtPath:[bundleFilePath stringByAppendingPathComponent:@"default_cuelist.json"] toPath:[self _cueListPath] error:nil];
    
    dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
    
    dispatch_async(queue, ^(){
        
        for (NSString* obj in preloadedResources)
        {
            [[NSFileManager defaultManager] copyItemAtPath:[bundleFilePath stringByAppendingPathComponent:obj] toPath:[documentsDirectory stringByAppendingPathComponent:obj] error:nil];
        }
    });
    
    [userDefaults setObject:@"true" forKey:@"copied_resources_to_documents"];
}

/////////////////////////////////////////////////////////////
////////////////////// FACEBOOK /////////////////////////////
/////////////////////////////////////////////////////////////

- (void) navigateUser
{
    NSDictionary *defaults = [userDefaults dictionaryRepresentation];
    
    NSLog(@"Navigating User");
    
    // Get network information
    [self.wifiViewController updateNetworkInformation];
    
    // Redirected to correct screen based on certain conditions
    if (!defaults[@"location"])
    {
        [self transitionToViewController:self.welcomeAndInfoViewController];
    }
    else if (!self.connectedToAWifiNetwork ||
             !self.connectedToInternet ||
             (self.showVenueWifi && !self.connectedToCorrectWifiNetwork))
    {
        NSLog(@"[App Delegate Redirect] Not connected to internet or wifi or supposed to show wifi. Going to wifi.");
        [self transitionToViewController:self.wifiViewController];
    }
    else if (!defaults[@"downloaded_facebook_photos"] && !defaults[@"skipped_facebook"])
    {
        NSLog(@"[App Delegate Redirect] Haven't chose what to do about facebook. Going to facebook.");
        [self transitionToViewController:self.facebookViewController];
    }
    else if ([[userDefaults objectForKey:@"latest_content_version"] isEqualToString:@"false"])
    {
        NSLog(@"[App Delegate Redirect] Device doesn't have latest content version. Going to production content download.");
        [self transitionToViewController:self.productionContentViewController];
    }
    else if (AppDelegate().showHoldingScreen)
    {
        NSLog(@"[App Delegate Redirect] Showing holding screen.");
        [self transitionToViewController:self.holdingViewController];
    }
    else
    {
        NSLog(@"[App Delegate Redirect] Skipping holding screen. Moving straight to show.");
        [self transitionToViewController:self.mainShowViewController];
    }
}

/////////////////////////////////////////////////////////////
////////////////////// FACEBOOK /////////////////////////////
/////////////////////////////////////////////////////////////

- (BOOL) application:(UIApplication *)application openURL:(NSURL *)url sourceApplication:(NSString *)sourceApplication annotation:(id)annotation
{
    // Call FBAppCall's handleOpenURL:sourceApplication to handle Facebook app responses
    BOOL wasHandled = [FBAppCall handleOpenURL:url sourceApplication:sourceApplication];
    
    return wasHandled;
}

/////////////////////////////////////////////////////////////
/////////////////////// WEB SOCKETS /////////////////////////
/////////////////////////////////////////////////////////////

- (void) webSocket:(SRWebSocket *)webSocket didReceiveMessage:(id)message
{
    NSData *messageData = [(NSString *)message dataUsingEncoding:NSUTF8StringEncoding];
    NSDictionary *messageJSON = [NSJSONSerialization
                                 JSONObjectWithData:messageData
                                 options:NSJSONReadingMutableContainers
                                 error:nil];
    
    // Log the incoming message
    NSLog(@"[App Delegate] Incoming socket message: %@", messageJSON);
    
    // Get arguments
    NSDictionary *arguments = messageJSON[@"arguments"];
    NSString *address = messageJSON[@"address"];
        
    // If response contains content message
    if ([address isEqualToString:@"/content_version"])
    {
        // Boolean of whether or not to show holding screen
        self.showHoldingScreen = [arguments[@"holding_screen"] boolValue];
        
        // Boolean of whether or not to show wifi screen
        self.showVenueWifi = [arguments[@"venue_wifi"] boolValue];
        
        // Set latest show content version
        currentShowContentVersion = [arguments[@"version"] integerValue];
        
        // Set current show content version
        [userDefaults setObject:arguments[@"version"]  forKey:@"show_content_version"];
        
        NSLog(@"[App Delegate] Lastest show content version: %i", currentShowContentVersion);
        
        // If device content version is the same
        BOOL deviceHasLatest = [[userDefaults objectForKey:@"device_content_version"] integerValue] == [[userDefaults objectForKey:@"show_content_version"] integerValue];
        NSString *latest = deviceHasLatest ? @"true" : @"false";
        [userDefaults setObject:latest forKey:@"latest_content_version"];
        
        [TestFlight passCheckpoint:[NSString stringWithFormat:@"[App Delegate] Show content version: %d Device content version: %@", currentShowContentVersion, [userDefaults objectForKey:@"device_content_version"]]];
        
        // Get latest show information
        showInfoUrl = arguments[@"cue_list"];
        
        // Get show info
        [self pullDownShowInfo:currentShowContentVersion];
        
        // Webview Override
        if ([arguments[@"web_view"] boolValue])
        {
            [self _manualOverrideToWebView];
        }
    }
    
    // If message is a trigger
    if ([address isEqualToString:@"/trigger"])
    {
        // Send cue number back to server (for diagnostics)
        NSArray *cueKey = messageJSON[@"arguments"];
        NSString *currentCue = [NSString stringWithFormat:@"%@", [cueKey lastObject]];
        NSString *cueToServer = [NSString stringWithFormat:@"{\"address\":\"/status\",\"arguments\":{\"cueNumber\":%@}}", currentCue];

        [self _sendMessageToServer:cueToServer];
        
        [self.mainShowViewController performSelectorOnMainThread:@selector(interpretSocketMessage:) withObject:message waitUntilDone:NO];
    }
    
    // Total show override
    if ([address isEqualToString:@"/web_view"])
    {
        [self _manualOverrideToWebView];
    }
}

- (void) _manualOverrideToWebView
{
    [deviceInfo setValue:@"true" forKey:@"web_view"];
    [self updateUserDefaults];
    
    NSLog(@"[App Delegate] Webview Override");
    [TestFlight passCheckpoint:@"[App Delegate] Manual override to web view."];
    
    // Check for new production content and
    NSLog(@"[App Delegate] Device not up to date - updating content version");
    [self.productionContentViewController checkForNewProductionContent];
}

- (void) _openWebSocket
{
    NSLog(@"[App Delegate] Attempting to open socket.");
    
    // Instantiate and open
    datpSocket = [[SRWebSocket alloc] initWithURL:[[NSURL alloc] initWithString:WEBSOCKETURL]];
    datpSocket.delegate = self;
    [datpSocket open];
    socketOpen = YES;
}

- (void) webSocketDidOpen:(SRWebSocket *)webSocket
{
    NSLog(@"[App Delegate] Socket opened. Connected to: %@", WEBSOCKETURL);
    [TestFlight passCheckpoint:[NSString stringWithFormat:@"[App Delegate] Socket successfully connected to %@.", WEBSOCKETURL]];

    // Reset socket connection attempts
    socketConnectionAttempts = 0;
    
    [self updateUserDefaults];

    // Send device information to server
    [self _sendDeviceInfoToServer];
}

- (void) webSocket:(SRWebSocket *)webSocket didFailWithError:(NSError *)error
{
    NSLog(@"[App Delegate] Socket failed.");
    [TestFlight passCheckpoint:[NSString stringWithFormat:@"[App Delegate] Socket failed when connecting to %@.", WEBSOCKETURL]];

    // Increment socketConnectionAttempts
    ++socketConnectionAttempts;
    
    socketOpen = NO;
    [datpSocket close];
}

- (void) webSocket:(SRWebSocket *)webSocket didCloseWithCode:(NSInteger)code reason:(NSString *)reason wasClean:(BOOL)wasClean
{
    NSLog(@"[App Delegate] Socket closed.");
    [TestFlight passCheckpoint:@"[App Delegate] Socket closed."];
    
    socketOpen = NO;
}

- (void) _sendMessageToServer: (NSString *) update
{
    // Put in a check to try to parse the update as JSON before sending
    if (datpSocket.readyState == SR_OPEN)
    {
        [datpSocket send:update];
    }
}

- (void) _startBackgroundSocketCheck
{
    NSLog(@"[App Delegate] Starting socket check.");
    
    float socketConnectionCheckDelay = 1.0;
    socketCheck = [NSTimer scheduledTimerWithTimeInterval:socketConnectionCheckDelay
                                                   target:self
                                                 selector:@selector(_backgroundSocketCheck)
                                                 userInfo:nil
                                                  repeats:YES];
}

- (void) _backgroundSocketCheck
{
    if (!socketOpen)
    {
        [self _openWebSocket];
    }
    
    if (socketConnectionAttempts > MAX_SOCKETCONNECTIONATTEMPTS)
    {
        if (!alertPresented)
        {
            [self _deployWifiAlert];
        }
    }
}

- (void) _deployWifiAlert
{
    NSLog(@"[App Delegate] Wifi alert deployed.");
    
    [[[UIAlertView alloc] initWithTitle: @"Can't connect to Powers Live."
                                                        message: @"If you are on a non-cellular device, please connect to a Wi-Fi network with Internet access."
                                                       delegate: self
                                              cancelButtonTitle:@"Okay"
                                              otherButtonTitles: nil]

     show];

    alertPresented = YES;
}

- (void) alertView:(UIAlertView *)alertView didDismissWithButtonIndex:(NSInteger)buttonIndex
{
    [self _wifiAlertDismissed];
}

- (void) _wifiAlertDismissed
{
    NSLog(@"[App Delegate] Wifi alert dismissed.");
    alertPresented = NO;
    socketConnectionAttempts = 0;
}

/////////////////////////////////////////////////////////////
////////////////////////// SHOW INFO ////////////////////////
/////////////////////////////////////////////////////////////

- (void) pullDownShowInfo:(int)showContentVersion
{
    // Get the current show information
    NSLog(@"[App Delegate] Pulling down show information.");
    
    NSString *showInfoPrefix = (showContentVersion < 10) ? @"0" : @"";
    NSString *showInfoString = [NSString stringWithFormat:@"%@%@%i.json", showInfoUrl, showInfoPrefix, showContentVersion];
    
    NSLog(@"[App Delegate] Pulling show info from: %@", showInfoString);
    [TestFlight passCheckpoint:[NSString stringWithFormat:@"[App Delegate] Pulled down show info from: %@", showInfoString]];
     
    NSData *showInfoData = [[NSData alloc] initWithContentsOfURL:[NSURL URLWithString:showInfoString]];
    
    NSError *err;
    // If it go the data
    if (showInfoData)
    {
        NSDictionary *showInfo = [NSJSONSerialization
                                  JSONObjectWithData:showInfoData
                                  options:NSJSONReadingMutableContainers
                                  error:&err];
        if (err)
        {
            NSLog(@"[App Delegate] Show info error: %@", err);
            [TestFlight passCheckpoint:@"[App Delegate] Error getting show info."];
        }
        else if (!appShowInfo || ![appShowInfo isEqualToDictionary:showInfo])
        {
            // Set global information for all views
            appShowInfo = showInfo;
            
            // Init necessary information for running the show
            [self initAssetPaths];
            [self initWebViewUrl];
            [[NSNotificationCenter defaultCenter] postNotificationName:DATPShowInfoDidLoadNotification object:self];
        }
    }
    else
    {
        NSLog(@"[App Delegate] Unable to get show info.");
        [TestFlight passCheckpoint:@"[App Delegate] Failed to pull down show info."];
    }
}

- (void) initAssetPaths
{
    assetHost = appShowInfo[@"asset-host"];
    assetHostPath = appShowInfo[@"asset-path"];
}

- (void) initWebViewUrl
{
    clientWebViewUrl = appShowInfo[@"client-page"];
}

/////////////////////////////////////////////////////////////
////////////////////// CONTENT VERSION //////////////////////
/////////////////////////////////////////////////////////////

- (void) _requestContentVersion
{
    NSLog(@"[App Delegate] Updating content version");
    NSString *contentVersionRequest = @"{\"address\":\"/content_version\"}";
    [self _sendMessageToServer:contentVersionRequest];
}

- (void) _setBaseContentVersion
{
    // Set base content version to start and set device to that
    int baseContentVersion = 14;
    
    [TestFlight passCheckpoint:[NSString stringWithFormat:@"[Show View] Base content version preloaded on device is: %i.", baseContentVersion]];
    
    [userDefaults setObject:[NSNumber numberWithInt:baseContentVersion] forKey:@"base_content_version"];
    
    // Set default device content version
    if (![userDefaults objectForKey:@"device_content_version"])
    {
        [userDefaults setObject:[NSNumber numberWithInteger:baseContentVersion] forKey:@"device_content_version"];
        
        [deviceInfo setValue:[NSNumber numberWithInteger:baseContentVersion] forKey:@"device_content_version"];
        [self updateUserDefaults];
    }
}

/////////////////////////////////////////////////////////////
///////////////////// DEVICE INFO ///////////////////////////
/////////////////////////////////////////////////////////////

- (void) _generateUUIDIfNeeded
{
    // Only initizlize if a uuid hasn't been generated yet
    if ([userDefaults objectForKey:@"uuid"])
    {
        NSLog(@"[App Delegate] Not generating a new UUID");
        NSLog(@"[App Delegate] Current UUID: %@", [userDefaults objectForKey:@"uuid"]);
    }
    else
    {
        NSLog(@"[App Delegate] Generating UUID");
        CFStringRef UUID = CFUUIDCreateString(NULL, CFUUIDCreate(NULL));
        NSString *uuidString = (__bridge NSString *)(UUID);
        [userDefaults setObject:uuidString forKey:@"uuid"];
        NSLog(@"[App Delegate] New UUID: %@", [userDefaults objectForKey:@"uuid"]);
    }
    [TestFlight passCheckpoint:[NSString stringWithFormat:@"[App Delegate] UUID: %@", [userDefaults objectForKey:@"uuid"]]];
}

- (void) _initalizeDeviceSpecificSettings
{
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad)
    {
        NSLog(@"[App Delegate] This device is an iPad");
        self.ipad = YES;
        self.storyBoard = [UIStoryboard storyboardWithName:@"Main_iPad" bundle:nil];
        self.mainTextFont = [UIFont systemFontOfSize:24.0];
        self.mainTextItalicFont = [UIFont italicSystemFontOfSize:24.0];
    }
    else
    {
        NSLog(@"[App Delegate] This device is an iPhone or iPod Touch");
        self.storyBoard = [UIStoryboard storyboardWithName:@"Main_iPhone" bundle:nil];
        self.mainTextFont =  [UIFont systemFontOfSize:16.0];
        self.mainTextItalicFont = [UIFont italicSystemFontOfSize:16.0];
        
        // set if device is 3.5" or 4"
        self.smallPhone = [[UIScreen mainScreen] bounds].size.height < 500 ? YES : NO;
    }
    
    // Get and set ios version
    NSArray *vComp = [[UIDevice currentDevice].systemVersion componentsSeparatedByString:@"."];
    
    BOOL ios7 = [[vComp objectAtIndex:0] intValue] >= 7;
    int iosVersion = ios7 ? 7 : 6;
    self.ios6 = ios7 ? NO : YES;
    
    [deviceInfo setValue:[NSNumber numberWithInteger:iosVersion] forKey:@"ios_version"];
}

- (void) _sendDeviceInfoToServer
{
    deviceInfo = [[NSMutableDictionary alloc] init];
    
    UIDevice *currentDevice = [UIDevice currentDevice];
    [deviceInfo setValue:[currentDevice model] forKey:@"device_type"];
    [deviceInfo setValue:[currentDevice localizedModel] forKey:@"localized_model"];
    [deviceInfo setValue:[currentDevice systemVersion] forKey:@"system_version"];
    [deviceInfo setValue:[currentDevice systemName] forKey:@"system_name"];
    [deviceInfo setValue:[userDefaults objectForKey:@"uuid"] forKey:@"uuid"];
    [deviceInfo setValue:[userDefaults objectForKey:@"device_content_version"] forKey:@"device_content_version"];
    
    NSString* message = DictionaryToJSON(@{@"address" : @"/device",
                                           @"arguments" : deviceInfo});
    [self _sendMessageToServer:message];
}

- (void) updateUserDefaults
{
    [userDefaults synchronize];
    [self _sendDeviceInfoToServer];
}

/////////////////////////////////////////////////////////////
//////////////// VIEW CONTROLLER INSTANTIATIONS /////////////
/////////////////////////////////////////////////////////////

- (void) _instantiateAllViewControllers
{
    NSLog(@"[App Delegate] Instantiating all view controllers");
    self.welcomeAndInfoViewController = (datpWelcomeAndInfo *) [self.storyBoard instantiateViewControllerWithIdentifier:@"welcomeAndInfo"];
    self.wifiViewController = (datpWifiScreen *)[self.storyBoard instantiateViewControllerWithIdentifier:@"wifi"];
    self.facebookViewController = (datpFacebookLoginViewController *)[self.storyBoard instantiateViewControllerWithIdentifier:@"facebook"];
    self.productionContentViewController = (datpProductionContentDownload *)[self.storyBoard instantiateViewControllerWithIdentifier:@"productionContent"];
    self.holdingViewController = (datpHoldingView *)[self.storyBoard instantiateViewControllerWithIdentifier:@"holdingView"];
    self.mainShowViewController = (datpViewController *)[self.storyBoard instantiateViewControllerWithIdentifier:@"showView"];
    self.launchImageController = (datpLaunchImage *)self.window.rootViewController;
}

- (void) transitionToViewController:(UIViewController*)to
{
    if (self.transitionInProgress)
    {
        NSLog(@"Transition in progress going from view controller %@ to %@", self.currentActiveViewController, to);
        NSLog(@"%@",[NSThread callStackSymbols]);
        return;
    }
    
    if (self.currentActiveViewController == to)
    {
        return;
    }
    self.transitionInProgress = YES;
    self.currentActiveViewController = to;
    
    void (^present)() = ^() {
        [self.window.rootViewController presentViewController:to animated:NO completion:^() {
            self.transitionInProgress = NO;
        }];
    };
    
    if (self.window.rootViewController.presentedViewController)
    {
        [self.window.rootViewController dismissViewControllerAnimated:NO completion:present];
    }
    else
    {
        present();
    }
}

/////////////////////////////////////////////////////////////
///////////////////// UI STANDARDIZATIONS ///////////////////
/////////////////////////////////////////////////////////////

- (void) formatButton: (UIButton *) button
{
    button.titleLabel.font = self.mainTextFont;
    [button setTitleColor:self.buttonColorNormal forState:UIControlStateNormal];
    [button setTitleColor:self.buttonColorPressed forState:UIControlStateHighlighted];
    button.reversesTitleShadowWhenHighlighted = TRUE;
    button.showsTouchWhenHighlighted = FALSE;
}

- (void) formatTextField: (UITextView *) textView
{
    textView.textAlignment = NSTextAlignmentCenter;
    textView.editable = NO;
    textView.textColor = [UIColor whiteColor];
    textView.backgroundColor = [UIColor clearColor];
    textView.userInteractionEnabled = NO;
}

- (void) formatLabel: (UILabel *) label
{
    label.font = self.mainTextFont;
    label.textColor = [UIColor whiteColor];
    label.backgroundColor = [UIColor clearColor];
    label.userInteractionEnabled = NO;
    label.textAlignment = NSTextAlignmentCenter;
}

- (void) formatProgressBar: (UIProgressView *) progressView
{
    progressView.progress = 0.0;
}

- (void) _initializeUIAttributes
{
    // Colors
    self.buttonColorNormal = [UIColor colorWithRed:0.0 / 255.0 green:81.0 / 255.0 blue:255.0 / 255.0 alpha:1.0];
    self.buttonColorPressed = [UIColor whiteColor];
    
    // Programatically position UI elements
    self.viewWidth = [[UIScreen mainScreen] bounds].size.width;
    self.viewHeight = [[UIScreen mainScreen] bounds].size.height;
}

/////////////////////////////////////////////////////////////
///////////////////// UTILITY FUNCTIONS /////////////////////
/////////////////////////////////////////////////////////////

- (NSDictionary *) dictionizeJsonUrl: (NSURL *) url
{
    NSData *jsonData = [[NSData alloc] initWithContentsOfURL:url];
    
    NSError *err;
    NSDictionary *jsonDict = [NSJSONSerialization
                              JSONObjectWithData:jsonData
                              options:NSJSONReadingMutableContainers
                              error:&err];
    return jsonDict;
}

@end