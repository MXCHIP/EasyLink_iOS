//
//  EASYLINK.h
//  EasyLink
//
//  Created by William Xu on 13-7-24.
//  Copyright (c) 2013年 MXCHIP. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <SystemConfiguration/CaptiveNetwork.h>
#import "AsyncUdpSocket.h"
#import "AsyncSocket.h"
#import "Reachability.h"

typedef enum{
    EASYLINK_V1 = 0,
    EASYLINK_V2,
    EASYLINK_PLUS,
    EASYLINK_V2_PLUS,
    EASYLINK_SOFT_AP,
} EasyLinkMode;

typedef enum{
    eState_initialize,
    eState_connect_to_uap,
    eState_configured_by_uap,
    eState_connect_to_wrong_wlan,
    eState_connect_to_target_wlan,
} EasyLinkSoftApStage;

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
@required
/**
 @brief A new FTC client is found by FTC server in EasyLink
 @param client:         Client identifier.
 @param configDict:     Configuration data provided by FTC client
 @return none.
 */
- (void)onFoundByFTC:(NSNumber *)client withConfiguration: (NSDictionary *)configDict;

/**
 @brief A FTC client is disconnected from FTC server in EasyLink
 @param client:         Client identifier.
 @return none.
 */
- (void)onDisconnectFromFTC:(NSNumber *)client;

@optional
/**
 @brief EasyLink stage is changed during soft ap configuration mode
 @param stage:         The current stage.
 @return none.
 */
- (void)onEasyLinkSoftApStageChanged: (EasyLinkSoftApStage)stage;

@end

@interface EASYLINK : NSObject<NSNetServiceBrowserDelegate,
NSNetServiceDelegate>{
@private
    /* Wlan configuratuon send by EasyLink */
    NSUInteger _broadcastcount, _multicastCount;
    bool _broadcastSending, _multicastSending, _softAPSending, _wlanUnConfigured;
    
    EasyLinkMode _mode;
    
    NSMutableArray *multicastArray, *broadcastArray;   //Used for EasyLink transmitting
    AsyncUdpSocket *multicastSocket, *broadcastSocket;
    
    //Used for EasyLink first time configuration
    AsyncSocket *ftcServerSocket;
    NSMutableArray *ftcClients;
    NSTimer *closeFTCClientTimer;
    
    NSNetServiceBrowser* _netServiceBrowser;
    NSMutableArray * _netServiceArray;
    NSDictionary * _configDict;
    
    CFHTTPMessageRef inComingMessageArray[MessageCount];
    Reachability *wifiReachability;
    EasyLinkSoftApStage _softAPStage;
    
    id theDelegate;
}

@property (nonatomic, readonly) EasyLinkSoftApStage softAPStage;
@property (nonatomic, readonly) bool softAPSending;
@property (nonatomic, readonly) EasyLinkMode mode;

/* These delays should can only be write before prepareEasyLink_withFTC:info:mode is called. The less time is delayed, the faster Easylink may success,but wireless router would be under heavier pressure. So user should consider a balence between speed and wireless router's performance*/
@property (nonatomic, readwrite) float easyLinkPlusDelayPerByte;   //Default value: 5ms
@property (nonatomic, readwrite) float easyLinkPlusDelayPerBlock;  //Default value: 80ms, a block send 5 package
@property (nonatomic, readwrite) float easyLinkV2DelayPerBlock;    //Default value: 20ms, a block send 1 package


- (id)initWithDelegate:(id)delegate;
- (id)delegate;
- (void)setDelegate:(id)delegate;
- (void)unInit;

