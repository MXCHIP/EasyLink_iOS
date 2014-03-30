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
@private
    IBOutlet UISwitch *contentSwitch;
}


@property (nonatomic, retain, readwrite) NSMutableDictionary *ftcConfig;
@property (nonatomic, retain, readwrite) UISwitch *contentSwitch;

@end
