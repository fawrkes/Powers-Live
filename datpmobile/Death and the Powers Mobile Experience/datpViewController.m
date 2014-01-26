//
//  datpViewController.m
//  Death and the Powers Mobile Experience
//
//  Created by Garrett Parrish on 11/11/13.
//  Copyright (c) 2013 Opera of the Future. All rights reserved.
//

#import "datpAppDelegate.h"
#import "datpViewController.h"
#import "NSURLImageProtocol.h"
#define ARC4RANDOM_MAX      0x100000000
#import "TestFlight.h"

@interface datpViewController () <UIWebViewDelegate>
{
    UIWebView *webBrowser;
    NSUserDefaults *userDefaults;
    
    // Cues
    NSString *followCue;
    
    // Audio / video
    AVAudioPlayer *audioPlayerController;
    MPMoviePlayerController *moviePlayerController;
    BOOL videoLoop;
    NSString *lastVideoCue;
}
@end

@implementation datpViewController

- (void) awakeFromNib
{
    [super awakeFromNib];
    
    userDefaults = [NSUserDefaults standardUserDefaults];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_didBecomeActive:) name:UIApplicationDidBecomeActiveNotification object:nil];
}

- (void) viewDidLoad
{
    [super viewDidLoad];
    
    // Register URL protocol with the url scheme of cpImg
    [NSURLProtocol registerClass:[NSURLImageProtocol class]];
    
    // Configure audio playback
    [self _configureAudioSession];
    
    // Turn off auto lock and hide status bar
    [[UIApplication sharedApplication] setStatusBarHidden:YES];
    [UIApplication sharedApplication].idleTimerDisabled = YES;
    
    // Instantiate web browser and scale to fit edges
    webBrowser = [[UIWebView alloc] initWithFrame:self.view.frame];
    webBrowser.allowsInlineMediaPlayback = YES;
    webBrowser.mediaPlaybackRequiresUserAction = NO;
    webBrowser.scalesPageToFit = YES;
    webBrowser.backgroundColor = [UIColor blackColor];
    webBrowser.delegate = self;
    
    self.view.backgroundColor = [UIColor blackColor];
}

- (void) viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    // Load the show
    [self loadShowWebPage];
}

/////////////////////////////////////////////////////////////
///////////////////////// WEB VIEW //////////////////////////
/////////////////////////////////////////////////////////////

- (void) webViewDidStartLoad:(UIWebView *)webView
{
    [webView removeFromSuperview];
}

- (void) webView:(UIWebView *)webView didFailLoadWithError:(NSError *)error
{
    [self performSelector:@selector(loadShowWebPage) withObject:nil afterDelay:2.0];
}

- (void) webViewDidFinishLoad:(UIWebView *)webView
{
    [self.view addSubview:webView];
}

- (NSURL*) _webViewUrl
{
    // Load webview
    NSString *uuid = [userDefaults objectForKey:@"uuid"];
    NSString *locationID = [userDefaults objectForKey:@"locationid"];
    return [NSURL URLWithString:[NSString stringWithFormat:@"%@?uuid=%@&location=%@", AppDelegate().clientWebViewUrl, uuid, locationID]];
}

- (void) _didBecomeActive:(NSNotification*)notification
{
    // Reload the web view when the app becomes active
    [self loadShowWebPage];
}

- (void) loadShowWebPage
{
    [webBrowser loadRequest:[NSURLRequest requestWithURL:[self _webViewUrl]]];
}

- (void) interpretSocketMessage:(id) message
{
    NSString *incomingMessage = [NSString stringWithFormat:@"%@", message];
    NSData *messageData = [incomingMessage dataUsingEncoding:NSUTF8StringEncoding];
    NSDictionary *messageJSON = [NSJSONSerialization
                                 JSONObjectWithData:messageData
                                 options:NSJSONReadingMutableContainers
                                 error:nil];
    
    // Get main cue key
    NSArray *cueKey = messageJSON[@"arguments"];
    
    // Number from arguments array
    NSString *currentCue = [NSString stringWithFormat:@"%@", [cueKey lastObject]];
    
    [TestFlight passCheckpoint:[NSString stringWithFormat:@"[Show View] Received and executing cue: %@", currentCue]];

    // Else execute
    [self _executeCue:currentCue];
}

/////////////////////////////////////////////////////////////
///////////////////////// RUN CUE ///////////////////////////
/////////////////////////////////////////////////////////////

