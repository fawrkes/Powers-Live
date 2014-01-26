//
//  datpFacebookLoginViewController.m
//  Death and the Powers Mobile Experience
//
//  Created by Garrett Parrish on 11/18/13.
//  Copyright (c) 2013 Opera of the Future. All rights reserved.
//

#import "datpFacebookLoginViewController.h"
#import "datpAppDelegate.h"
#import "TestFlight.h"
#import "datpProductionContentDownload.h"

@interface datpFacebookLoginViewController () <UIAlertViewDelegate>
{
    NSUserDefaults *userDefaults;
    
    // UI
    UIActivityIndicatorView  *downloading;
    UIProgressView *facebookProgressBar;
    UIButton *skipBtn;
    UIButton *chooseVenueBtn;
    float progressFloat;
    
    // Facebook
    float maxFBPics;
    BOOL fetchedUserInfo;
    BOOL loggedInWithFacebook;
    BOOL stoppedInMiddle;
}

@property (strong, nonatomic) IBOutlet FBProfilePictureView *profilePictureView;
@property (strong, nonatomic) IBOutlet UILabel *nameLabel;
@property (strong, nonatomic) IBOutlet UILabel *statusLabel;
@property (strong, nonatomic) IBOutlet UIButton *bypassButton;

@end

@implementation datpFacebookLoginViewController

@synthesize bypassButton, profilePictureView, nameLabel, statusLabel;

- (void) awakeFromNib
{
    [super awakeFromNib];    
    userDefaults = [NSUserDefaults standardUserDefaults];
}

- (void) viewDidLoad
{
    [super viewDidLoad];
    
    // Number of FB images to download
    maxFBPics = 20.0;
    
    // Configure UI
    [self _configureUI];
}

- (void) _configureUI
{
    float viewWidth = AppDelegate().viewWidth;
    float viewHeight = AppDelegate().viewHeight;
    
    // Background image
    UIImageView *backgroundImage = [[UIImageView alloc] initWithFrame:self.view.frame];
    [backgroundImage setImage:[UIImage imageNamed:@"text_bg.png"]];
    [self.view addSubview:backgroundImage];
    
    // Main facebook message
    UITextView *facebookMessage = [[UITextView alloc] initWithFrame:CGRectMake(viewWidth * .1, viewWidth * .9, viewWidth * .9, viewHeight * .30)];
    facebookMessage.center = CGPointMake(viewWidth/2, viewHeight * .2);
    facebookMessage.attributedText = GetFormattedText(@"Enter into The System by logging in with Facebook. You will not receive any Facebook notifications, and nothing will be posted to your Wall. Your likeness may be incorporated into the performance.");
    
    [AppDelegate() formatTextField:facebookMessage];
    [self.view addSubview:facebookMessage];
    
    // Create a FBLoginView to log the user in with photo permissions
    FBLoginView *loginView = [[FBLoginView alloc] initWithReadPermissions:@[@"user_photos", @"friends_photos"]];
    loginView.loginBehavior = FBSessionLoginBehaviorUseSystemAccountIfPresent;
    
    // Set this loginUIViewController to be the loginView button's delegate
    loginView.delegate = self;
    
    // Set login view frame
    loginView.frame = CGRectMake(AppDelegate().viewWidth, AppDelegate().viewHeight, AppDelegate().viewWidth * .8, AppDelegate().viewHeight * .1);
    
    // Align the button in the center horizontally
    loginView.frame = CGRectOffset(loginView.frame,
                                   (self.view.center.x - (loginView.frame.size.width / 2)),
                                   5);
    
    
    loginView.center = CGPointMake(viewWidth/2, viewHeight * .4);
    
    // Add the button to the view
    [self.view addSubview:loginView];
    
    // FB Profile Pic View
    profilePictureView = [[FBProfilePictureView alloc] initWithFrame:CGRectMake(viewWidth * .25, viewWidth * .65, viewWidth * .2, viewWidth * .2)];
    profilePictureView.center = CGPointMake(viewWidth/4, viewHeight * .63);
    profilePictureView.hidden = YES;
    [self.view addSubview:self.profilePictureView];
    
    // FB Name
    nameLabel = [[UILabel alloc] initWithFrame:CGRectMake(viewWidth * .3, viewHeight * .2, viewWidth * .5, viewHeight *.2)];
    nameLabel.center = CGPointMake(viewWidth * .7, viewHeight * .63);
    [AppDelegate() formatLabel:nameLabel];
    [self.view addSubview:self.nameLabel];
    
    // FB Login Status
    statusLabel = [[UILabel alloc] initWithFrame:CGRectMake(viewWidth * .3, viewHeight * .2, viewWidth * .6, viewHeight *.2)];
    statusLabel.center = CGPointMake(viewWidth * .5, viewHeight * .5);
    [AppDelegate() formatLabel:statusLabel];
    [self.view addSubview:self.statusLabel];
    
    // Activity indicator
    downloading = [[UIActivityIndicatorView alloc] initWithFrame:CGRectMake(viewWidth * .15, viewWidth * .15, viewWidth * .5, viewWidth * .5)];
    
    downloading.center = CGPointMake(viewWidth/2, viewHeight * .75);
    [self.view addSubview:downloading];
    downloading.hidden = YES;
    
    // Progress bar
    facebookProgressBar = [[UIProgressView alloc] initWithFrame:CGRectMake(viewWidth * .15, viewWidth * .85, viewWidth * .7, viewHeight * .08)];
    facebookProgressBar.center = CGPointMake(viewWidth/2, viewHeight * .8);
    
    [AppDelegate() formatProgressBar:facebookProgressBar];
    [self.view addSubview:facebookProgressBar];
    facebookProgressBar.hidden = YES;
    
    // Skip button
    skipBtn = [[UIButton alloc] initWithFrame:CGRectMake(viewWidth * .15, viewWidth * .85, viewWidth * .6, viewHeight * .2)];
    skipBtn.center = CGPointMake(viewWidth/2, viewHeight * .8);
    
    [skipBtn setTitle:@"Skip" forState:UIControlStateNormal];
    [AppDelegate() formatButton:skipBtn];
    [skipBtn addTarget:self action:@selector(_userSkippedFacebookLogin) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:skipBtn];
    
    chooseVenueBtn = [[UIButton alloc] initWithFrame:CGRectMake(5, 5, 150, 25)];
    chooseVenueBtn.center = CGPointMake(viewWidth/2, viewHeight * .9);
    [chooseVenueBtn setTitle:@"Start Over" forState:UIControlStateNormal];
    [AppDelegate() formatButton:chooseVenueBtn];
    [chooseVenueBtn addTarget:self action:@selector(_handleChooseVenue) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:chooseVenueBtn];
}

