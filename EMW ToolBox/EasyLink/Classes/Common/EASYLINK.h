//
//  EASYLINK.h
//  EasyLink
//
//  Created by William Xu on 13-7-24.
//  Copyright (c) 2013年 MXCHIP. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "AsyncUdpSocket.h"
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

#define EASYLINK_V1 0
#define EASYLINK_V2 1


@interface EASYLINK : NSObject{
@private
    AsyncUdpSocket *socket;
    NSMutableArray *array;
    NSTimer *sendInterval;
}

@property (retain, nonatomic) NSMutableArray *array;
@property (retain, nonatomic) AsyncUdpSocket *socket;
@property (retain, nonatomic) NSTimer *sendInterval;

- (void)setSettingsWithSsid:(NSString *)bSSID password:(NSString *)bpasswd version: (NSUInteger)ver;
- (void)transmitSettings;
- (void)stopTransmitting;
- (void)startConfigure:(id)sender;
- (NSString *)ssidForConnectedNetwork;
- (NSString *)getGatewayAddress;

@end
