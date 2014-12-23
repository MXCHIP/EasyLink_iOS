//
//  FTCSubMenuCell.m
//  MICO
//
//  Created by William Xu on 14-4-4.
//  Copyright (c) 2014年 MXCHIP Co;Ltd. All rights reserved.
//

#import "FTCSubMenuCell.h"
#include "EasyLinkFTCTableViewController.h"

@implementation FTCSubMenuCell

- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier
{
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
        // Initialization code
    }
    return self;
}

- (void)awakeFromNib
{
    // Initialization code
}

- (void)setSelected:(BOOL)selected animated:(BOOL)animated
{
    [super setSelected:selected animated:animated];

    // Configure the view for the selected state
}

- (void)setFtcConfig:(NSMutableDictionary *)newFtcConfig {
	_ftcConfig = newFtcConfig;
    self.textLabel.text = [self.ftcConfig objectForKey:@"N"];
//    self.contentSwitch.on = [[self.ftcConfig valueForKey:@"C"] boolValue];
//    
//    if ([[self.ftcConfig objectForKey:@"P"] isEqualToString:@"RO"]) {
//        [self.contentSwitch setUserInteractionEnabled:NO];
//    }
}




@end
