//
//  moduleBrowserCell.h
//  EasyLink
//
//  Created by William Xu on 14-4-2.
//  Copyright (c) 2014年 MXCHIP Co;Ltd. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "AsyncSocket.h"

@interface moduleBrowserCell : UITableViewCell{
    NSDictionary *_moduleService;
    IBOutlet UIImageView *lightStrengthView;
    AsyncSocket *socket;
    UIView *checkMarkView;
}

@property (nonatomic, retain, readwrite) NSDictionary *moduleService;

- (void)startActivityIndicator: (BOOL) enable;
- (void)startCheckIndicator: (BOOL) enable;

@end