- (int) _executeCue: (NSString *) currentCue
{
    // Get the cue value for that input cue
    NSDictionary *cueName = AppDelegate().cueList[currentCue];
    
    NSLog(@"[Web View] %@ is pointing to: %@", currentCue, cueName);
    
    // If the cue isn't in the cue list - break out of function early (don't execute anything)
    if (!cueName)
    {
        return 1;
    }
        
    // First redirect
    NSString *cueClass = [NSString stringWithFormat:@"%@",[cueName class]];
    NSString *stringClass = @"__NSCFString";
    
    // While the cue points to another, keep going down until you hit the last cue
    while ([cueClass isEqualToString:stringClass])
    {
        // Reset cue dictionary to the value of the new key
        cueName = AppDelegate().cueList[cueName];
        
        NSLog(@"[Web View] Redirecting cue to %@", cueName);
        cueClass = [NSString stringWithFormat:@"%@", [cueName class]];
    }
    
    NSDictionary *cue = cueName;
    
    // If there is a probability
    if (cue[@"probability"])
    {
        // Calculate probability
        double myDub = [cue[@"probability"] doubleValue];
        double val = ((double)arc4random() / ARC4RANDOM_MAX);
        
        NSLog(@"[Web View] Checking probability of cue: %f < %f ?", val, myDub);
        
        // If the probability is right
        if (myDub < val)
        {
            NSLog(@"[Web View] Not executing this cue ... moving on");
            
            NSString *nextCueKey = cue[@"next"];
            NSDictionary *nextCue = AppDelegate().cueList[nextCueKey];
            
            NSLog(@"[Web View] Next cue: %@ has contents: %@", nextCueKey, nextCue);
            
            [self _executeCue:nextCueKey];
            
            [TestFlight passCheckpoint:[NSString stringWithFormat:@"[Show View] Proabilitistic cue. Not executing, instead, playing cue: %@", nextCueKey]];

            // Exit function
            return 1;
        }
        else
        {
            NSLog(@"[Web view] Executing this cue");
        }
    }
    
    if (cue[@"device"])
    {
        NSDictionary *deviceCues = cue[@"device"];
        
        NSLog(@"[Web View] Device cues for this cue are: %@", deviceCues);
        
        // Brightness
        [[UIScreen mainScreen] setBrightness: deviceCues[@"dim"] ? DIM : BRIGHT];
        
        // Audio
        if (deviceCues[@"audio"])
        {
            [self playAudio:deviceCues[@"audio"]];
        }
        
        // Video
        if (deviceCues[@"video"])
        {
            NSLog(@"[Web view] Play Video");

            // Loop or not
            videoLoop = [deviceCues[@"loop"] boolValue];
            
            NSLog(@"Last video cue: %@", lastVideoCue);
            
            if (deviceCues[@"video"] != lastVideoCue)
            {
                NSLog(@"[Web View] Playing %@", deviceCues[@"video"]);
                
                [self playVideo:deviceCues[@"video"]];
            }
            else
            {
                NSLog(@"[Web View] Not restarting video for loop.");
            }
            
            // Set the last video cue to check for loop
            lastVideoCue = deviceCues[@"video"];
        }
        // Make sure video is cut
        else
        {
            // This allows for retriggering of the same video cue if another cue was received
            lastVideoCue = NULL;
            [self cutVideo:moviePlayerController];
        }
        
        // Vibrate
        if (deviceCues[@"vibrate"])
        {
            int duration = [deviceCues[@"vibrate"] intValue]; // in milliseconds
            NSLog(@"[Web view] Vibrating for %i milliseconds.", duration);
            [self vibrate:duration/1000.0];
        }
    }
    else
    {
        // Reset for new video cues, brighten display, and cut video
        lastVideoCue = NULL;
        [[UIScreen mainScreen] setBrightness:BRIGHT];
        [self cutVideo:moviePlayerController];
    }
    
    // If supposed to wait
    if (cue[@"follow"])
    {
        // Wait specified time
        float delay = [cue[@"follow"] floatValue];
        
        NSLog(@"[Web View] Waiting %f seconds", delay);
        followCue = cue[@"next"];
        
        [TestFlight passCheckpoint:[NSString stringWithFormat:@"[Show View] Waiting for %f seconds, then executing %@.", delay, followCue]];
        
        // Play cue
        [self performSelector:@selector(followForNextCue) withObject:nil afterDelay:delay];
        
        NSLog(@"[Web View] Next cue key: %@", followCue);
		
        return 1;
    }
    
    return  1;
}

- (void) followForNextCue
{
    [self _executeCue:followCue];
}

/////////////////////////////////////////////////////////////
///////////////////////// VIDEO /////////////////////////////
/////////////////////////////////////////////////////////////

