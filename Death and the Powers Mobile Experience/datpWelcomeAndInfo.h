//
//  datpWelcomeAndInfo.h
//  Death and the Powers Mobile Experience
//
//  Created by Garrett Parrish on 12/4/13.
//  Copyright (c) 2013 Opera of the Future. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface datpWelcomeAndInfo : UIViewController <UIPickerViewDataSource, UIPickerViewDelegate>

@property UIPickerView *pickerView;
@property NSMutableArray *locations;

@end
