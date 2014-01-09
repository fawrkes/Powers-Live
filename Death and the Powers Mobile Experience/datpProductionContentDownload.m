//
//  datpProductionContentDownload.m
//  Death and the Powers Mobile Experience
//
//  Created by Garrett Parrish on 11/20/13.
//  Copyright (c) 2013 Opera of the Future. All rights reserved.
//

#import "datpProductionContentDownload.h"
#import "TestFlight.h"
#import "datpAppDelegate.h"
#import "datpViewController.h"

@interface datpDataDelegate : NSObject <NSURLConnectionDataDelegate>
@property NSString* path;
@property NSString* tempPath;
@property NSFileHandle* file;
@property BOOL failed;
@property BOOL done;
@end

@implementation datpDataDelegate

- (id) initWithPath:(NSString*)path
{
    self = [super init];
    if (self)
    {
        self.path = path;
        
        CFUUIDRef uuid = CFUUIDCreate(NULL);
        NSString* uuidString = CFBridgingRelease(CFUUIDCreateString(NULL, uuid));
        CFRelease(uuid);
        
        self.tempPath = [NSTemporaryDirectory() stringByAppendingPathComponent: [NSString stringWithFormat: @"datp-%@.tmp", uuidString]];
        [[NSFileManager defaultManager] createFileAtPath:self.tempPath contents:nil attributes:nil];
        self.file = [NSFileHandle fileHandleForWritingAtPath:self.tempPath];
        [self.file truncateFileAtOffset:0];
    }
    return self;
}

- (void) connection:(NSURLConnection *)connection didReceiveData:(NSData *)data
{
    [self.file writeData:data];
}

- (void) connectionDidFinishLoading:(NSURLConnection *)connection
{
    self.done = YES;
    
    [self.file closeFile];
    
    NSError* error = nil;
    BOOL success = YES;
    
    if ([[NSFileManager defaultManager] fileExistsAtPath:self.path])
    {
        success = [[NSFileManager defaultManager] removeItemAtPath:self.path error:&error];
        if (!success)
        {
            self.failed = YES;
            NSLog(@"Failed to remove existing file at path %@ (%@)", self.path, error);
            return;
        }
    }
    
    success = [[NSFileManager defaultManager] moveItemAtPath:self.tempPath toPath:self.path error:&error];
    if (!success)
    {
        self.failed = YES;
        NSLog(@"Failed to copy temp file from %@ to %@ (%@)", self.tempPath, self.path, error);
    }
}

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error
{
    self.done = YES;
    self.failed = YES;
    
    NSLog(@"Failed to download file %@ (%@)", [[connection originalRequest] URL], error);
    [self.file closeFile];
    BOOL success = [[NSFileManager defaultManager] removeItemAtPath:self.tempPath error:&error];
    if (!success)
    {
        NSLog(@"Failed to delete temporary file %@ (%@)", self.tempPath, error);
    }
}

@end

@interface datpProductionContentDownload ()
{
    NSMutableArray *assetList;
    id incomingMessage;
    int contentVersionToCheckFor;
    UIProgressView *productionContentDownloadProgress;
    UIActivityIndicatorView *downloading;
    NSUserDefaults *userDefaults;
}

@property (strong, nonatomic) IBOutlet UIButton *bypassButton;

@end

@implementation datpProductionContentDownload

- (void) awakeFromNib
{
    [super awakeFromNib];    
    userDefaults = [NSUserDefaults standardUserDefaults];
}

- (void) viewDidLoad
{
    [super viewDidLoad];
    
    NSLog(@"[Production Download] Current device content version: %i", [[userDefaults objectForKey:@"device_content_version"] integerValue]);
    NSLog(@"[Production Download] Should have content version: %i", [[userDefaults objectForKey:@"show_content_version"] integerValue]);
    
    // Configure UI
    [self _configureUI];
}

- (void) viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    
    // Check for new production content
    [self checkForNewProductionContent];
}

