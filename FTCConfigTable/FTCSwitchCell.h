//
//  FTCSwitchCell.h
//  EasyLink
//
//  Created by William Xu on 14-3-26.
//  Copyright (c) 2014年 MXCHIP Co;Ltd. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface FTCSwitchCell : UITableViewCell{
    NSMutableDictionary *_ftcConfig;
    id theDelegate;
@private
    IBOutlet UISwitch *contentSwitch;
}

@property (nonatomic, readwrite) NSUInteger sectionRow;
@property (nonatomic, readwrite) NSUInteger contentRow;
@property (nonatomic, retain, readwrite) NSMutableDictionary *ftcConfig;
@property (nonatomic, retain, readwrite) UISwitch *contentSwitch;

- (id)delegate;
- (void)setDelegate:(id)delegate;
- (IBAction)switchChanged: (UISwitch *)switcher;

@end