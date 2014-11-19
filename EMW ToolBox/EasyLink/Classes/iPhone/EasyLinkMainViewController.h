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

@interface EasyLinkMainViewController : UIViewController<UITextFieldDelegate, EasyLinkFTCDelegate, EasyLinkFTCDataDelegate, EasyLinkOTADelegate>{
    NSMutableArray *foundModules;
@private
    IBOutlet UITableView *configTableView;
    IBOutlet UITableView *foundModuleTableView;
    UITextField *ssidField,*bssidField,*passwordField,*userInfoField,*ipAddress;

    IBOutlet UIButton *EasylinkV2Button;
    UIAlertView *alertView;
    CustomIOS7AlertView *customAlertView, *otaAlertView;
    NSMutableDictionary *deviceIPConfig;
    NSMutableDictionary *apInforRecord;
    NSString *apInforRecordFile;

    EASYLINK *easylink_config;
    CustomIOS7AlertView *easyLinkSendingView;

    Reachability *wifiReachability;
}

@property (strong, nonatomic) NSMutableArray *foundModules;

/*
 This method waits for an acknowledge from the remote device than it stops the transmit to the remote device and returns with data it got from the remote device.
 This method blocks until it gets respond.
 The method will return true if it got the ack from the remote device or false if it got aborted by a call to stopTransmitting.
 In case of a failure the method throws an OSFailureException.
 */
- (void) waitForAck: (id)sender;

/*
    This method start the transmitting the data to connected 
    AP. Nerwork validation is also done here. All exceptions from
    library is handled.
 */
- (void)startTransmitting: (int)version;





@end
