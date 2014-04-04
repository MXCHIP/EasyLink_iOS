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
    NSMutableDictionary *_moduleService;
    IBOutlet UIImageView *lightStrengthView;
    AsyncSocket *socket;
}

@property (nonatomic, retain, readwrite) NSMutableDictionary *moduleService;
@property (nonatomic, retain, readwrite) IBOutlet UIImageView *lightStrengthView;

- (void)startActivityIndicator: (BOOL) enable;

@end
