//
//  RootViewController.h
//  MICO
//
//  Created by William Xu on 14-5-15.
//  Copyright (c) 2014年 MXCHIP Co;Ltd. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "HMSegmentedControl.h"

#import "AsyncSocket.h"
#import "CustomIOS7AlertView.h"
#import "commandsTableViewController.h"
#import "messageViewController.h"

@interface talkToModuleViewController : UIViewController  <UIScrollViewDelegate>
{
    HMSegmentedControl *sceneSegment;
    
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
    CustomIOS7AlertView *customAlertView;
    messageViewController *message;
    commandsTableViewController *commandVC;
    BOOL isInforground;
}

@property (strong, nonatomic) NSNetService *service;
@property (strong, nonatomic) AsyncSocket *socket;

@end
