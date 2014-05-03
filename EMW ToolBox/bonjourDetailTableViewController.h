//
//  bonjourDetailTableViewController.h
//  MICO
//
//  Created by William Xu on 14-4-30.
//  Copyright (c) 2014年 MXCHIP Co;Ltd. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface bonjourDetailTableViewController : UITableViewController{
    IBOutlet UITableView *bonjourDetailTable;
@private
    NSDictionary *_txtRecord;
    NSString *_address;
    NSString *_hostName;
    NSString *_name;
    NSString *_port;
    NSMutableArray *_majourInfo;
    NSMutableArray *_txtRecordArray;
}

@property (strong, nonatomic) NSNetService *service;

@end