- (void) _handleChooseVenue
{
    [AppDelegate() navigateUser];
}

/////////////////////////////////////////////////////////////
/////////////////// FACEBOOK METHODS ////////////////////////
/////////////////////////////////////////////////////////////

// This method will be called when the user information has been fetched
- (void) loginViewFetchedUserInfo:(FBLoginView *)loginView user:(id<FBGraphUser>)user
{
    // Boolean to prevent calling twice
    if (!fetchedUserInfo)
    {
        fetchedUserInfo = YES;
        
        self.profilePictureView.profileID = user.id;
        self.nameLabel.text = user.name;
        
        // Initialize view variables
        progressFloat = 0.0;
        facebookProgressBar.hidden = NO;
        
        // Update display
        [self _updateProgressBar];
        [downloading setHidden:NO];
        [downloading startAnimating];
        skipBtn.hidden = YES;
        
        // Download pictures
        [self _downloadFacebookImageData];
    }
}

- (void) loginViewShowingLoggedInUser:(FBLoginView *)loginView
{
    self.statusLabel.text = @"You're logged in as";
    loggedInWithFacebook = YES;
    profilePictureView.hidden = NO;
    chooseVenueBtn.hidden = YES;
    [TestFlight passCheckpoint:@"[Facebook View] User logged in with Facebook."];
}

- (void) loginViewShowingLoggedOutUser:(FBLoginView *)loginView
{
    self.profilePictureView.profileID = nil;
    self.nameLabel.text = @"";
    self.statusLabel.text= @"You're not logged in!";
    loggedInWithFacebook = NO;
    profilePictureView.hidden = YES;
    chooseVenueBtn.hidden = NO;
    [TestFlight passCheckpoint:@"[Facebook View] User logged out with Facebook."];
}

- (void) loginView:(FBLoginView *)loginView handleError:(NSError *)error
{
    NSString *alertMessage, *alertTitle;
    
    if ([FBErrorUtility shouldNotifyUserForError:error])
    {
        alertTitle = @"[Facebook Login] Facebook error";
        alertMessage = [FBErrorUtility userMessageForError:error];
    }
    else if ([FBErrorUtility errorCategoryForError:error] == FBErrorCategoryAuthenticationReopenSession)
    {
        alertTitle = @"Session Error";
        alertMessage = @"Your current session is no longer valid. Please log in again.";
    }
    else if ([FBErrorUtility errorCategoryForError:error] == FBErrorCategoryUserCancelled)
    {
        NSLog(@"[Facebook Login] User cancelled login.");
    }
    else
    {
        alertTitle  = @"Something went wrong";
        alertMessage = @"Please try again later.";
        NSLog(@"Unexpected error:%@", error);
    }
    
    if (alertMessage)
    {
        [[[UIAlertView alloc] initWithTitle:alertTitle
                                    message:alertMessage
                                   delegate:nil
                          cancelButtonTitle:@"OK"
                          otherButtonTitles:nil] show];
    }
}

