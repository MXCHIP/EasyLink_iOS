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
//#import "EMWUtility.h"
#import "EASYLINK.h"
#import "EasyLinkFTCTableViewController.h"
#import "CustomIOS7AlertView.h"
#import "EasyLinkOTATableViewController.h"
#import "EasyLinkFoundTableViewController.h"


@interface EasyLinkMainViewController : UIViewController<UITextFieldDelegate, EasyLinkFTCDelegate, EasyLinkFTCDataDelegate, EasyLinkOTADelegate, NSFileManagerDelegate>{
    NSMutableArray *foundModules;
@private
    IBOutlet UITableView *configTableView;
    IBOutlet UIScrollView *bgView;
    IBOutlet UITableView *foundModuleTableView;
    UITextField *ssidField,*bssidField,*passwordField,*userInfoField,*ipAddress;

    NSData *targetSsid;

    IBOutlet UIButton *newDevicesButton;
    UIAlertView *alertView;
    CustomIOS7AlertView *customAlertView, *otaAlertView;
    NSMutableDictionary *deviceIPConfig;
    NSMutableDictionary *apInforRecord;
    NSString *apInforRecordFile;

    EASYLINK *easylink_config;
    CustomIOS7AlertView *easyLinkSendingView, *easyLinkUAPSendingView;
    __weak EasyLinkFoundTableViewController *foundTableViewController;
    

    Reachability *wifiReachability;
}

@property (strong, nonatomic) NSMutableArray *foundModules;








@end
