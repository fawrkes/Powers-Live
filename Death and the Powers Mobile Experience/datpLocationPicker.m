//
//  datpLocationPicker.m
//  Death and the Powers Mobile Experience
//
//  Created by Garrett Parrish on 11/22/13.
//  Copyright (c) 2013 Opera of the Future. All rights reserved.
//

#import "datpLocationPicker.h"

@interface datpLocationPicker ()
{
    NSMutableArray *locations;
}
@end

@implementation datpLocationPicker

@synthesize locationPicker;

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Custom initialization
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    NSArray *preloadedLocations = @[@"Dallas",
                                    @"Stockholm",
                                    @"London",
                                    @"New York",
                                    @"Los Angeles",
                                    @"Boston",
                                    @"Berlin",
                                    @"Moscow",
                                    @"Tokyo",
                                    @"Rome",
                                    ];
    
    [locations addObjectsFromArray:preloadedLocations];
    
    locationPicker.delegate = self;
    
	// Do any additional setup after loading the view.
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end