- (void) _configureUI
{
    // Background image
    UIImageView *backgroundImage = [[UIImageView alloc] initWithFrame:self.view.frame];
    [backgroundImage setImage:[UIImage imageNamed:@"text_bg.png"]];
    [self.view addSubview:backgroundImage];
    
    float viewWidth = AppDelegate().viewWidth;
    float viewHeight = AppDelegate().viewHeight;
    
    // Content download
    UITextView *message = [[UITextView alloc] initWithFrame:CGRectMake(viewWidth/2, viewWidth/2, viewWidth * .7, viewHeight * .35)];
    message.center = CGPointMake(viewWidth/2, viewHeight * .3);
    NSString* text = @"We’re downloading the latest Death and the Powers content for your device.";
    message.attributedText = GetFormattedText(text);
    [AppDelegate() formatTextField:message];
    [self.view addSubview:message];
    
    // Activity Indicator
    downloading = [[UIActivityIndicatorView alloc] initWithFrame:CGRectMake(viewWidth * .15, viewWidth * .15, viewWidth * .5, viewWidth * .5)];
    downloading.center = CGPointMake(viewWidth/2, viewHeight * .6);
    [self.view addSubview:downloading];
    [downloading startAnimating];
    
    // Progress bar
    productionContentDownloadProgress = [[UIProgressView alloc] initWithFrame:CGRectMake(viewWidth * .15, viewWidth * .85, viewWidth * .7, viewHeight * .08)];
    productionContentDownloadProgress.center = CGPointMake(viewWidth/2, viewHeight * .7);
    [AppDelegate() formatProgressBar:productionContentDownloadProgress];
    [self.view addSubview:productionContentDownloadProgress];
    
}

/////////////////////////////////////////////////////////////
/////////////////// CONTENT DOWNLOAD ////////////////////////
/////////////////////////////////////////////////////////////

- (void) checkForNewProductionContent
{
    NSLog(@"[Production Download] Checking for new production content.");

    // If device is up to date
    if ([[userDefaults objectForKey:@"latest_content_version"] isEqualToString:@"true"])
    {
        NSLog(@"[Production Download] This device has all the latest content. Moving on.");
        [TestFlight passCheckpoint:@"[Production Download] Device is up to date on content."];
        if (AppDelegate().showHoldingScreen)
        {
            [self _goToHolding];
        }
        else
        {
            [self _goToShow];
        }
    }
    // If device isn't up to date
    else
    {
        NSLog(@"[Production Download] Device isn't up to date.");
        [TestFlight passCheckpoint:@"[Production Download] Device content is not up to date."];
        contentVersionToCheckFor = AppDelegate().currentShowContentVersion;
        
        // Initialize download variables
        [self _beginProductionContentDownload];
    }
}

/////////////////////////////////////////////////////////////
/////////////////// CONTENT DOWNLOAD ////////////////////////
/////////////////////////////////////////////////////////////

- (void) _beginProductionContentDownload
{
    // Pull down show info
    [AppDelegate() pullDownShowInfo:contentVersionToCheckFor];

    [TestFlight passCheckpoint:[NSString stringWithFormat:@"[Production Download] Attempting to download content version: %i", contentVersionToCheckFor]];
    
    [self _updateAssetList];
    [self _updateProgressBar];
    [self _downloadLatestProductionContent];
}

- (void) _updateAssetList
{
    // Get preload
    NSArray *preload = AppDelegate().appShowInfo[@"preload"];
    
    assetList = [[NSMutableArray alloc] initWithCapacity:[preload count]];
    
    // Fill 'assetList' with file URLs
    for ( NSString *source in preload )
    {
        // Get full source URL and add to asset list
        NSString *fileURL = [AppDelegate().assetHost stringByAppendingString:AppDelegate().assetHostPath];
        [assetList addObject:[fileURL stringByAppendingString:source]];
    }
}

