//
//  EasyLinkMainViewController.h
//  EMW ToolBox
//
//  Created by William Xu on 13-7-28.
//  Copyright (c) 2013年 MXCHIP Co;Ltd. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "Reachability.h"
#include <time.h>
#import "EMWHeader.h"
#import "EASYLINK.h"
#import "EasyLinkFTCTableViewController.h"
#import "CustomIOSAlertView.h"
#import "EasyLinkOTATableViewController.h"


@interface EasyLinkMainViewController : UIViewController<UITextFieldDelegate, EasyLinkFTCDelegate, EasyLinkFTCDataDelegate, EasyLinkOTADelegate, NSFileManagerDelegate>{
@private
    IBOutlet UITableView *configTableView, *foundModuleTableView;
    IBOutlet UIScrollView *bgView;
    IBOutlet UILabel *newDeviceCount;
    IBOutlet UIButton *startEasyLinkBTN;
    UITextField *ssidField, *bssidField, *passwordField, *userInfoField, *ipAddress, *easylinkModeField;

    NSData *targetSsid;

    UIAlertView *alertView;
    EasyLinkMode easylinkMode;
    CustomIOSAlertView *customAlertView, *otaAlertView;
    NSMutableDictionary *deviceIPConfig;
    NSMutableDictionary *apInforRecord;
    NSString *apInforRecordFile;

    EASYLINK *easylink_config;
    CustomIOSAlertView *easyLinkSendingView, *easyLinkUAPSendingView;

    Reachability *wifiReachability;
}

@property (strong, nonatomic) NSMutableArray *foundModules;

@end
