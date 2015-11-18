//
//  bonjourDetailTableViewController.h
//  MICO
//
//  Created by William Xu on 14-4-30.
//  Copyright (c) 2014年 MXCHIP Co;Ltd. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "AsyncSocket.h"
#import "CustomIOSAlertView.h"

typedef enum
{
    eState_start                        = -1,
    eState_ReadConfig                   = 0,
    eState_WriteConfig                  = 1,
    eState_SendOTAData                  = 2
} _ConfigState_t;

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
    AsyncSocket *configSocket;
    CustomIOSAlertView *customAlertView, *otaAlertView;
    CFHTTPMessageRef inComingMessage;
    NSMutableDictionary *configData;
    NSData *updateData;
    NSData *otaData;
    _ConfigState_t currentState;
}

@property (strong, nonatomic) NSNetService *service;

- (IBAction)edit:(UIBarButtonItem *)sender;


@end