- (void) playVideo: (NSString *) filename
{
    NSLog(@"[Web View] Playing video: %@", filename);
    [TestFlight passCheckpoint:[NSString stringWithFormat:@"[Show View] Playing video file: %@", filename]];
    
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentsDirectory = [paths objectAtIndex:0];
    NSURL *videoFileUrl = [NSURL fileURLWithPath:[documentsDirectory stringByAppendingPathComponent:filename]];
    
    if (moviePlayerController)
    {
        [self cutVideo:moviePlayerController];
        [[NSNotificationCenter defaultCenter] removeObserver:self
                                                        name:MPMoviePlayerPlaybackDidFinishNotification
                                                      object:moviePlayerController];
    }
    
    // Create movie player and audio player
    moviePlayerController = [[MPMoviePlayerController alloc] initWithContentURL:videoFileUrl];
    [moviePlayerController.view setFrame:self.view.frame];
    moviePlayerController.view.hidden = NO;
    moviePlayerController.scalingMode = MPMovieScalingModeAspectFill;
    moviePlayerController.controlStyle = MPMovieControlStyleNone;
    moviePlayerController.view.userInteractionEnabled = NO;
    moviePlayerController.shouldAutoplay = NO;
    moviePlayerController.movieSourceType = MPMovieSourceTypeFile;
    
    // Add movieplayer stop listener
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(moviePlayerStateDidChange:)
                                                 name:MPMoviePlayerPlaybackStateDidChangeNotification
                                               object:moviePlayerController];
    
    // Play movie player
    [moviePlayerController prepareToPlay];
    [self.view addSubview:moviePlayerController.view];
    
    // Play movie player
    [moviePlayerController play];
}

// Loop video, if supposed to
- (void) moviePlayerStateDidChange:(NSNotification *)notification
{
    MPMoviePlayerController* player = notification.object;
    if (player.playbackState == MPMoviePlaybackStateStopped ||
        (videoLoop && player.playbackState == MPMoviePlaybackStatePaused))
    {
        if (videoLoop)
        {
            // Replay video
            [player play];
        }
        else
        {
            // Stop video playback
            [self cutVideo:player];
        }
    }
}

- (void) cutVideo:(MPMoviePlayerController*)player
{
    NSLog(@"[Web view] Cutting video");
    // Stop and hide movie player
    [player stop];
    [player setContentURL:nil];
    [player setFullscreen:NO animated:NO];
    [player.view removeFromSuperview];
}

/////////////////////////////////////////////////////////////
///////////////////////// AUDIO /////////////////////////////
/////////////////////////////////////////////////////////////

- (void) playAudio: (NSString *)filename
{
    NSLog(@"[Web View] Playing audio : %@", filename);
    [TestFlight passCheckpoint:[NSString stringWithFormat:@"[Show View] Playing audio file: %@", filename]];
    
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentsDirectory = [paths objectAtIndex:0];
    NSURL *audioFileUrl = [NSURL fileURLWithPath:[documentsDirectory stringByAppendingPathComponent:filename]];
    
    // Load audio
	audioPlayerController = [[AVAudioPlayer alloc] initWithContentsOfURL:audioFileUrl error:nil];
    [audioPlayerController play];
}

- (void) _configureAudioSession
{
    // Audio session initializations for playing sound even when on silent mode
    AudioSessionInitialize(nil, nil, nil, nil);
    AudioSessionSetActive(YES);
    UInt32 sessionCategory = kAudioSessionCategory_MediaPlayback;
    AudioSessionSetProperty (kAudioSessionProperty_AudioCategory, sizeof(sessionCategory),&sessionCategory);
}

/////////////////////////////////////////////////////////////
/////////////////////// VIBRATE /////////////////////////////
/////////////////////////////////////////////////////////////

static const double kVibratePeriod = 0.001;

- (void) vibrate:(float)duration
{
    [TestFlight passCheckpoint:[NSString stringWithFormat:@"[Show View] Vibrating for %f seconds.", duration]];
	
    CFAbsoluteTime endTime = CFAbsoluteTimeGetCurrent() + duration + kVibratePeriod;
	NSNumber* end = [NSNumber numberWithDouble:endTime];
    [NSTimer scheduledTimerWithTimeInterval:kVibratePeriod target:self selector:@selector(vibe:) userInfo:end repeats:YES];
}

- (void) vibe:(NSTimer*)timer
{
	// Always vibrate at least once
	AudioServicesPlayAlertSound(kSystemSoundID_Vibrate);
	
	CFAbsoluteTime endTime = [[timer userInfo] doubleValue];
	if (CFAbsoluteTimeGetCurrent() > endTime)
	{
        NSLog(@"Stopping vibration.");
        [timer invalidate];
    }
}

@end