- (void) _downloadLatestProductionContent
{
    NSLog(@"[Production Download] Downloading Assets");
    
    dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
    
    NSArray* assets = [assetList copy];
    
    dispatch_async(queue, ^(){
        
        NSArray   *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
        NSString  *documentsDirectory = [paths objectAtIndex:0];
        
        NSFileManager *fileManager = [NSFileManager defaultManager];
        
        BOOL failed = NO;
        
        for (NSString *file in assets)
        {
            NSString *filename = [[file componentsSeparatedByString:@"/media/"] lastObject];
            
            NSString* path = [documentsDirectory stringByAppendingPathComponent:filename];
            BOOL fileExists = [fileManager fileExistsAtPath:path];
            
            // If the file doesn't exist, download it
            if (!fileExists)
            {
                NSLog(@"[Production Download] %@ does not exist. Attempting to write to file.", filename);
                NSError* error = nil;
                NSURLRequest* request = [[NSURLRequest alloc] initWithURL:[NSURL URLWithString:[NSString stringWithFormat:@"http://%@", file]]];
                NSURLResponse* response = nil;
                NSData *urlData = [NSURLConnection sendSynchronousRequest:request returningResponse:&response error:&error];
                if (error || !urlData)
                {
                    NSLog(@"[Production Download] Failed to download %@ (%@).", file, error);

                    [TestFlight passCheckpoint:[NSString stringWithFormat:@"[Production Download] Failed to download %@. (Content Version %i)", file, contentVersionToCheckFor]];
                     
					failed = YES;
					break;
				}
                
                if (![urlData writeToFile:path options:NSDataWritingAtomic error:&error] || error)
                {
                    NSLog(@"[Production Download] Failed to write %@ to file (%@).", filename, error);
                    [TestFlight passCheckpoint:[NSString stringWithFormat:@"[Production Download] Failed to write %@ to file. (Content Version %i)", filename, contentVersionToCheckFor]];
					failed = YES;
					break;
                }

                // Not-in-use code to use the datpDataDelegate to do the download synchronously.
//                datpDataDelegate* delegate = [[datpDataDelegate alloc] initWithPath:path];
//                NSURLConnection* connection = [[NSURLConnection alloc] initWithRequest:request delegate:delegate startImmediately:YES];
//                [connection start];
//                
//                while (!delegate.done)
//                {
//                    [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.1]];
//                }
//                
//                if (delegate.failed)
//                {
//                    NSLog(@"Download failed... cancelling remaining downloads.");
//                    failed = YES;
//                    break;
//                }

                NSLog(@"[Production Download] Successfully wrote %@ to file.", filename);

            }
            else
            {
                NSLog(@"[Production Download] %@ already exists. Skipping.", filename);
            }
			
            // Update progress view.
            [self performSelectorOnMainThread:@selector(_updateProgressBar) withObject:nil waitUntilDone:NO];
        }
        
        if (failed)
        {
            NSLog(@"[Production Download] Content update failed. Moving to previous cuelist.");
            [self performSelectorOnMainThread:@selector(_downloadFailed) withObject:nil waitUntilDone:NO];
        }
        else
        {
            NSLog(@"[Production Download] Content update succeeded.");
            [self performSelectorOnMainThread:@selector(_downloadSucceeded) withObject:nil waitUntilDone:NO];
        }
    });
}

- (void) _downloadFailed
{
    // Go back one content version and try those assets
    int base = [[userDefaults objectForKey:@"base_content_version"] integerValue];
    if (contentVersionToCheckFor > base)
    {
        contentVersionToCheckFor--;
        NSLog(@"[Production Download] Content version isn't at preloaded version. Moving to content version %i", contentVersionToCheckFor);
        [TestFlight passCheckpoint:[NSString stringWithFormat:@"[Production Download] Content version update failed. Checking version %i. ", contentVersionToCheckFor]];

        [self _beginProductionContentDownload];
    }
    else
    {
        NSLog(@"[Production Download] Reached preloaded content version. Using that as content version.");
        [TestFlight passCheckpoint:[NSString stringWithFormat:@"[Production Download] Couldn't download any full cue lists. Using preloaded version: %i", base]];

        [self _downloadSucceeded];
    }
}

- (void) _downloadSucceeded
{
    NSLog(@"All files located for this cue list. Proceeding.");
    [userDefaults setObject:[NSNumber numberWithInt:contentVersionToCheckFor] forKey:@"device_content_version"];
    [userDefaults setObject:@"true" forKey:@"latest_content_version"];
    [AppDelegate() updateUserDefaults];
    
    [TestFlight passCheckpoint:[NSString stringWithFormat:@"[Production Download] Content checks complete. Proceeding with version %i.", contentVersionToCheckFor]];
    
    // Store cue list
    AppDelegate().cueList = AppDelegate().appShowInfo[@"cues"];
    
    // Disable UI
    [downloading stopAnimating];
    
    // Go to holding screen until overrided to go to show
    if (AppDelegate().showHoldingScreen)
    {
        NSLog(@"[Production Download] Going to holding");
        [self _goToHolding];
    }
    else
    {
        NSLog(@"[Production Download] Skip holding screen");
        [self _goToShow];
    }
}

- (void) _updateProgressBar
{
    float increase = productionContentDownloadProgress.progress += 1.0/([assetList count] + 1.0);
    [productionContentDownloadProgress setProgress:increase animated:YES];
}

- (void) didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
}

- (void) _goToHolding
{
    NSLog(@"[Production Download] Going to holding.");
    [AppDelegate() transitionToViewController:AppDelegate().holdingViewController];
}

- (void) _goToShow
{
    NSLog(@"[Production Download] Going to show.");
    [AppDelegate() transitionToViewController:AppDelegate().mainShowViewController];
}

@end
