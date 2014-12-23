//
//  FTCSubMenuCell.h
//  MICO
//
//  Created by William Xu on 14-4-4.
//  Copyright (c) 2014年 MXCHIP Co;Ltd. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface FTCSubMenuCell : UITableViewCell{
    NSMutableDictionary *_ftcConfig;
}

@property (nonatomic, retain, readwrite) NSMutableDictionary *ftcConfig;

@end