/////////////////////////////////////////////////////////////
///////////////////// IMAGE DOWNLOAD ////////////////////////
/////////////////////////////////////////////////////////////

- (void) _downloadFacebookImageData
{
    NSLog(@"[Facebook Login] Retrieving facebook photo data.");
    
    [FBRequestConnection startWithGraphPath:@"me/photos"
                          completionHandler:^(FBRequestConnection *connection, id result, NSError *error)
     {
         if (!error)
         {
             NSData *photoData = [NSJSONSerialization dataWithJSONObject:result
                                                                 options:NSJSONWritingPrettyPrinted
                                                                   error:&error];
             [self _downloadFacebookImages:photoData];
         }
         else
         {
             NSLog(@"Error: %@", error);
         }
     }];
}

- (void) _downloadFacebookImages: (NSData *) data
{
    NSLog(@"[Facebook Login] Downloading Facebook photos.");
    
    dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
    
    dispatch_async(queue, ^(){
        
        NSDictionary *photosDict = [NSJSONSerialization
                                    JSONObjectWithData:data
                                    options:NSJSONReadingMutableContainers
                                    error:nil];
        
        // Write images to files
        int fbImageNumber = 0;
        
        // Save file urls in 'photoList'
        for (id fbImage in photosDict[@"data"])
        {
            if (loggedInWithFacebook)
            {
                NSLog(@"[Facebook Login] Downloading photo.");
                NSURL  *fbImageURL = [NSURL URLWithString:fbImage[@"source"]];
                NSData *fbImageData = [NSData dataWithContentsOfURL:fbImageURL];
                
                // If photo was downloaded
                if (fbImageData)
                {
                    // Save files in 'documents' directory
                    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
                    NSString  *documentsDirectory = [paths objectAtIndex:0];
                    
                    // Name files according to the number downloaded
                    NSString *fbImageFilePrefix = fbImageNumber < 9 ? @"FB0" : @"FB";
                    NSString *fbImageFileName = [NSString stringWithFormat:@"%@%d.jpg", fbImageFilePrefix, fbImageNumber];
                    NSString *filePath = [documentsDirectory stringByAppendingPathComponent:fbImageFileName];
                    
                    // Write pictures to file
                    [fbImageData writeToFile:filePath atomically:YES];
                    
                    fbImageNumber++;
                    
                    // Update progress
                    [self performSelectorOnMainThread:@selector(_updateProgressBar) withObject:nil waitUntilDone:NO];
                    
                    // If downloaded specified number, quit
                    if (fbImageNumber > maxFBPics)
                    {
                        break;
                    }
                }
            }
            else
            {
                NSLog(@"[Facebook Download] User logged out. Stopping download.");
                [TestFlight passCheckpoint:@"[Facebook View] User cancelled Facebook photo download."];

                stoppedInMiddle = YES;
                [self performSelectorOnMainThread:@selector(_revertUI) withObject:nil waitUntilDone:NO];
                break;
            }
        }
        
        if (!stoppedInMiddle)
        {
            [self performSelectorOnMainThread:@selector(_finishedDownloadingPhotos) withObject:nil waitUntilDone:NO];
        }
    
        stoppedInMiddle = NO;
        fetchedUserInfo = NO;
    });
}

- (void) _finishedDownloadingPhotos
{
    [userDefaults setObject:@"true" forKey:@"downloaded_facebook_photos"];
    [AppDelegate() updateUserDefaults];

    [TestFlight passCheckpoint:@"[Facebook View] Successfully downloaded Facebook photos."];
    // Go to next screen
    [self _moveToNextView];
}

- (void) _updateProgressBar
{
    [facebookProgressBar setProgress:progressFloat += 1.0/(maxFBPics + 1.0) animated:YES];
}

- (void) _userSkippedFacebookLogin
{
    [userDefaults setObject:@"true" forKey:@"skipped_facebook"];
    [self _moveToNextView];
}

/////////////////////////////////////////////////////////////
/////////////////////// NAVIGATION //////////////////////////
/////////////////////////////////////////////////////////////

- (void) _revertUI
{
    // Update view elements
    [downloading stopAnimating];
    [downloading setHidden:YES];
    [facebookProgressBar setHidden:YES];
    [facebookProgressBar setProgress:0.0];
    skipBtn.hidden = NO;
    chooseVenueBtn.hidden = NO;
}

- (void) _moveToNextView
{
    [self _revertUI];
    
    [facebookProgressBar setProgress:1.0 animated:YES];
    
    [AppDelegate() navigateUser];
}
@end
