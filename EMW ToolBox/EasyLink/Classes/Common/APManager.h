//
//  APManager.h
//  EMW ToolBox
//
//  Created by William Xu on 13-7-28.
//  Copyright (c) 2013年 MXCHIP Co;Ltd. All rights reserved.
//

#import <UIKit/UIKit.h>
#include <sys/socket.h>
#include <netdb.h>
#include <AssertMacros.h>
#import <CFNetwork/CFNetwork.h>
#include <netinet/in.h>
#include <errno.h>
#include <ifaddrs.h>
#include <arpa/inet.h>

#import <SystemConfiguration/CaptiveNetwork.h>

typedef enum {
  
    CC3xSending = 1,
    CC3xStopped
} ProcessStatus;


@interface EasyLinkAPManager : NSObject{
    
    ProcessStatus _status;
}

+ (EasyLinkAPManager *)sharedInstance;

/*!!!!!!!!! return thr status of the process !!!!!!!!!*/
- (ProcessStatus)processStatus;

/* Printing the address of pinged AP
 * @param destination address
 */
- (NSString *) displayAddressForAddress:(NSData *) address;

/*!!!!!!!!!!!!! retrieving the IP Address from the connected WiFi */
- (NSString *)getIPAddress ;

/*!!!!!!!!!!!! retriving the SSID of the connected network !!!!!!!!!!*/
- (NSString*)ssidForConnectedNetwork;
@end
