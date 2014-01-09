//
//  datpHoldingView.m
//  Death and the Powers Mobile Experience
//
//  Created by Garrett Parrish on 12/6/13.
//  Copyright (c) 2013 Opera of the Future. All rights reserved.
//

#import "datpHoldingView.h"
#import "datpAppDelegate.h"
#import "datpViewController.h"
#import "datpProductionContentDownload.h"
#import "TestFlight.h"

@interface datpHoldingView ()

@property (strong, nonatomic) IBOutlet UIButton *bypassButton;

@end

@implementation datpHoldingView
{
    UIButton* chooseVenueBtn;
}

@synthesize bypassButton;

- (void) viewDidLoad
{
    [super viewDidLoad];

    [TestFlight passCheckpoint:@"[Holding Screen] User currently at holding screen. "];

    [self _configureUI];
}

- (void) _configureUI
{
    // Programatically position UI elements
    float viewWidth = AppDelegate().viewWidth;
    float viewHeight = AppDelegate().viewHeight;
    
    // Background image
    UIImageView *backgroundImage = [[UIImageView alloc] initWithFrame:self.view.frame];
    [backgroundImage setImage:[UIImage imageNamed:@"text_bg.png"]];
    [self.view addSubview:backgroundImage];
    
    // Set message text
    NSString *location = [[NSUserDefaults standardUserDefaults] objectForKey:@"location"];
    
    NSString *time = AppDelegate().appShowInfo[@"locations"][location][@"show-time"];
    
    UITextView *holdingText = [[UITextView alloc] initWithFrame:CGRectMake(viewWidth/2, viewWidth/2, viewWidth * .7, viewHeight * .5)];
    holdingText.center = CGPointMake(viewWidth/2, viewHeight/2);
    NSString* text = [NSString stringWithFormat:@"You’re ready to begin your journey into The System!  Come back to this app on Feb. 16th at %@ to experience the Death and the Powers Global Simulcast.", time];
    holdingText.attributedText = GetFormattedText(text);
    [AppDelegate() formatTextField:holdingText];
    [self.view addSubview:holdingText];
    
    chooseVenueBtn = [[UIButton alloc] initWithFrame:CGRectMake(5, 5, 150, 25)];
    chooseVenueBtn.center = CGPointMake(viewWidth/2, viewHeight * .9);
    [chooseVenueBtn setTitle:@"Start Over" forState:UIControlStateNormal];
    [AppDelegate() formatButton:chooseVenueBtn];
    [chooseVenueBtn addTarget:self action:@selector(_handleChooseVenue) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:chooseVenueBtn];
}

- (void) _handleChooseVenue
{
    [AppDelegate() transitionToViewController:AppDelegate().welcomeAndInfoViewController];
}

- (IBAction)handleBypass
{
    [AppDelegate() transitionToViewController:AppDelegate().mainShowViewController];
}

@end
