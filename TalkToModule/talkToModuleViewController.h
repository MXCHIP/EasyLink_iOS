//
//  talkToModuleViewController.h
//  MICO
//
//  Created by William Xu on 14-5-8.
//  Copyright (c) 2014年 MXCHIP Co;Ltd. All rights reserved.
//

#import "RMMultipleViewsController.h"
#import "AsyncSocket.h"
#import "CustomIOSAlertView.h"
#import "commandsTableViewController.h"
#import "messageViewController.h"

@interface talkToModuleViewController : RMMultipleViewsController
{
@private
    
    AsyncSocket *socket;
    NSDictionary *_txtRecord;
    NSString *_address;
    NSString *_name;
    NSString *_mac;
    NSString *_protocol;
    NSString *_module;
    NSInteger _port;
    NSMutableArray *_txtRecordArray;
    CustomIOSAlertView *customAlertView;
    messageViewController *message;
    commandsTableViewController *commandVC;
    BOOL isInforground;
}

@property (strong, nonatomic) NSNetService *service;
@property (strong, nonatomic) AsyncSocket *socket;

@end
