//
//  EASYLINK.h
//  EasyLink
//
//  Created by William Xu on 13-7-24.
//  Copyright (c) 2013年 MXCHIP. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "AsyncUdpSocket.h"
#import "AsyncSocket.h"
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

#define EASYLINK_V1         0
#define EASYLINK_V2         1

/*wlanConfigArray content index*/
#define INDEX_SSID          0
#define INDEX_PASSWORD      1
#define INDEX_DHCP          2
#define INDEX_IP            3
#define INDEX_NETMASK       4
#define INDEX_GATEWAY       5
#define INDEX_DNS1          6
#define INDEX_DNS2          7


#define FTC_PORT 8000

@protocol EasyLinkFTCDelegate
@optional

/**
 *
 **/
- (void)onFoundByFTC:(NSNumber *)client currentConfig: (NSData *)config;

/**
 *
 **/
- (void)onDisconnectFromFTC:(NSNumber *)client;

@end



@interface EASYLINK : NSObject{
@private
    NSTimer *closeFTCClientTimer;
    NSUInteger version;
    NSMutableArray *array;   //Used for EasyLink transmitting
    AsyncUdpSocket *socket;
    
    //Used for EasyLink first time configuration
    AsyncSocket *ftcServerSocket;
    NSMutableArray *ftcClients;
    CFMutableArrayRef inCommingMessages;
    
    NSTimer *sendInterval;
    NSThread *easyLinkThread;
    BOOL firstTimeConfig;
    id theDelegate;
}

@property (retain, nonatomic) NSMutableArray *array;
@property (retain, nonatomic) AsyncUdpSocket *socket;
@property (retain, nonatomic) AsyncSocket *ftcServerSocket;
@property (retain, nonatomic) NSMutableArray *ftcClients;


- (void)prepareEasyLinkV1:(NSString *)bSSID password:(NSString *)bpasswd;

- (void)prepareEasyLinkV2:(NSString *)bSSID password:(NSString *)bpasswd info: (NSData *)userInfo;
- (void)prepareEasyLinkV2_withFTC:(NSArray *)wlanConfigArray info: (NSData *)userInfo;

- (void)transmitSettings;
- (void)stopTransmitting;

- (id)delegate;
- (void)setDelegate:(id)delegate;
- (void)startFTCServerWithDelegate:(id)delegate;
- (void)configFTCClient:(NSNumber *)client withConfigurationData: (NSData *)configData;
- (void)otaFTCClient:(NSNumber *)client withOTAData: (NSData *)otaData;
- (void)closeFTCClient:(NSNumber *)client;
- (void)closeFTCServer;
- (BOOL)isFTCServerStarted;

/**
 * Tools
 **/

+ (NSString *)ssidForConnectedNetwork;
+ (NSString *)getIPAddress;
+ (NSString *)getNetMask;

+ (NSString *)getGatewayAddress;

@end
