//
//  easyLinkIpConfigTableViewController.h
//  MICO
//
//  Created by William Xu on 14-4-20.
//  Copyright (c) 2014年 MXCHIP Co;Ltd. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface easyLinkIpConfigTableViewController : UITableViewController<UITextFieldDelegate>{
@private
    IBOutlet  UITableView *ipConfigTable;
    UITextField *ipAddressField,*netMaskField,*gatewayField,*dnsServerField;
    UISwitch *dhcpSwitch;
    bool dhcp;
}

@property(strong, nonatomic)NSMutableDictionary *deviceIPConfig;
@property(strong, nonatomic)NSArray *firmwareList;

@end
