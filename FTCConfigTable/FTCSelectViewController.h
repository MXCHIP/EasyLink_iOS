//
//  FTCSelectViewController.h
//  MICO
//
//  Created by William Xu on 14-4-8.
//  Copyright (c) 2014年 MXCHIP Co;Ltd. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface FTCSelectViewController : UITableViewController{
    IBOutlet UITableView *selectTable;
    
}

@property (strong, nonatomic) NSMutableDictionary *configData;
@property (strong, nonatomic) NSArray *selectMenu;

@end