// Easylink sequence:
// Application ---------------------------------EasyLink------------------------------------------MICO Device----------------------
// initWithDelegate:(id)delegate;     ->      Create FTC server
// prepareEasyLink_withFTC:info:mode: ->      Store configurations
//
// EasyLink V2/Plus mode:==========================================================================================================
// transmitSettings                   ->      Send wlan configurations       ->             Receive wlan configurations
//                                                                                          Connect to wlan
//                                            Accept FTC client              <-             Connect to FTC server
// onFoundByFTC:withConfiguration:    <-      Receive                        <-             Send current info and configuration
//
// stopTransmitting                   ->      Stop send wlan configurations
//
//
// EasyLink soft ap mode:==========================================================================================================
// transmitSettings                   ->      Start FTC monitoring
// onEasyLinkSoftApStageChanged:      <-      Connect to EasyLink_XXXXXX wlan in iOS settings by user
//                                            Find the new device, connect   ->             Accetp iOS connection
//                                            Send wlan configurations       ->             Receive wlan configurations
// onEasyLinkSoftApStageChanged:      <-      Receive                        <-             Send response
//                                                                                          Close Soft AP
//                                                                                          Connect to wlan
// iOS disconnect from Soft ap and connect to wlan (possiable manual operation required in iOS settings, because iOS may connect to another wlan rather than a previous connected wlan)
// onEasyLinkSoftApStageChanged:      <-      Connect to EasyLink_XXXXXX wlan in iOS settings by user
//                                            Find the new device, connect   ->             Accetp iOS connection
//                                            Read FTC configurations        ->             Receive
// onFoundByFTC:withConfiguration:    <-      Receive                        <-             Send FTC configurations
//
//
//================================================================================================================================
//
// At this step, the device has connect to the same wlan as iOS, but wlan settings has not stored to flash storage.
// If App enter background while FTC client is connected, all FTC client will be disconnected, and leave them unconfigured
//
//================================================================================================================================
// Now application has several choices:
//
// 1. Send first-time-configuration to device, and finish EasyLink procedure
// configFTCClient:withConfiguration: ->      Send FTC configurations        ->             Receive FTC configurations
//                                                                                          Store all configurations
// onDisconnectFromFTC:               <-      Disconnect FTC client          <-             Disconnect from FTC server
//                                                                                          Reboot and enter normal running mode
//
// 2. Send OTA data to update device's firmware
// otaFTCClient:withOTAData:          ->      Send OTA data                  ->             Receive OTA data
// onDisconnectFromFTC:               <-      Disconnect FTC client          <-             Disconnect from FTC server
//                                                                                          Reboot and apply new firmware
//                                            Accept FTC client              <-             Connect to FTC server
// onFoundByFTC:currentConfig:        <-      Receive                        <-             Send current info and configuration
//
// 3. Ignore FTC client and leave them unconfigured
// configFTCClient:withConfiguration: ->      Send FTC configurations        ->             Receive FTC configurations
//                                                                                          Store all configurations
// onDisconnectFromFTC:               <-      Disconnect FTC client          <-             Disconnect from FTC server
//                                                                                          Reboot and enter normal running mode
//

/**
 @brief Set all wlan seetings that need to be delivered by EasyLink. It 
        should be excuted before (void)transmitSettings
 @param wlanConfigDict: Wlan configurations, include SSID, password, address etc.
 @param userInfo:       Application defined specific data to be send by Easylink.
 @param easyLinkMode:   The mode of EasyLink.
 @return none.
 */
- (void)prepareEasyLink_withFTC:(NSDictionary *)wlanConfigDict info: (NSData *)userInfo mode: (EasyLinkMode)easyLinkMode;

/**
 @brief Send wlan settings use the predefined EasyLink mode
 */
- (void)transmitSettings;

/**
 @brief Stop current Easylink delivery. It is suggested to stop EasyLink once a new device
        is found (Notified by onFoundByFTC:currentConfig: in protocol EasyLinkFTCDelegate).
        As the EasyLink V2/plus mode would reduce the performance of the wireless router.
 */
- (void)stopTransmitting;

/**
 @brief Send a dictionary that contains all of the first-time-configurations to the new deivice.
        Once the device has received, it will disconnect, and exit the EasyLionk configuration mode.
        This function initialize the device like cloud servive account, password, working configures
        etc. when user first connect the device to Internet.
 @param client:         Client identifier, read by onFoundByFTC:currentConfig: in protocol 
                        EasyLinkFTCDelegate.
 @param configDict:     Device configurations.
 @return none.
 */
- (void)configFTCClient:(NSNumber *)client withConfiguration: (NSDictionary *)configDict;

/**
 @brief Send new firmware to the new deivice. Once the device has received, it will disconnect,
        update to the new firmware, and reconnect to iOS.
 @param client:         Client identifier, read by onFoundByFTC:currentConfig: in protocol
                        EasyLinkFTCDelegate.
 @param otaData:        New firmware data.
 @return none.
 */
- (void)otaFTCClient:(NSNumber *)client withOTAData: (NSData *)otaData;

/**
 @brief Disconnect the new device, and leave it unconfigured(device will not store wlan settings).
 @param client:         Client identifier, read by onFoundByFTC:currentConfig: in protocol
                        EasyLinkFTCDelegate.
 @return none.
 */
- (void)closeFTCClient:(NSNumber *)client;


#pragma mark - Tools -

/**
 @brief Return the WLan SSID string(UTF8 conding) connected by iOS currently.
 */
+ (NSString *)ssidForConnectedNetwork;

/**
 @brief Return the WLan SSID data (bytes) connected by iOS currently.
 */
+ (NSData *)ssidDataForConnectedNetwork;

/**
 @brief Return the WLan information connected by iOS currently.
 */
+ (NSDictionary *)infoForConnectedNetwork;

/**
 @brief Return the current iOS IP address on the wlan interface.
 */
+ (NSString *)getIPAddress;

/**
 @brief Return the current iOS netmask on the wlan interface.
 */
+ (NSString *)getNetMask;

/**
 @brief Return the current iOS broadcast address on the wlan interface.
 */
+ (NSString *)getBroadcastAddress;

/**
 @brief Return the current iOS gateway address on the wlan interface.
 */
+ (NSString *)getGatewayAddress;

@end
