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
#import "EMWUtility.h"
#import "EASYLINK.h"

@interface EasyLinkMainViewController : UIViewController<UITextFieldDelegate>{
    @private
        IBOutlet UITableView *configTableView, *aboutTableView;

        IBOutlet  UIButton *startbutton;
        IBOutlet UIImageView *spinnerView;

        EASYLINK *easylink_config;
    
        UITextField *ssidField,*passwordField,*ipAddress;
    
        Reachability *wifiReachability;
}

/*
 This method waits for an acknowledge from the remote device than it stops the transmit to the remote device and returns with data it got from the remote device.
 This method blocks until it gets respond.
 The method will return true if it got the ack from the remote device or false if it got aborted by a call to stopTransmitting.
 In case of a failure the method throws an OSFailureException.
 */
- (void) waitForAckThread: (id)sender;

/*
    This method start the transmitting the data to connected 
    AP. Nerwork validation is also done here. All exceptions from
    library is handled.
 */
- (void)startTransmitting;

@end
