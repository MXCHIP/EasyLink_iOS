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
#import "route.h"
#import <SystemConfiguration/CaptiveNetwork.h>

#define EASYLINK_V1 0
#define EASYLINK_V2 1


@interface EASYLINK : NSObject{
@private
    NSUInteger version;
    AsyncUdpSocket *socket;
    NSTimer *sendInterval;
    NSMutableArray *array;
    NSThread *easyLinkThread;
}

@property (retain, nonatomic) NSMutableArray *array;
@property (retain, nonatomic) AsyncUdpSocket *socket;

- (void)prepareEasyLinkV1:(NSString *)bSSID password:(NSString *)bpasswd;
- (void)prepareEasyLinkV2:(NSString *)bSSID password:(NSString *)bpasswd info: (NSString *)userInfo;
- (void)transmitSettings;
- (void)stopTransmitting;
+ (NSString *)ssidForConnectedNetwork;
+ (NSString *)getGatewayAddress;

@end
