//
//  easylinkModeConfigTableViewController.h
//  MICO
//
//  Created by William Xu on 2017/11/12.
//  Copyright © 2017年 MXCHIP Co;Ltd. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "EasyLink.h"

@interface easylinkModeConfigTableViewController : UITableViewController {
    IBOutlet UITableView *selectTable;
    id theDelegate;
}

@property(nonatomic)EasyLinkMode *mode;

@end
