//
//  EASYLINK.h
//  EasyLink
//
//  Created by William Xu on 13-7-24.
//  Copyright (c) 2013年 MXCHIP. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <SystemConfiguration/CaptiveNetwork.h>
#import "AsyncUdpSocket.h"
#import "AsyncSocket.h"


typedef enum{
    EASYLINK_V1,
    EASYLINK_V2,
    EASYLINK_PLUS,
    EASYLINK_SOFT_AP,
} EasyLinkMode;

typedef enum
{
    eState_start                        = -1,
    eState_ReadConfig                   = 0,
    eState_WriteConfig                  = 1,
    eState_SendOTAData                  = 2
} _ConfigState_t;

/*w lanConfig key */
#define KEY_SSID          @"SSID"
#define KEY_PASSWORD      @"PASSWORD"
#define KEY_DHCP          @"DHCP"
#define KEY_IP            @"IP"
#define KEY_NETMASK       @"NETMASK"
#define KEY_GATEWAY       @"GATEWAY"
#define KEY_DNS1          @"DNS1"
#define KEY_DNS2          @"DNS2"

#define FTC_PORT 8000
#define MessageCount 100

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



@interface EASYLINK : NSObject<NSNetServiceBrowserDelegate,
NSNetServiceDelegate>{
@private
    /* Wlan configuratuon send by EasyLink */
    in_addr_t ip, netmask, gateway, dns1, dns2;
    bool dhcp;
    NSString *ssid, *passwd;
    NSMutableData *userInfoWithIP;
    
    NSUInteger broadcastcount, multicastCount;
    bool broadcastSending, multicastSending, softAPSending;
    
    EasyLinkMode mode;
    bool wlanUnConfigured;
    
    NSMutableArray *multicastArray, *broadcastArray;   //Used for EasyLink transmitting
    AsyncUdpSocket *multicastSocket, *broadcastSocket;
    
    //Used for EasyLink first time configuration
    AsyncSocket *ftcServerSocket, *configSocket;
    NSMutableArray *ftcClients;
    CFMutableArrayRef inCommingMessages;
    NSTimer *closeFTCClientTimer;
    
    NSNetServiceBrowser* _netServiceBrowser;
    NSMutableArray * _netServiceArray;
    NSDictionary * configDict;
    
    CFHTTPMessageRef inComingMessageArray[MessageCount];
    
    id theDelegate;
}

@property (retain, nonatomic) AsyncUdpSocket *multicastSocket;
@property (retain, nonatomic) AsyncUdpSocket *broadcastSocket;
@property (retain, nonatomic) AsyncSocket *ftcServerSocket;
@property (retain, nonatomic) NSMutableArray *ftcClients;



- (void)prepareEasyLink_withFTC:(NSDictionary *)wlanConfigArray info: (NSData *)userInfo mode: (EasyLinkMode)easyLinkMode;

- (void)transmitSettings;
- (void)stopTransmitting;

- (id)delegate;
- (void)setDelegate:(id)delegate;
- (void)startFTCServerWithDelegate:(id)delegate;
- (void)configFTCClient:(NSNumber *)client withConfigurationData: (NSData *)configData;
- (void)otaFTCClient:(NSNumber *)client withOTAData: (NSData *)otaData;
- (void)closeFTCClient:(NSNumber *)client;
- (void)closeFTCServer;



/**
 * Tools
 **/

+ (NSString *)ssidForConnectedNetwork;
+ (NSData *)ssidDataForConnectedNetwork;
+ (NSDictionary *)infoForConnectedNetwork;
+ (NSString *)getIPAddress;
+ (NSString *)getNetMask;
+ (NSString *)getBroadcastAddress;

+ (NSString *)getGatewayAddress;

@end
