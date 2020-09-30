//
//  EASYLINK.m
//  EasyLink
//
//  Created by William Xu on 13-7-24.
//  Copyright (c) 2013年 MXCHIP. All rights reserved.
//

#import "EasyLink.h"
#import "sys/sysctl.h"
#include <ifaddrs.h>
#include <UIKit/UIKit.h>
#include <arpa/inet.h>
#import "ELAsyncUdpSocket.h"
#import "ELAsyncSocket.h"
#import "ELReachability.h"

#define EASYLINK_VERSION  @"4.2.4"

//#define AWS_COMPATIBLE

#define EasyLinkLog(A, ...) do{[self displayDebug:[NSString stringWithFormat:@"[libEasyLink: %s: %d] %@", __func__, __LINE__, [NSString stringWithFormat:(A), ##__VA_ARGS__]]];} while(1==0)


#include "route.h"

#define DefaultEasyLinkPlusDelayPerByte    0.005
#define DefaultEasyLinkPlusDelayPerBlock   0.06
#define DefaultEasyLinkV2DelayPerBlock     0.08
#define DefaultEasyLinkAWSDelayPerByte     0.02

#define kEasyLinkConfigServiceType @"_easylink_config._tcp"
#define kInitialDomain  @"local"


@implementation NSMutableArray (Additions)
- (void)insertEasyLinkPlusData:(NSUInteger)length delay:(float)delay
{
    [self addObject:[NSMutableDictionary dictionaryWithObjectsAndKeys: [NSMutableData dataWithLength:length], @"sendData", [NSNumber numberWithFloat:delay], @"Delay", nil]];
}

- (void)insertEasyLinkPlusBlockIndex:(uint32_t *)blockIndex forSeqNo: (uint32_t)seqNo delay:(float)delay blockDelay: (float)blockDelay
{
    if (((seqNo)%4)==3) {
        (*blockIndex)++;
        [(NSMutableDictionary *)([self lastObject]) setObject:[NSNumber numberWithFloat:blockDelay] forKey:@"Delay"];
        [self addObject:[NSDictionary dictionaryWithObjectsAndKeys: [NSMutableData dataWithLength:(0xB0+ *blockIndex)], @"sendData", [NSNumber numberWithFloat:delay], @"Delay", nil]];
    }
}

- (void)insertEasyLinkAWSHeader:(NSUInteger)header delay:(float)delay
{
    [self addObject:[NSMutableDictionary dictionaryWithObjectsAndKeys: [NSMutableData dataWithLength:header], @"sendData", [NSNumber numberWithFloat:delay], @"Delay", nil]];
}


- (void)insertEasyLinkAWSData:(NSUInteger)data atIndex: (NSUInteger)dataIdx atBlockIndex:(NSUInteger *)blockIndex delay:(float)delay
{
    NSUInteger length = ((dataIdx%8 + 2) << 7) + (data&0xFF);
    [self addObject:[NSMutableDictionary dictionaryWithObjectsAndKeys: [NSMutableData dataWithLength:length], @"sendData", [NSNumber numberWithFloat:delay], @"Delay", nil]];
    
    if (((dataIdx)%8)==7) {
        (*blockIndex)++;
        [self addObject:[NSDictionary dictionaryWithObjectsAndKeys: [NSMutableData dataWithLength:(992 + *blockIndex)], @"sendData", [NSNumber numberWithFloat:delay], @"Delay", nil]];
        [self addObject:[NSDictionary dictionaryWithObjectsAndKeys: [NSMutableData dataWithLength:(992 + *blockIndex)], @"sendData", [NSNumber numberWithFloat:delay], @"Delay", nil]];
    }
}

@end

@implementation NSData (Additions)
- (NSString *)host
{
    struct sockaddr *addr = (struct sockaddr *)[self bytes];
    if(addr->sa_family == AF_INET) {
        struct sockaddr_in *addr4 = (struct sockaddr_in *)addr;
        char straddr4[INET_ADDRSTRLEN];
        inet_ntop(AF_INET, &(addr4->sin_addr), straddr4, sizeof(straddr4));
        return [NSString stringWithCString: straddr4 encoding: NSASCIIStringEncoding];
    }
    else if(addr->sa_family == AF_INET6) {
        struct sockaddr_in6 *addr6 = (struct sockaddr_in6 *)addr;
        char straddr[INET6_ADDRSTRLEN];
        inet_ntop(AF_INET6, &(addr6->sin6_addr), straddr,
                  sizeof(straddr));
        return [NSString stringWithCString: straddr encoding: NSASCIIStringEncoding];
    }
    return nil;
}

@end

@implementation EASYLINK (Additions)
- (void)displayDebug:(NSString *)debugInfo
{
    if(self.enableDebug == true)
        NSLog(@"%@", debugInfo);
}

@end

@interface EASYLINK ()
- (void)broadcastStartConfigure:(id)sender;
- (void)multicastStartConfigure:(id)sender;
- (void)closeClient:(NSTimer *)timer;
- (BOOL)isFTCServerStarted;
- (void)closeFTCServer;

- (void)prepareEasyLink:(NSDictionary *)wlanConfigDict info:(NSData *)userInfo encrypt:(NSData *)key mode:(EasyLinkMode)easyLinkMode identifier:(uint32_t)id;

- (void)prepareEasyLinkV2:(NSData *)bSSID password:(NSData *)bpasswd info:(NSData *)userInfo;
- (void)prepareEasyLinkPlus:(NSData *)bSSID password:(NSData *)bpasswd info:(NSData *)userInfo;

+ (void)encrypt:(NSMutableData *)inputData useRC4Key:(NSData *)key;

@end

@implementation EASYLINK
@synthesize softAPStage = _softAPStage;
@synthesize softAPSending = _softAPSending;
@synthesize mode = _mode;
@synthesize easyLinkPlusDelayPerByte;
@synthesize easyLinkPlusDelayPerBlock;
@synthesize easyLinkV2DelayPerBlock;
@synthesize easyLinkAWSDelayPerByte;
@synthesize enableDebug;


-(id)init{
    return [self initWithDelegate:nil];
}

-(id)initWithDelegate:(id)delegate{
    return [self initForDebug:false WithDelegate:delegate];
}

- (id)initForDebug:(BOOL)enable WithDelegate:(id)delegate;
{
    self = [super init];
    NSError *err;
    if (self) {
        // Initialization code
        _mode = EASYLINK_V2_PLUS;
        self.enableDebug = enable;
        EasyLinkLog(@"Init EasyLink v:%@", EASYLINK_VERSION);
        
        lockToken = [NSObject alloc];
        
        broadcastArray = [NSMutableArray array];
        multicastArray = [NSMutableArray array];
        awsArray = [NSMutableArray array];
        _softAPStage = eState_initialize;
        
        ftcClients = [NSMutableArray arrayWithCapacity:10];
        
        ftcServerSocket = [[ELAsyncSocket alloc] initWithDelegate:self];
        [ftcServerSocket acceptOnPort:FTC_PORT error:&err];
        if (err) {
            EasyLinkLog(@"Setup TCP server failed:%@", [err localizedDescription]);
        }
        
        awsEchoServer = [[ELAsyncUdpSocket alloc] initIPv4];
        [awsEchoServer setDelegate:self];
        [awsEchoServer enablePortReUse:YES error:&err];
        [awsEchoServer bindToPort:AWS_ECHO_SERVER_PORT error:&err];
        if (err) {
            EasyLinkLog(@"Setup AWS echo server failed:%@", [err localizedDescription]);
        }
        
        awsHostsArrayPerSearch = [NSMutableArray array];
        
        [awsEchoServer receiveWithTimeout:-1 tag:0];

        _multicastSending = false;
        _broadcastSending = false;
        _awsSending = false;
        _softAPSending = false;
        _wlanUnConfigured = false;
        easyLinkPlusDelayPerByte = DefaultEasyLinkPlusDelayPerByte;
        easyLinkPlusDelayPerBlock = DefaultEasyLinkPlusDelayPerBlock;
        easyLinkV2DelayPerBlock = DefaultEasyLinkV2DelayPerBlock;
        easyLinkAWSDelayPerByte = DefaultEasyLinkAWSDelayPerByte;
        
        for(NSUInteger idx = 0; idx<MessageCount; idx++){
            inComingMessageArray[idx] = nil;
        }
        
        _broadcastCount = 0;
        _multicastCount = 0;
        _awsCount = 0;
        
        wifiReachability = [ELReachability reachabilityForLocalWiFi];  //监测Wi-Fi连接状态
        [wifiReachability startNotifier];
        
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(appEnterInforground:) name:UIApplicationWillEnterForegroundNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(appEnterInBackground:) name:UIApplicationDidEnterBackgroundNotification object:nil];
        
        
        // wifi notification when changed.
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(wifiStatusChanged:) name:kELReachabilityChangedNotification object:nil];
        
        theDelegate = delegate;
        
    }
    return self;
}

-(void) unInit{
    theDelegate = nil;
    [self closeFTCServer];
    [self stopTransmitting];
    [awsEchoServer close];
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

-(void)dealloc{
    EasyLinkLog(@"unInit EasyLink");
    [self closeFTCServer];
    [self stopTransmitting];
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (id)delegate
{
    return theDelegate;
}

- (void)setDelegate:(id)delegate
{
    theDelegate = delegate;
}

- (void)closeFTCServer
{
    for (NSMutableDictionary *object in ftcClients)
    {
        EasyLinkLog(@"Close FTC clients");
        ELAsyncSocket *clientSocket = [object objectForKey:@"Socket"];
        [clientSocket setDelegate:nil];
        [clientSocket disconnect];
        clientSocket = nil;
    }
    if(ftcServerSocket != nil){
        EasyLinkLog(@"Close FTC server");
        [ftcServerSocket setDelegate:nil];
        [ftcServerSocket disconnect];
        ftcServerSocket = nil;
    }
    
    for(int idx = 0; idx<MessageCount; idx++){
        if(inComingMessageArray[idx]!=nil){
            CFRelease(inComingMessageArray[idx]) ;
            inComingMessageArray[idx] = nil;
        }
    }
    theDelegate = nil;
}

- (BOOL)isFTCServerStarted
{
    if(ftcServerSocket == nil)
        return NO;
    else
        return YES;
}


- (void)prepareEasyLink:(NSDictionary *)wlanConfigDict info: (NSData *)userInfo encrypt: (NSData *)key mode: (EasyLinkMode)easyLinkMode identifier: (uint32_t)id
{
    NSString *ipAddress;
    in_addr_t ip = -1, netmask = -1, gateway = -1, dns1 = -1, dns2 = -1;
    NSData *ssid, *passwd;
    
    _mode = easyLinkMode;
    _configDict = wlanConfigDict;
    _userInfo_str =  [[NSString alloc] initWithData:userInfo encoding:NSUTF8StringEncoding];
    if( _userInfo_str == nil ) _userInfo_str = [userInfo description];
    
    if ([_configDict objectForKey:KEY_SSID] == nil)
        ssid = [NSData dataWithBytes:nil length:0];
    else
        ssid = [_configDict objectForKey:KEY_SSID];
        
    if ([_configDict objectForKey:KEY_PASSWORD] == nil)
        passwd = [NSData dataWithBytes:nil length:0];
    else {
        if( [[_configDict objectForKey:KEY_PASSWORD] isKindOfClass:[NSString class]] == YES )
            passwd = [(NSString *)[_configDict objectForKey:KEY_PASSWORD] dataUsingEncoding:NSUTF8StringEncoding];
        else if( [[_configDict objectForKey:KEY_PASSWORD] isKindOfClass:[NSData class]] == YES )
            passwd = [_configDict objectForKey:KEY_PASSWORD];
        else {
            EasyLinkLog(@"PASSWORD should be NSString or NSData");
        }
    }
    
        
    if (userInfo == nil) userInfo = [NSData dataWithBytes:nil length:0];
    
    ipAddress = [_configDict objectForKey:KEY_IP];
    if( ipAddress != nil ){
        if(inet_pton(AF_INET, [ipAddress cStringUsingEncoding:NSASCIIStringEncoding], &ip) == 1)
        {
            ip = htonl(ip);
        }
        else
        {
            EasyLinkLog(@"Target IP is not a correct IPv4 address, exit");
        }
    }

    ipAddress = [_configDict objectForKey:KEY_NETMASK];
    if( ipAddress != nil ){
        if(inet_pton(AF_INET, [ipAddress cStringUsingEncoding:NSASCIIStringEncoding], &netmask) == 1)
        {
            netmask = htonl(netmask);
        }
        else
        {
            EasyLinkLog(@"Target Netmask is not a correct IPv4 address, exit");
        }
    }
    
    ipAddress = [_configDict objectForKey:KEY_GATEWAY];
    if( ipAddress != nil ){
        if(inet_pton(AF_INET, [ipAddress cStringUsingEncoding:NSASCIIStringEncoding], &gateway) == 1)
        {
            gateway = htonl(gateway);
        }
        else
        {
            EasyLinkLog(@"Target gateway is not a correct IPv4 address, exit");
        }
    }
    
    ipAddress = [_configDict objectForKey:KEY_DNS1];
    if( ipAddress != nil ){
        if(inet_pton(AF_INET, [ipAddress cStringUsingEncoding:NSASCIIStringEncoding], &dns1) == 1)
        {
            dns1 = htonl(dns1);
        }
        else
        {
            EasyLinkLog(@"Target DNS 1 is not a correct IPv4 address, exit");
        }
    }
    
    ipAddress = [_configDict objectForKey:KEY_DNS2];
    if( ipAddress != nil ){
        if(inet_pton(AF_INET, [ipAddress cStringUsingEncoding:NSASCIIStringEncoding], &dns2) == 1)
        {
            dns2 = htonl(dns2);
        }
        else
        {
            EasyLinkLog(@"Target DNS 2 is not a correct IPv4 address, exit");
        }
    }
    
    bool dhcp = [[_configDict objectForKey:KEY_DHCP]  boolValue];
    
    if(dhcp==YES)
        ip = -1;
    
    
    
    if(easyLinkMode != EASYLINK_SOFT_AP){
        NSMutableData * userInfoWithIP = [NSMutableData dataWithCapacity:200];
        char seperate = '#';
        
        [userInfoWithIP appendData:userInfo];
        [userInfoWithIP appendData:[NSData dataWithBytes:&seperate length:1]];
        [userInfoWithIP appendBytes:(const void *)&id length:sizeof(uint32_t)];
        if(dhcp == NO){
            [userInfoWithIP appendBytes:&ip length:sizeof(uint32_t)];
            [userInfoWithIP appendBytes:&netmask length:sizeof(uint32_t)];
            [userInfoWithIP appendBytes:&gateway length:sizeof(uint32_t)];
            [userInfoWithIP appendBytes:&dns1 length:sizeof(uint32_t)];
            [userInfoWithIP appendBytes:&dns2 length:sizeof(uint32_t)];
        }
        
        NSMutableData *encryptedssid        = [NSMutableData dataWithCapacity: [ssid length]];
        NSMutableData *encryptedpasswd      = [NSMutableData dataWithCapacity: [passwd length]];
        NSMutableData *encryptedUserInfoWithIP = [NSMutableData dataWithCapacity: [userInfoWithIP length]];
        
        [encryptedssid              appendData:ssid];
        [encryptedpasswd            appendData:passwd];
        [encryptedUserInfoWithIP    appendData:userInfoWithIP];
        
        if(key != nil){
            [EASYLINK encrypt:encryptedssid             useRC4Key:key];
            [EASYLINK encrypt:encryptedpasswd           useRC4Key:key];
            [EASYLINK encrypt:encryptedUserInfoWithIP   useRC4Key:key];
        }

        [self prepareEasyLinkV2:encryptedssid password:encryptedpasswd info: encryptedUserInfoWithIP];
        [self prepareEasyLinkPlus:encryptedssid password:encryptedpasswd info: encryptedUserInfoWithIP];
        [self prepareEasyLinkAWS:encryptedssid password:encryptedpasswd];
    }
    
    _softAPStage = eState_initialize;
}

- (void)prepareEasyLink:(NSDictionary *)wlanConfigDict info: (NSData *)userInfo mode: (EasyLinkMode)easyLinkMode
{
    [self prepareEasyLink:wlanConfigDict info:userInfo mode:easyLinkMode encrypt:nil ];
}

- (void)prepareEasyLink:(NSDictionary *)wlanConfigDict info: (NSData *)userInfo mode: (EasyLinkMode)easyLinkMode encrypt: (NSData *)key
{
    int ret = 0;
    ret = SecRandomCopyBytes ( kSecRandomDefault, 4, (uint8_t *)&_identifier );
    if( ret == -1 ){
        EasyLinkLog(@"Gen random number error!");
        _identifier = 0;
    }
    [self prepareEasyLink:wlanConfigDict
                     info: userInfo
                  encrypt: key
                     mode: (EasyLinkMode)easyLinkMode
               identifier: _identifier];
}


- (void)prepareEasyLink_withFTC:(NSDictionary *)wlanConfigDict info: (NSData *)userInfo mode: (EasyLinkMode)easyLinkMode
{
    [self prepareEasyLink_withFTC:wlanConfigDict info:userInfo mode:easyLinkMode encrypt:nil];
}

- (void)prepareEasyLink_withFTC:(NSDictionary *)wlanConfigDict info: (NSData *)userInfo mode: (EasyLinkMode)easyLinkMode encrypt: (NSData *)key
{
    if(inet_pton(AF_INET, [[EASYLINK getIPAddress] cStringUsingEncoding:NSASCIIStringEncoding], &_identifier) == 1)
    {
        _identifier = htonl(_identifier);
    }
    else
    {
        EasyLinkLog(@"Local IP is not a correct IPv4 address!");
    }
    
    [self prepareEasyLink:wlanConfigDict
                     info: userInfo
                  encrypt: key
                     mode: (EasyLinkMode)easyLinkMode
               identifier: _identifier];
}

- (void)prepareEasyLinkV2:(NSData *)bSSID password:(NSData *)bpasswd info: (NSData *)userInfo
{
    if (bSSID == nil) bSSID = [NSData data];
    if (bpasswd == nil) bpasswd = [NSData data];
    if (userInfo == nil) userInfo = [NSData dataWithBytes:nil length:0];
    
    NSMutableData *mergeSsidPass = [NSMutableData dataWithCapacity:100];
    [mergeSsidPass appendData:bSSID];
    //[mergeSsidPass appendData: [bpasswd dataUsingEncoding:NSUTF8StringEncoding]];
    [mergeSsidPass appendData: bpasswd];
    
    const uint8_t *cUserInfo = [userInfo bytes];
    const uint8_t *cMergeSsidPass = [mergeSsidPass bytes];
    
    NSUInteger ssid_length = [bSSID length];
    NSUInteger passwd_length = [bpasswd length];
    NSUInteger userInfo_length = [userInfo length];
    NSUInteger mergeSsidPass_Length = [mergeSsidPass length];
    
    NSUInteger headerLength = 20;
    
    @synchronized(lockToken) {
    [multicastArray removeAllObjects];
    
    // 239.118.0.0
    for (NSUInteger idx = 0; idx != 5; ++idx) {
        NSMutableDictionary *dictionary = [NSMutableDictionary dictionary];
        [dictionary setValue:[NSMutableData dataWithLength:headerLength] forKey:@"sendData"];
        [dictionary setValue:@"239.118.0.0" forKey:@"host"];
        [dictionary setValue:[NSNumber numberWithFloat:easyLinkV2DelayPerBlock] forKey:@"Delay"];
        [multicastArray addObject:dictionary];
    }
    
    // 239.126.ssidlen.passwdlen
    NSMutableDictionary *dictionary = [NSMutableDictionary dictionary];
    [dictionary setValue:[NSMutableData dataWithLength:headerLength] forKey:@"sendData"];
    [dictionary setValue:[NSString stringWithFormat:@"239.126.%lu.%lu", (unsigned long)ssid_length, (unsigned long)passwd_length] forKey:@"host"];
    [dictionary setValue:[NSNumber numberWithFloat:easyLinkV2DelayPerBlock] forKey:@"Delay"];
    [multicastArray addObject:dictionary];
    headerLength++;
    
    // 239.126.mergeString[idx],mergeString[idx+1]
    for (NSUInteger idx = 0; idx < mergeSsidPass_Length; idx += 2, headerLength++) {
        Byte a = cMergeSsidPass[idx];
        Byte b = 0;
        if (idx + 1 != mergeSsidPass_Length)
            b = cMergeSsidPass[idx+1];
        
        dictionary = [NSMutableDictionary dictionary];
        
        [dictionary setValue:[NSMutableData dataWithLength:headerLength] forKey:@"sendData"];
        [dictionary setValue:[NSString stringWithFormat:@"239.126.%d.%d", a, b] forKey:@"host"];
        [dictionary setValue:[NSNumber numberWithFloat:easyLinkV2DelayPerBlock] forKey:@"Delay"];
        [multicastArray addObject:dictionary];
    }
    
    // 239.126.userinfolen.0
    dictionary = [NSMutableDictionary dictionary];
    [dictionary setValue:[NSMutableData dataWithLength:headerLength] forKey:@"sendData"];
    [dictionary setValue:[NSString stringWithFormat:@"239.126.%lu.0", (unsigned long)userInfo_length] forKey:@"host"];
    [dictionary setValue:[NSNumber numberWithFloat:easyLinkV2DelayPerBlock] forKey:@"Delay"];
    [multicastArray addObject:dictionary];
    headerLength++;
    
    // 239.126.userinfo[idx],userinfo[idx+1]
    for (NSUInteger idx = 0; idx < userInfo_length; idx += 2, headerLength++) {
        Byte a = cUserInfo[idx];
        Byte b = 0;
        if (idx + 1 != userInfo_length)
            b = cUserInfo[idx+1];
        
        dictionary = [NSMutableDictionary dictionary];
        [dictionary setValue:[NSMutableData dataWithLength:headerLength] forKey:@"sendData"];
        [dictionary setValue:[NSString stringWithFormat:@"239.126.%d.%d", a, b] forKey:@"host"];
        [dictionary setValue:[NSNumber numberWithFloat:easyLinkV2DelayPerBlock] forKey:@"Delay"];
        [multicastArray addObject:dictionary];
    }
    }
}

- (void)prepareEasyLinkPlus:(NSData *)bSSID password:(NSData *)bpasswd info: (NSData *)userInfo
{
    if (bSSID == nil) bSSID = [NSData data];
    if (bpasswd == nil) bpasswd = [NSData data];
    if (userInfo == nil) userInfo = [NSData dataWithBytes:nil length:0];
    
    const uint8_t *cSSID = [bSSID bytes];
    const uint8_t *cPasswd = [bpasswd bytes];
    const uint8_t *cUserInfo = [userInfo bytes];
    
    NSUInteger ssid_length = [bSSID length];
    NSUInteger passwd_length = [bpasswd length];
    NSUInteger userInfo_length = [userInfo length];
    
    uint16_t chechSum = 0;
    
    uint32_t seqNo = 0;
    uint32_t seqHook = 0;
    
    NSUInteger totalLen = 0x5 + ssid_length + passwd_length + userInfo_length;
    
    NSUInteger addedConst[4] = {0x100, 0x200, 0x300, 0x400};
    NSUInteger addedConstIdx = 0;
    
    @synchronized(lockToken) {
    [broadcastArray removeAllObjects];
    
    [broadcastArray insertEasyLinkPlusData:0xAA delay:easyLinkPlusDelayPerByte];
    [broadcastArray insertEasyLinkPlusData:0xAB delay:easyLinkPlusDelayPerByte];
    [broadcastArray insertEasyLinkPlusData:0xAC delay:easyLinkPlusDelayPerByte];
    
    /*Total len*/
    [broadcastArray insertEasyLinkPlusData:( totalLen + addedConst[(addedConstIdx++)%4] ) delay:easyLinkPlusDelayPerByte];
    [broadcastArray insertEasyLinkPlusBlockIndex: &seqHook forSeqNo:seqNo++ delay:easyLinkPlusDelayPerByte blockDelay:easyLinkPlusDelayPerBlock];
    chechSum += totalLen;
    
    /*SSID len*/
    [broadcastArray insertEasyLinkPlusData:( ssid_length + addedConst[(addedConstIdx++)%4] ) delay:easyLinkPlusDelayPerByte];
    [broadcastArray insertEasyLinkPlusBlockIndex: &seqHook forSeqNo:seqNo++ delay:easyLinkPlusDelayPerByte blockDelay:easyLinkPlusDelayPerBlock];
    chechSum += ssid_length;
    
    /*Key len*/
    [broadcastArray insertEasyLinkPlusData:( passwd_length + addedConst[(addedConstIdx++)%4] ) delay:easyLinkPlusDelayPerByte];
    [broadcastArray insertEasyLinkPlusBlockIndex: &seqHook forSeqNo:seqNo++ delay:easyLinkPlusDelayPerByte blockDelay:easyLinkPlusDelayPerBlock];
    chechSum += passwd_length;
    
    /*SSID*/
    for (NSUInteger idx = 0; idx != ssid_length; ++idx) {
        [broadcastArray insertEasyLinkPlusData:( cSSID[idx] + addedConst[(addedConstIdx++)%4] ) delay:easyLinkPlusDelayPerByte];
        [broadcastArray insertEasyLinkPlusBlockIndex: &seqHook forSeqNo:seqNo++ delay:easyLinkPlusDelayPerByte blockDelay:easyLinkPlusDelayPerBlock];
        chechSum += cSSID[idx];
    }
    
    /*Key*/
    for (NSUInteger idx = 0; idx != passwd_length; ++idx) {
        [broadcastArray insertEasyLinkPlusData:( cPasswd[idx] + addedConst[(addedConstIdx++)%4] ) delay:easyLinkPlusDelayPerByte];
        [broadcastArray insertEasyLinkPlusBlockIndex: &seqHook forSeqNo:seqNo++ delay:easyLinkPlusDelayPerByte blockDelay:easyLinkPlusDelayPerBlock];
        chechSum += cPasswd[idx];
    }
    
    
    /*User info*/
    for (NSUInteger idx = 0; idx != userInfo_length; ++idx) {
        [broadcastArray insertEasyLinkPlusData:( cUserInfo[idx] + addedConst[(addedConstIdx++)%4] ) delay:easyLinkPlusDelayPerByte];
        [broadcastArray insertEasyLinkPlusBlockIndex: &seqHook forSeqNo:seqNo++ delay:easyLinkPlusDelayPerByte blockDelay:easyLinkPlusDelayPerBlock];
        chechSum += cUserInfo[idx];
    }
    
    /*Checksum high*/
    [broadcastArray insertEasyLinkPlusData:( ((chechSum&0xFF00)>>8) + addedConst[(addedConstIdx++)%4] ) delay:easyLinkPlusDelayPerByte];
    [broadcastArray insertEasyLinkPlusBlockIndex: &seqHook forSeqNo:seqNo++ delay:easyLinkPlusDelayPerByte blockDelay:easyLinkPlusDelayPerBlock];
    
    /*Checksum low*/
    [broadcastArray insertEasyLinkPlusData:( (chechSum&0x00FF) + addedConst[(addedConstIdx++)%4] ) delay:easyLinkPlusDelayPerByte];
    [broadcastArray insertEasyLinkPlusBlockIndex: &seqHook forSeqNo:seqNo++ delay:easyLinkPlusDelayPerByte blockDelay:easyLinkPlusDelayPerBlock];
    }
}
/*
 * 8bit -> 6bit
 *
 * serialize chinese char from 8bit to 6bit
 */
static void encode_chinese(uint8_t *in, uint8_t in_len, uint8_t *out, uint8_t *out_len)
{
    uint8_t bit[33 * 8] = { 0 };
    uint8_t i, j;
    uint8_t output_len = ((in_len * 8) + 5) / 6;
    
    //char to bit stream
    for (i = 0; i < in_len; i++) {
        for (j = 0; j < 8; j++) {
            bit[i * 8 + j] = (in[i] >> j) & 0x01;
        }
    }
    
    out[output_len] = '\0'; /* NULL-terminated */
    for (i = 0; i < output_len; i++) {
        for (j = 0, out[i] = 0; j < 6; j++) {
            out[i] |= bit[i * 6 + j] << j;
        }
    }
    
    if (out_len) {
        *out_len = output_len;
    }
}

- (void)prepareEasyLinkAWS:(NSData *)ssid password:(NSData *)passwd
{
    if (ssid == nil) ssid = [NSData data];
    if (passwd == nil) passwd = [NSData data];
    
    NSUInteger blockIndex = 0;
    NSUInteger dataIndex = 0;
    NSUInteger idx;
    uint8_t flag = 0x0;
    uint8_t cSsidZipped[100];
    uint8_t cPasswdZipped[100];
    uint16_t chechSum = 0;
    BOOL isASSIC = YES;
    
    const uint8_t *cSsid = [ssid bytes];
    const uint8_t *cPasswd = [passwd bytes];
    
    NSUInteger ssidLength = [ssid length];
    NSUInteger passwdLength = [passwd length];
    NSUInteger totalLen = 0;
    
    /* ZIP SSID */
    for (idx=0; idx < ssidLength; idx++) {
        if (cSsid[idx] < 0x20 || cSsid[idx] >0x7F) {
            isASSIC = NO;
            break;
        };
    }
    
    if (isASSIC == YES) {
        flag = 0x1;
        for(idx=0; idx < ssidLength; idx++) {
            cSsidZipped[idx] = cSsid[idx] - 0x20;
        }
    } else {
        flag = 0x21;
        encode_chinese((uint8_t *)cSsid, ssidLength, cSsidZipped, (uint8_t *)&ssidLength);
    }
    
    /* ZIP PASSWORD */
    for(idx=0; idx<passwdLength; idx++) {
        cPasswdZipped[idx] = cPasswd[idx] - 0x20;
    }
    
    @synchronized(lockToken) {
    [awsArray removeAllObjects];
    
    /* EasyLink Header */
    [awsArray insertEasyLinkAWSHeader:0x4E0 delay:easyLinkAWSDelayPerByte];
    [awsArray insertEasyLinkAWSHeader:0x4E0 delay:easyLinkAWSDelayPerByte];
    [awsArray insertEasyLinkAWSHeader:0x4E0 delay:easyLinkAWSDelayPerByte];

    /*Total len*/
    totalLen = ssidLength + passwdLength + 6; // total_len | flag | ssid_len | key_len | <ssid> | <key> | crc16_high | crc16_low
    [awsArray insertEasyLinkAWSData:totalLen atIndex:dataIndex++ atBlockIndex:&blockIndex delay:easyLinkAWSDelayPerByte];
    chechSum += totalLen;
    
    /*Flag*/
    [awsArray insertEasyLinkAWSData:flag atIndex:dataIndex++ atBlockIndex:&blockIndex delay:easyLinkAWSDelayPerByte];
    chechSum += flag;
    
    /*SSID len*/
    [awsArray insertEasyLinkAWSData:ssidLength atIndex:dataIndex++ atBlockIndex:&blockIndex delay:easyLinkAWSDelayPerByte];
    chechSum += ssidLength;
    
    /*Key len*/
    [awsArray insertEasyLinkAWSData:passwdLength atIndex:dataIndex++ atBlockIndex:&blockIndex delay:easyLinkAWSDelayPerByte];
    chechSum += passwdLength;
    
    /*SSID*/
    for (idx = 0; idx != ssidLength; ++idx) {
        [awsArray insertEasyLinkAWSData:cSsidZipped[idx] atIndex:dataIndex++ atBlockIndex:&blockIndex delay:easyLinkAWSDelayPerByte];
        chechSum += cSsidZipped[idx];
    }
    
    /*PASSWORD*/
    for (idx = 0; idx != passwdLength; ++idx) {
        [awsArray insertEasyLinkAWSData:cPasswdZipped[idx] atIndex:dataIndex++ atBlockIndex:&blockIndex delay:easyLinkAWSDelayPerByte];
        chechSum += cPasswdZipped[idx];
    }
    
    /*Checksum high*/
    [awsArray insertEasyLinkAWSData:((chechSum & (0x7F << 7)) << 1)>>8 atIndex:dataIndex++ atBlockIndex:&blockIndex delay:easyLinkAWSDelayPerByte];
    
    /*Checksum low*/
    [awsArray insertEasyLinkAWSData:chechSum&0x7F atIndex:dataIndex++ atBlockIndex:&blockIndex delay:easyLinkAWSDelayPerByte];
    }
}


- (void)transmitSettings
{
    
    [self stopTransmitting];
    
    _netServiceBrowser.delegate = nil;
    _netServiceBrowser = nil;
    
    [awsHostsArrayPerSearch removeAllObjects];
    
    for (NSNetService *service in _netServiceArray){
        service.delegate = nil;
        [service stopMonitoring];
    }
    _netServiceArray = nil;
    
    NSNetServiceBrowser *aNetServiceBrowser = [[NSNetServiceBrowser alloc] init];
    if(!aNetServiceBrowser) {
        // The NSNetServiceBrowser couldn't be allocated and initialized.
        EasyLinkLog(@"Network service error!");
    }
    aNetServiceBrowser.delegate = self;
    _netServiceBrowser = aNetServiceBrowser;
    _netServiceArray = [[NSMutableArray alloc]initWithCapacity:10];
    
    [_netServiceBrowser searchForServicesOfType:kEasyLinkConfigServiceType inDomain:kInitialDomain];
    
    if(_mode == EASYLINK_V2_PLUS){
        _broadcastSending = true;
        _multicastSending = true;
        
        [self performSelector:@selector(broadcastStartConfigure:) withObject:self];
        [self performSelector:@selector(multicastStartConfigure:) withObject:self];
        
    }else if(_mode == EASYLINK_PLUS){
        _broadcastSending = true;
        [self performSelector:@selector(broadcastStartConfigure:) withObject:self];
        
    }else if(_mode == EASYLINK_V2){
        _multicastSending = true;
        [self performSelector:@selector(multicastStartConfigure:) withObject:self];
        
    }else if(_mode == EASYLINK_AWS){
        _awsSending = true;
        [self performSelector:@selector(awsStartConfigure:) withObject:self];

    }else if(_mode == EASYLINK_SOFT_AP) {
        _softAPSending = true;
    }
}

- (void)stopTransmitting
{
    _broadcastSending = false;
    _multicastSending = false;
    _awsSending = false;

    _softAPSending = false;
}

- (void)broadcastStartConfigure:(id)sender{
    NSError *err;
    float plusDelay;
    NSData *plusData;
    
    @synchronized(lockToken) {
        if(_broadcastSending == true){
            if (broadcastSocket == nil) {
                broadcastSocket = [[ELAsyncUdpSocket alloc] initWithDelegate:nil];
                [broadcastSocket enableBroadcast:YES error:&err];
            }
            if (_broadcastCount >= [broadcastArray count]) _broadcastCount = 0;
            plusDelay = [[[broadcastArray objectAtIndex:_broadcastCount] objectForKey:@"Delay"] floatValue];
            plusData = [[broadcastArray objectAtIndex:_broadcastCount] objectForKey:@"sendData"];
            [broadcastSocket sendData:plusData toHost:[EASYLINK getBroadcastAddress] port:50000 withTimeout:10 tag:0];
            [self performSelector:@selector(broadcastStartConfigure:) withObject:self afterDelay:plusDelay];
            _broadcastCount++;
        }
        else{
            if (broadcastSocket != nil ){
                [broadcastSocket close];
                broadcastSocket = nil;
            }
        }
    }
}

- (void)awsStartConfigure:(id)sender{
    NSError *err;
    float awsDelay;
    NSData *awsData;
    
    @synchronized(lockToken) {
        if(_awsSending == true){
            if (awsSocket == nil) {
                awsSocket = [[ELAsyncUdpSocket alloc] initWithDelegate:nil];
                [awsSocket enableBroadcast:YES error:&err];
            }
            if (_awsCount >= [awsArray count]) _awsCount = 0;
            awsDelay = [[[awsArray objectAtIndex:_awsCount] objectForKey:@"Delay"] floatValue];
            awsData = [[awsArray objectAtIndex:_awsCount] objectForKey:@"sendData"];
            [awsSocket sendData:awsData toHost:[EASYLINK getBroadcastAddress] port:50000 withTimeout:10 tag:0];
            [self performSelector:@selector(awsStartConfigure:) withObject:self afterDelay:awsDelay];
            _awsCount++;
        }
        else{
            if (awsSocket != nil ){
                [awsSocket close];
                awsSocket = nil;
            }
        }
    }
}

- (void)multicastStartConfigure:(id)sender{
    NSError *err;
    float multicastDelay;
    NSData *multicastData;
    NSString *multicastHost;
    
    @synchronized(lockToken) {
        if(_multicastSending == true){
            if (multicastSocket == nil) {
                multicastSocket = [[ELAsyncUdpSocket alloc] initWithDelegate:nil];
                [multicastSocket enableBroadcast:YES error:&err];
            }
            if (_multicastCount >= [multicastArray count]) _multicastCount = 0;
            multicastDelay = [[[multicastArray objectAtIndex:_multicastCount] objectForKey:@"Delay"] floatValue];
            multicastData = [[multicastArray objectAtIndex:_multicastCount] objectForKey:@"sendData"];
            multicastHost = [[multicastArray objectAtIndex:_multicastCount] objectForKey:@"host"];
            
            [multicastSocket sendData:multicastData toHost:multicastHost port:65523 withTimeout:10 tag:0];
            [self performSelector:@selector(multicastStartConfigure:) withObject:self afterDelay:multicastDelay];
            _multicastCount++;
        }
        else{
            if (multicastSocket != nil ){
                [multicastSocket close];
                multicastSocket = nil;
            }
        }
    }
}

#pragma mark - Service browser

- (void)netServiceBrowser:(NSNetServiceBrowser*)netServiceBrowser didFindService:(NSNetService*)service moreComing:(BOOL)moreComing {
    // If a service came online, add it to the list and update the table view if no more events are queued.
    service.delegate = self;
    
    EasyLinkLog(@"service found %@",[service name]);
    [service resolveWithTimeout:0.0];
    [_netServiceArray addObject:service];
}

- (void)netService:(NSNetService *)sender didUpdateTXTRecordData:(NSData *)data
{
    EasyLinkLog(@"service %@ txt record updated",[sender name]);
    if ([[sender addresses] count] != 0)
        [self netServiceDidResolveAddress:sender];
}

- (void)netServiceDidResolveAddress:(NSNetService *)service
{
    NSDictionary *txtData;
    NSError *err;
    NSString *_address;
    NSNumber *tag = nil;
    uint32_t _identifier_current = 0;
    
    EasyLinkLog(@"service %@ netServiceDidResolveAddress",[service name]);
    
    if ([[service addresses] count] == 0) return;
    
    _address = [[[service addresses] objectAtIndex: 0] host];
    txtData = [NSNetService dictionaryFromTXTRecordData: [service TXTRecordData]];
    
    sscanf( [[[NSString alloc] initWithData:[txtData objectForKey:@"ID"] encoding:NSUTF8StringEncoding] cStringUsingEncoding:NSUTF8StringEncoding], "%x", &_identifier_current );
    
    EasyLinkLog(@"Found address: %@, id_current: %x, id_target:%x", _address,_identifier_current, _identifier);
    
    if( _identifier !=  _identifier_current && _identifier_current != 0 ){
        EasyLinkLog(@"Identifier not match");
        return;
    }
    
    for (NSDictionary *client in ftcClients){
        if( [[client objectForKey:@"Host"]isEqualToString:_address]){
            [[client objectForKey:@"Socket"] disconnect];
            break;
        }
    }
    
    /* Find a empty place to store the client http data, use the place id as client id and sock tag */
    for (NSUInteger idx=0; idx!=MessageCount; idx++) {
        if(inComingMessageArray[idx]==nil){
            inComingMessageArray[idx] = CFHTTPMessageCreateEmpty(kCFAllocatorDefault, false);
            tag = [NSNumber numberWithLong:(long)idx];
            break;
        }
    }
    
    if(tag == nil)
        return;
    
    NSMutableDictionary *client = [[NSMutableDictionary alloc] initWithCapacity:5];
    ELAsyncSocket *sock = [[ELAsyncSocket alloc] initWithDelegate:self];
    [client setObject:sock forKey:@"Socket"];
    [client setObject:tag forKey:@"Tag"];
    [client setObject:_address forKey:@"Host"];
    [client setObject:@0 forKey:@"Error"];
    [client setObject:[NSNumber numberWithInteger:service.port] forKey:@"Port"];
    
    [ftcClients addObject:client];
    EasyLinkLog(@"New socket client, %d", [tag intValue]);
    
    /* Client found in soft ap mode (Send configuration now) */
    if([[NSString alloc]initWithData:[txtData objectForKey:@"wlan unconfigured"] encoding:NSASCIIStringEncoding].boolValue == YES){
        _wlanUnConfigured = true;
    }
    /* client found in station mode (Easylink success), inform the delegate */
    else{
        _wlanUnConfigured = false;
        if([theDelegate respondsToSelector:@selector(onFound: withName: mataData:)]){
            [theDelegate onFound:tag withName:service.name mataData:txtData];
        }
    }
    
    if([[[NSString alloc] initWithData:[txtData objectForKey:@"FTC"] encoding:NSUTF8StringEncoding] isEqualToString:@"T"] || [txtData objectForKey:@"FTC"] == nil){
        EasyLinkLog(@"Connect to: %@:%ld", _address, (long)service.port);
        [sock connectToHost:[client objectForKey:@"Host"] onPort:[[client objectForKey:@"Port"] integerValue] withTimeout:5 error:&err];
    }
    
    service.delegate = nil;
    [service stopMonitoring];
    [_netServiceArray removeObject:service];
}

/* On found by AWS Echo server */
- (BOOL)onUdpSocket:(ELAsyncUdpSocket *)sock didReceiveData:(NSData *)data withTag:(long)tag fromHost:(NSString *)host port:(UInt16)port
{
    NSError *err;
    NSNumber *ftcClientTag = nil;
    NSString *module, *mac, *name;
    NSNumber *ftc_port;
    const char *cMac;
    unsigned int mac_hex[6];
    
    /* Check socket */
    if (sock !=awsEchoServer ) return YES;
    
    /* Check client port */
    if (port != AWS_ECHO_CLIENT_PORT ) return YES;
    
    /* Stop easylink sending notify */
    if ( [data length] == 1 && *(uint8_t *)[data bytes] == 0xee ) {
        EasyLinkLog(@"Receive stop sending notify");
        [self stopTransmitting];
        [awsEchoServer receiveWithTimeout:-1 tag:0];
        return YES;
    }
    
    /* Send a responce anyway, content is not important in aws protocol */
    [awsEchoServer sendData: [[[NSString alloc] initWithFormat:@"{\"STATUS\":\"OK\",\"ExtraData\":\"%@\"}",_userInfo_str]
                                             dataUsingEncoding:NSUTF8StringEncoding]
                     toHost:host
                       port:port
                withTimeout:10
                        tag:0];
    [awsEchoServer receiveWithTimeout:-1 tag:0];
    
//    String ack_str = "{\"STATUS\":\"OK\",";
//    ack_str = ack_str + "\"ExtraData\":\"" + ExtraData + "\"}";
    
    /* Check client address, filter duplicated address */
    for (NSString *object in awsHostsArrayPerSearch){
        if( [object isEqualToString:host]){
            return YES;
        }
    }
    
    EasyLinkLog(@"AES echo client found at %@",host);
   
    NSMutableDictionary *clientInfo = [NSJSONSerialization JSONObjectWithData:data
                                                                      options:NSJSONReadingMutableContainers|NSJSONReadingMutableLeaves
                                                                        error:&err];
    
    module = [clientInfo objectForKey:@"MD"];
    mac = [clientInfo objectForKey:@"MAC"];
    
    if ( module == nil || mac== nil ) {
        EasyLinkLog(@"AWS echo kMalformedErr");
        return YES;
    }
    
    cMac = [mac cStringUsingEncoding:NSUTF8StringEncoding];
    sscanf(cMac, "%02X:%02X:%02X:%02X:%02X:%02X", &mac_hex[0], &mac_hex[1], &mac_hex[2], &mac_hex[3], &mac_hex[4], &mac_hex[5]);
    
    
    name = [[[NSString alloc] init]stringByAppendingFormat:@"%@(%02X%02X%02X)", module, mac_hex[3], mac_hex[4], mac_hex[5] ];
    
    /* For compatiablity with mDNS discovery, convert value to NSData type */
    [clientInfo enumerateKeysAndObjectsUsingBlock: ^(NSString *key, id obj, BOOL *stop)  {
        if ( [obj isKindOfClass:[NSString class]] ) {
            [clientInfo setObject:[(NSString *)obj dataUsingEncoding:NSUTF8StringEncoding] forKey:key];
        }
    }];
    
    /* Find a empty place to store the client http data, use the place id as client id and sock tag */
    for (NSUInteger idx=0; idx!=MessageCount; idx++) {
        if(inComingMessageArray[idx]==nil){
            inComingMessageArray[idx] = CFHTTPMessageCreateEmpty(kCFAllocatorDefault, false);
            ftcClientTag = [NSNumber numberWithLong:(long)idx];
            break;
        }
    }
    
    if(ftcClientTag == nil) return YES;
    
    NSMutableDictionary *client = [[NSMutableDictionary alloc] initWithCapacity:5];
    ELAsyncSocket *ftc_sock = [[ELAsyncSocket alloc] initWithDelegate:self];
    [client setObject:ftc_sock forKey:@"Socket"];
    [client setObject:ftcClientTag forKey:@"Tag"];
    [client setObject:host forKey:@"Host"];
    [client setObject:@0 forKey:@"Error"];
    [ftcClients addObject:client];
    [awsHostsArrayPerSearch addObject:host];
    
    EasyLinkLog(@"New socket client, %d", [ftcClientTag intValue]);
    
#ifdef AWS_COMPATIBLE
    _wlanUnConfigured = false;
    if([theDelegate respondsToSelector:@selector(onFound: withName: mataData:)]){
        [theDelegate onFound:ftcClientTag withName:name mataData:clientInfo];
    }
#else

    /* Client found in soft ap mode (Send configuration now) */
    if([[NSString alloc]initWithData:[clientInfo objectForKey:@"wlan unconfigured"] encoding:NSASCIIStringEncoding].boolValue == YES){
        _wlanUnConfigured = true;
    }
    /* client found in station mode (Easylink success), inform the delegate */
    else
    {
        _wlanUnConfigured = false;
        if([theDelegate respondsToSelector:@selector(onFound: withName: mataData:)]){
            [clientInfo setObject:host forKey:@"IP"];
            [theDelegate onFound:ftcClientTag withName:name mataData:clientInfo];
        }
    }
    
    /* test function
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5f*NSEC_PER_SEC)), dispatch_get_main_queue(),
                   ^{
                       [self closeFTCClient:ftcClientTag];
                   });
     */
    
    /* Connect to config server if config server is available */
   if([[[NSString alloc] initWithData:[clientInfo objectForKey:@"FTC"] encoding:NSUTF8StringEncoding] isEqualToString:@"T"]){
       
       if ( (ftc_port = [clientInfo objectForKey:@"PORT"]) == nil ) {
           ftc_port = @FTC_PORT;
       }
       [client setObject:ftc_port forKey:@"Port"];
       
       EasyLinkLog(@"Connect to: %@:%ld", host, (unsigned long)[ftc_port unsignedIntegerValue]);
       [ftc_sock connectToHost:host onPort: [ftc_port unsignedIntegerValue] withTimeout:5 error:&err];
    }
#endif
    return YES;
}

#pragma mark - First time configuration

- (void)closeFTCClient:(NSNumber *)client
{
    NSMutableDictionary *clientDict;
    for (NSMutableDictionary *object in ftcClients){
        if( [[object objectForKey:@"Tag"] longValue] == [client longValue]){
            clientDict = object;
            break;
        }
    }
    
    if(clientDict == nil) {
        if([theDelegate respondsToSelector:@selector(onDisconnectFromFTC:withError:)] && _wlanUnConfigured == false){
            [theDelegate onDisconnectFromFTC:client withError: NO];
        }
        return;
    }
    
    EasyLinkLog(@"Close FTC client %d", [client intValue]);
    ELAsyncSocket *clientSocket = [clientDict objectForKey:@"Socket"];
    //[clientSocket setDelegate:nil];
    //if( [clientSocket isConnected] == YES )
        [clientSocket disconnect];
    //else
        //[self onSocketDidDisconnect:clientSocket];
    
    //clientSocket = nil;
    
    if(inComingMessageArray[[client intValue]] != nil){
        CFRelease(inComingMessageArray[[client intValue]]) ;
        inComingMessageArray[[client intValue]] = nil;
    }
}


- (void)configFTCClient:(NSNumber *)client withConfiguration:(NSDictionary* )configDict
{
    NSError *err;
    CFHTTPMessageRef httpRespondMessage;
    NSMutableDictionary *clientDict;
    EasyLinkLog(@"Configured");
    char contentLen[50];
    
    if(configDict==nil)
        configDict = [NSDictionary dictionary];
    
    NSData *configData = [NSJSONSerialization dataWithJSONObject:configDict options:0 error:&err];
    
    for (NSMutableDictionary *object in ftcClients){
        if( [[object objectForKey:@"Tag"] longValue] == [client longValue]){
            clientDict = object;
            break;
        }
    }
    
    if( [[clientDict objectForKey:@"FTC"]  isEqual: @YES]){ //old version
        httpRespondMessage = CFHTTPMessageCreateResponse ( kCFAllocatorDefault, 200, NULL, kCFHTTPVersion1_1 );
    }else{ //new version
        CFURLRef urlRef = CFURLCreateWithString(kCFAllocatorDefault, CFSTR("/config-write"), NULL);
        httpRespondMessage = CFHTTPMessageCreateRequest(kCFAllocatorDefault, CFSTR("POST"), urlRef, kCFHTTPVersion1_1) ;
    }
    
    CFHTTPMessageSetHeaderFieldValue(httpRespondMessage, CFSTR("Content-Type"), CFSTR("application/json"));
    CFHTTPMessageSetHeaderFieldValue(httpRespondMessage, CFSTR("Connection"), CFSTR("close"));
    
    snprintf(contentLen, 50, "%lu", (unsigned long)[configData length]);
    CFStringRef length = CFStringCreateWithCString(kCFAllocatorDefault, contentLen, kCFStringEncodingASCII);
    //CFStringRef length = CFStringCreateWithCharacters (kCFAllocatorDefault, (unichar *)contentLen, strlen(contentLen));
    CFHTTPMessageSetHeaderFieldValue(httpRespondMessage, CFSTR("Content-Length"),length);
    CFHTTPMessageSetBody(httpRespondMessage, (__bridge CFDataRef)configData);
    
    
    CFDataRef httpData = CFHTTPMessageCopySerializedMessage ( httpRespondMessage );
    [[clientDict objectForKey:@"Socket"] writeData:(__bridge_transfer NSData*)httpData
                                       withTimeout:-1
                                               tag:[client longValue]];
    
    /*Recv data that server can send FIN+ACK when client disconnect*/
    [[clientDict objectForKey:@"Socket"] readDataWithTimeout:-1
                                                         tag:[client longValue]];
    
    closeFTCClientTimer = [NSTimer scheduledTimerWithTimeInterval:5
                                                           target:self
                                                         selector:@selector(closeClient:)
                                                         userInfo:[clientDict objectForKey:@"Socket"]
                                                          repeats:NO];
}

- (void)otaFTCClient:(NSNumber *)client withOTAData: (NSData *)otaData
{
    CFHTTPMessageRef httpRespondMessage;
    NSMutableDictionary *clientDict;
    EasyLinkLog(@"Configured");
    char contentLen[50];
    
    for (NSMutableDictionary *object in ftcClients){
        if( [[object objectForKey:@"Tag"] longValue] == [client longValue]){
            clientDict = object;
            break;
        }
    }
    
    if( CFHTTPMessageIsRequest (inComingMessageArray[[client intValue]]) == false){
        CFURLRef urlRef = CFURLCreateWithString(kCFAllocatorDefault, CFSTR("/OTA"), NULL);
        httpRespondMessage = CFHTTPMessageCreateRequest(kCFAllocatorDefault, CFSTR("POST"), urlRef, kCFHTTPVersion1_1) ;
        CFRelease(urlRef);
    }else{
        httpRespondMessage = CFHTTPMessageCreateResponse ( kCFAllocatorDefault, 200, NULL, kCFHTTPVersion1_1 );
    }
    
    CFHTTPMessageSetHeaderFieldValue(httpRespondMessage, CFSTR("Content-Type"), CFSTR("application/ota-stream"));
    
    snprintf(contentLen, 50, "%lu", (unsigned long)[otaData length]);
    CFStringRef length = CFStringCreateWithCString(kCFAllocatorDefault, contentLen, kCFStringEncodingASCII);
    //CFStringRef CFStringCreateWithCharacters (kCFAllocatorDefault, (unichar *)contentLen, strlen(contentLen));
    CFHTTPMessageSetHeaderFieldValue(httpRespondMessage, CFSTR("Content-Length"),length);
    CFHTTPMessageSetBody(httpRespondMessage, (__bridge CFDataRef)otaData);
    
    
    CFDataRef httpData = CFHTTPMessageCopySerializedMessage ( httpRespondMessage );
    CFRelease(httpRespondMessage);
    [[clientDict objectForKey:@"Socket"] writeData:(__bridge_transfer NSData*)httpData
                                       withTimeout:-1
                                               tag:[client longValue]];
    
    /*Recv data that server can send FIN+ACK when client disconnect*/
    [[clientDict objectForKey:@"Socket"] readDataWithTimeout:-1
                                                         tag:[client longValue]];
    
    closeFTCClientTimer = [NSTimer scheduledTimerWithTimeInterval:10
                                                           target:self
                                                         selector:@selector(closeClient:)
                                                         userInfo:[clientDict objectForKey:@"Socket"]
                                                          repeats:NO];
    CFRelease(length);
}


#pragma mark - TCP delegate

- (void)onSocket:(ELAsyncSocket *)sock didConnectToHost:(NSString *)host port:(UInt16)port
{
    EasyLinkLog(@"connected");
    
    char contentLen[50];
    NSError *err;
    NSNumber *tag = nil;
    
    if(_wlanUnConfigured == true){ //uAP mode -> connected to uap, send config
        NSMutableDictionary *configDictTmp = [NSMutableDictionary dictionaryWithDictionary:_configDict];
        
        [configDictTmp setObject:[[NSString alloc] initWithData:[configDictTmp objectForKey:KEY_SSID] encoding:NSUTF8StringEncoding]
                          forKey:KEY_SSID];
        [configDictTmp setObject:[NSNumber numberWithInt:_identifier] forKey:@"IDENTIFIER"];
        
        NSData *configData = [NSJSONSerialization dataWithJSONObject:configDictTmp options:0 error:&err];
        
        
        CFURLRef urlRef = CFURLCreateWithString(kCFAllocatorDefault, CFSTR("/config-write-uap"), NULL);
        CFHTTPMessageRef httpRequestMessage = CFHTTPMessageCreateRequest (kCFAllocatorDefault,
                                                                          CFSTR("POST"),
                                                                          urlRef,
                                                                          kCFHTTPVersion1_1);
        CFHTTPMessageSetHeaderFieldValue(httpRequestMessage, CFSTR("Content-Type"), CFSTR("application/json"));
        
        snprintf(contentLen, 50, "%lu", (unsigned long)[configData length]);
        CFStringRef length = CFStringCreateWithCString(kCFAllocatorDefault, contentLen, kCFStringEncodingASCII);
        CFHTTPMessageSetHeaderFieldValue(httpRequestMessage, CFSTR("Content-Length"),length);
        CFHTTPMessageSetBody(httpRequestMessage, (__bridge CFDataRef)configData);
        
        CFDataRef httpData = CFHTTPMessageCopySerializedMessage ( httpRequestMessage );
        [sock writeData:(__bridge NSData*)httpData withTimeout:-1 tag:[tag intValue]];
        CFRelease(httpData);
        CFRelease(httpRequestMessage);
        CFRelease(urlRef);
        CFRelease(length);
        
        [sock readDataWithTimeout:-1 tag:[tag intValue]];
    }else{ //Connected to target ap, read config
        
        ELAsyncSocket *clientSocket = sock;
        
        for( NSDictionary *client in ftcClients){
            
            if( [client objectForKey:@"Socket"] == clientSocket )
            {
                tag = [client objectForKey:@"Tag"];
                /* This socket is created by FTC on iOS,
                 device will report its configurations automatically, this will happen
                 in EasyLink with FTC mode */
                if( [[client objectForKey:@"FTC"]  isEqual: @YES])
                {
                    return;
                }
                break;
            }
        }
        
        if(tag == nil)
            return;
        
        /* We need to send a /config-read http request to get client's configuration,
         this will happen in EasyLink with mDNS discovery */
        
        CFURLRef urlRef = CFURLCreateWithString(kCFAllocatorDefault, CFSTR("/config-read"), NULL);
        CFHTTPMessageRef httpRequestMessage = CFHTTPMessageCreateRequest (kCFAllocatorDefault,
                                                                          CFSTR("GET"),
                                                                          urlRef,
                                                                          kCFHTTPVersion1_1);
        CFDataRef httpData = CFHTTPMessageCopySerializedMessage ( httpRequestMessage );
        [sock writeData:(__bridge NSData*)httpData withTimeout:-1 tag:[tag intValue]];
        CFRelease(httpData);
        CFRelease(httpRequestMessage);
        CFRelease(urlRef);
        
        [sock readDataWithTimeout:-1 tag:[tag intValue]];
    }
    
}

- (void)onSocket:(ELAsyncSocket *)sock didAcceptNewSocket:(ELAsyncSocket *)newSocket
{
    NSNumber *tag = nil;
    ELAsyncSocket *clientSocket = newSocket;
    
    NSMutableDictionary *client = [[NSMutableDictionary alloc]initWithCapacity:5];
    for (NSUInteger idx=0; idx!=MessageCount; idx++) {
        if(inComingMessageArray[idx]==nil){
            inComingMessageArray[idx] = CFHTTPMessageCreateEmpty(kCFAllocatorDefault, true);
            tag = [NSNumber numberWithLong:(long)idx];
            break;
        }
    }
    if(tag == nil)
        return;
    
    [client setObject:clientSocket forKey:@"Socket"];
    [client setObject:tag forKey:@"Tag"];
    [client setObject:@YES forKey:@"FTC"];
    [client setObject:@0 forKey:@"Error"];
    [ftcClients addObject:client];
    EasyLinkLog(@"New socket client, %d", [tag intValue]);
    
    [clientSocket readDataWithTimeout:100 tag:[tag longValue]];
}

- (void)onSocket:(ELAsyncSocket *)sock willDisconnectWithError:(NSError *)err
{
    
    if (err) {
        EasyLinkLog(@"Socket connect failed: %@, %ld", [err localizedDescription], (long)err.code);
    }
    
    for (NSMutableDictionary *object in ftcClients) {
        if([object objectForKey:@"Socket"] == sock){
            [object setObject:[NSNumber numberWithInteger:err.code] forKey:@"Error"];
            break;
        }
    }
}

/**/
- (void)onSocketDidDisconnect:(ELAsyncSocket *)sock
{
    NSError *err;
    NSInteger errCode;
    NSNumber *tag = nil;
    NSDictionary *disconnnectedClient;
    EasyLinkLog(@"TCP disconnect");
    
    /*Stop the timeout counter for closing a client after send the config data.*/
    if(closeFTCClientTimer != nil){
        if([closeFTCClientTimer userInfo] == sock){
            [closeFTCClientTimer invalidate];
            closeFTCClientTimer = nil;
        }
    }

    /* Needs reconnect? */
    for (NSMutableDictionary *object in ftcClients) {
        if([object objectForKey:@"Socket"] ==sock && [[object objectForKey:@"Error"] integerValue] == AsyncSocketConnectTimeoutError ){
            [object setObject:@0 forKey:@"Error"];
            [sock connectToHost:[object objectForKey:@"Host"] onPort:[[object objectForKey:@"Port"] integerValue] withTimeout:5 error:&err];
            if (err) {
                EasyLinkLog(@"Socket re-connect failed: %@, %ld", [err localizedDescription], (long)err.code);
            }
            return;
        }
    }
    
    /*Remove resources*/
    for (NSDictionary *object in ftcClients) {
        if([object objectForKey:@"Socket"] ==sock){
            tag = [object objectForKey:@"Tag"];
            disconnnectedClient = object;
            break;
        }
    }

    if(tag != nil){
        if( inComingMessageArray[[tag intValue]] != nil ){
            CFRelease(inComingMessageArray[[tag intValue]]);
            inComingMessageArray[[tag intValue]] = nil;
        }
        errCode = [[disconnnectedClient objectForKey:@"Error"] integerValue];
        [ftcClients removeObject: disconnnectedClient];

        if([theDelegate respondsToSelector:@selector(onDisconnectFromFTC:withError:)] && _wlanUnConfigured == false){
            if(errCode == 0)
                [theDelegate onDisconnectFromFTC:tag withError: NO];
            else
                [theDelegate onDisconnectFromFTC:tag withError: YES];
        }
    }
}

- (void)onSocket:(ELAsyncSocket *)sock didReadData:(NSData *)data withTag:(long)tag
{
    CFHTTPMessageRef inComingMessage, httpRespondMessage;
    NSUInteger contentLength, currentLength;
    NSMutableDictionary *client;
    inComingMessage = inComingMessageArray[tag];
    NSError *err;
    NSDictionary *configuration;
    NSString *temp;
    
    CFHTTPMessageAppendBytes(inComingMessage, [data bytes], [data length]);
    if (!CFHTTPMessageIsHeaderComplete(inComingMessage)){
        [sock readDataWithTimeout:100 tag:tag];
        return;
    }
    
    CFDataRef bodyRef = CFHTTPMessageCopyBody (inComingMessage );
    NSData *body = (__bridge_transfer NSData*)bodyRef;
    
    CFStringRef contentLengthRef = CFHTTPMessageCopyHeaderFieldValue (inComingMessage, CFSTR("Content-Length") );
    contentLength = [(__bridge_transfer NSString*)contentLengthRef intValue];
    
    currentLength = [body length];
    EasyLinkLog(@"%lu/%lu", (unsigned long)currentLength, (unsigned long)contentLength);
    
    if(currentLength < contentLength){
        [sock readDataToLength:(contentLength-currentLength) withTimeout:100 tag:(long)tag];
        return;
    }
    
    if(CFHTTPMessageIsRequest(inComingMessage) == true ){
        CFURLRef urlRef = CFHTTPMessageCopyRequestURL(inComingMessage);
        CFStringRef urlPathRef= CFURLCopyPath (urlRef);
        CFRelease(urlRef);
        NSString *urlPath= (__bridge_transfer NSString*)urlPathRef;
        EasyLinkLog(@"URL: %@", urlPath);
        
        if([urlPath rangeOfString:@"/auth-setup"].location != NSNotFound || [urlPath rangeOfString:@"/config-read"].location != NSNotFound){
            httpRespondMessage = CFHTTPMessageCreateResponse ( kCFAllocatorDefault, 202, NULL, kCFHTTPVersion1_1 );
            CFDataRef httpData = CFHTTPMessageCopySerializedMessage ( httpRespondMessage );
            CFRelease(httpRespondMessage);
            [sock writeData:(__bridge_transfer NSData*)httpData withTimeout:20 tag:[[client objectForKey:@"Tag"] longValue]];
            [self stopTransmitting];
            if([theDelegate respondsToSelector:@selector(onFoundByFTC: withConfiguration:)]){
                configuration = [NSJSONSerialization JSONObjectWithData:body
                                                                options:NSJSONReadingMutableContainers|NSJSONReadingMutableLeaves
                                                                  error:&err];
                if (err) {
                    temp = [[NSString alloc] initWithData:body encoding:NSASCIIStringEncoding];
                    EasyLinkLog(@"Unpackage JSON data failed:%@, %@", [err localizedDescription], temp);
                    return;
                }
                [theDelegate onFoundByFTC:[NSNumber numberWithLong:tag] withConfiguration:configuration];
            }
            
        }
    }else{
        if(_wlanUnConfigured == true ){
            _softAPStage = eState_configured_by_uap;
            
            if( [theDelegate respondsToSelector:@selector(onEasyLinkSoftApStageChanged:)])
                [theDelegate onEasyLinkSoftApStageChanged:_softAPStage];
            
            return;
            
        }
        
        NSMutableDictionary *foundModule = [NSJSONSerialization JSONObjectWithData:body
                                                                           options:NSJSONReadingMutableContainers|NSJSONReadingMutableLeaves
                                                                             error:&err];
        if ( [[foundModule objectForKey:@"T"] isEqualToString:@"Current Configuration"] == true ){
            //[self stopTransmitting];
            if([theDelegate respondsToSelector:@selector(onFoundByFTC: withConfiguration:)]){
                configuration = [NSJSONSerialization JSONObjectWithData:body
                                                                options:NSJSONReadingMutableContainers|NSJSONReadingMutableLeaves
                                                                  error:&err];
                if (err) {
                    temp = [[NSString alloc] initWithData:body encoding:NSASCIIStringEncoding];
                    EasyLinkLog(@"Unpackage JSON data failed:%@, %@", [err localizedDescription], temp);
                    return;
                }
                [theDelegate onFoundByFTC:[NSNumber numberWithLong:tag] withConfiguration: configuration];
                
            }
        }
    }
    
    if( inComingMessageArray[tag] != nil ){
        CFRelease(inComingMessageArray[tag]);
        inComingMessageArray[tag] = nil;
    }
    inComingMessageArray[tag] = CFHTTPMessageCreateEmpty(kCFAllocatorDefault, true);
    
    /*Recv data that server can send FIN+ACK when client disconnect*/
    [sock readDataWithTimeout:-1 tag:(long)tag];
}

- (void)onSocket:(ELAsyncSocket *)sock didWriteDataWithTag:(long)tag
{
    EasyLinkLog(@"Send complete!");
}

- (void)closeClient:(NSTimer *)timer
{
    [(ELAsyncSocket *)[timer userInfo] disconnect];
    [timer invalidate];
    timer = nil;
}

/*
 Notification method handler when app enter in forground
 @param the fired notification object
 */
- (void)appEnterInforground:(NSNotification*)notification{
    NSError *err = nil;
    ftcServerSocket = [[ELAsyncSocket alloc] initWithDelegate:self];
    [ftcServerSocket acceptOnPort:FTC_PORT error:&err];
    if (err) {
        EasyLinkLog(@"Setup TCP server failed:%@", [err localizedDescription]);
    }
    NetworkStatus netStatus = [wifiReachability currentReachabilityStatus];
    
    if ( netStatus != NotReachable ) {
        if(_softAPSending == true && ![[EASYLINK ssidForConnectedNetwork]  isEqual: @""]){
            [self transmitSettings];
            EasyLinkLog(@"Current SSID:%@", [EASYLINK ssidForConnectedNetwork]);
            if ([[EASYLINK ssidDataForConnectedNetwork] isEqual: [_configDict objectForKey:KEY_SSID]]){
                if(_softAPStage != eState_initialize)
                    _softAPStage = eState_connect_to_target_wlan;
            }
            else if ([[EASYLINK ssidForConnectedNetwork] hasPrefix:@"EasyLink_"])
                _softAPStage = eState_connect_to_uap;
            else
                _softAPStage = eState_connect_to_wrong_wlan;
            
            if( [theDelegate respondsToSelector:@selector(onEasyLinkSoftApStageChanged:)])
                [theDelegate onEasyLinkSoftApStageChanged:_softAPStage];
        }
    }
    
    awsEchoServer = [[ELAsyncUdpSocket alloc] initIPv4];
    [awsEchoServer setDelegate:self];
    [awsEchoServer enablePortReUse:YES error:&err];
    [awsEchoServer bindToPort:AWS_ECHO_SERVER_PORT error:&err];
    if (err) {
        EasyLinkLog(@"Setup AWS echo server failed:%@", [err localizedDescription]);
    }
    
    [awsEchoServer receiveWithTimeout:-1 tag:0];
    
    @synchronized(lockToken) {
        if(_broadcastSending == true)
            [self performSelector:@selector(broadcastStartConfigure:) withObject:self];
        if(_multicastSending == true)
            [self performSelector:@selector(multicastStartConfigure:) withObject:self];
        if(_awsSending == true)
            [self performSelector:@selector(awsStartConfigure:) withObject:self];
    }
    
    
    if(_softAPSending == true || _broadcastSending == true || _multicastSending == true || _awsSending == true){
        _netServiceBrowser.delegate = nil;
        _netServiceBrowser = nil;
        
        for (NSNetService *service in _netServiceArray){
            service.delegate = nil;
        }
        _netServiceArray = nil;
        
        NSNetServiceBrowser *aNetServiceBrowser = [[NSNetServiceBrowser alloc] init];
        if(!aNetServiceBrowser) {
            // The NSNetServiceBrowser couldn't be allocated and initialized.
            EasyLinkLog(@"Network service error!");
        }
        aNetServiceBrowser.delegate = self;
        _netServiceBrowser = aNetServiceBrowser;
        _netServiceArray = [[NSMutableArray alloc]initWithCapacity:10];
        
        [_netServiceBrowser searchForServicesOfType:kEasyLinkConfigServiceType inDomain:kInitialDomain];
    }
    
}

- (void)appEnterInBackground:(NSNotification*)notification{
    if(ftcServerSocket != nil){
        EasyLinkLog(@"Close FTC server");
        [ftcServerSocket setDelegate:nil];
        [ftcServerSocket disconnect];
        ftcServerSocket = nil;
    }
    
    @synchronized(lockToken) {
        if(_broadcastSending == true)
            [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(broadcastStartConfigure: ) object:self];
        if(_multicastSending == true)
            [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(multicastStartConfigure: ) object:self];
        if(_awsSending == true)
            [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(awsStartConfigure: ) object:self];
        
        [broadcastSocket close];
        [multicastSocket close];
        [awsSocket close];
        broadcastSocket = nil;
        multicastSocket = nil;
        awsSocket = nil;
    }

}


/*
 Notification method handler when status of wifi changes
 @param the fired notification object
 */
- (void)wifiStatusChanged:(NSNotification*)notification{
    ELReachability *verifyConnection = [notification object];
    NetworkStatus netStatus = [verifyConnection currentReachabilityStatus];
    
    if ( netStatus != NotReachable ) {
        if(_softAPSending == true && ![[EASYLINK ssidForConnectedNetwork]  isEqual: @""]){
            [self transmitSettings];
            EasyLinkLog(@"Current SSID:%@", [EASYLINK ssidForConnectedNetwork]);
            if ([[EASYLINK ssidDataForConnectedNetwork] isEqual: [_configDict objectForKey:KEY_SSID]]){
                if(_softAPStage != eState_initialize)
                    _softAPStage = eState_connect_to_target_wlan;
            }
            else if ([[EASYLINK ssidForConnectedNetwork] hasPrefix:@"EasyLink_"])
                _softAPStage = eState_connect_to_uap;
            else
                _softAPStage = eState_connect_to_wrong_wlan;
            
            if( [theDelegate respondsToSelector:@selector(onEasyLinkSoftApStageChanged:)])
                [theDelegate onEasyLinkSoftApStageChanged:_softAPStage];
        }
    }
}

#pragma mark - Tools

enum {
    ARC4_ENC_TYPE   = 4,    /* cipher unique type */
    ARC4_STATE_SIZE = 256
};

/* ARC4 encryption and decryption */
typedef struct Arc4 {
    uint8_t x;
    uint8_t y;
    uint8_t state[ARC4_STATE_SIZE];
} Arc4;

void Arc4Process(Arc4*, uint8_t*, const uint8_t*, uint32_t);
void Arc4SetKey(Arc4*, const uint8_t*, uint32_t);


void Arc4SetKey(Arc4* arc4, const uint8_t* key, uint32_t length)
{
    uint32_t i;
    uint32_t keyIndex = 0, stateIndex = 0;
    
    
    arc4->x = 1;
    arc4->y = 0;
    
    for (i = 0; i < ARC4_STATE_SIZE; i++)
        arc4->state[i] = (uint8_t)i;
    
    for (i = 0; i < ARC4_STATE_SIZE; i++) {
        uint32_t a = arc4->state[i];
        stateIndex += key[keyIndex] + a;
        stateIndex &= 0xFF;
        arc4->state[i] = arc4->state[stateIndex];
        arc4->state[stateIndex] = (uint8_t)a;
        
        if (++keyIndex >= length)
            keyIndex = 0;
    }
}


static uint8_t MakeByte(uint32_t* x, uint32_t* y, uint8_t* s)
{
    uint32_t a = s[*x], b;
    *y = (*y+a) & 0xff;
    
    b = s[*y];
    s[*x] = (uint8_t)b;
    s[*y] = (uint8_t)a;
    *x = (*x+1) & 0xff;
    
    return s[(a+b) & 0xff];
}


void Arc4Process(Arc4* arc4, uint8_t* out, const uint8_t* in, uint32_t length)
{
    uint32_t x;
    uint32_t y;
    
    
    x = arc4->x;
    y = arc4->y;
    
    while(length--)
        *out++ = *in++ ^ MakeByte(&x, &y, arc4->state);
    
    arc4->x = (uint8_t)x;
    arc4->y = (uint8_t)y;
}

+ (void)encrypt: (NSMutableData *)inputData useRC4Key: (NSData *)key
{
    if( key == nil || inputData == nil )
        return;
    
    if( [key length]== 0 || [inputData length] == 0 )
        return;
    
    Arc4 arc4_cont4ext;
    uint32_t data_len = (uint32_t)[inputData length];

    uint8_t *outCData = malloc(data_len);
    uint8_t *inCData = malloc(data_len);
    NSRange range = {0, data_len};
    
    memcpy(inCData, [inputData bytes], data_len);
    
    Arc4SetKey(&arc4_cont4ext, [key bytes], (uint32_t)[key length]);
    Arc4Process(&arc4_cont4ext, outCData, inCData, data_len);
    
    [inputData replaceBytesInRange:range withBytes:outCData];
    free(outCData);
    free(inCData);
}


+ (NSString *)version
{
    return EASYLINK_VERSION;
}


/*!!!!!!!!!!!!
 retriving the SSID of the connected network
 @return value: the SSID of currently connected wifi
 '!!!!!!!!!!*/
+ (NSString*)ssidForConnectedNetwork{
    NSArray *interfaces = (__bridge_transfer NSArray*)CNCopySupportedInterfaces();
    NSDictionary *info = nil;
    for (NSString *ifname in interfaces) {
        info = (__bridge_transfer NSDictionary*)CNCopyCurrentNetworkInfo((__bridge CFStringRef)ifname);
        if (info && [info count]) {
            break;
        }
        info = nil;
    }
    
    NSString *ssid = nil;
    
    if ( info ){
        ssid = [info objectForKey:(__bridge_transfer NSString*)kCNNetworkInfoKeySSID];
    }
    info = nil;
    return ssid? ssid:@"";
}

+ (NSData *)ssidDataForConnectedNetwork{
    NSArray *interfaces = (__bridge_transfer NSArray*)CNCopySupportedInterfaces();
    NSDictionary *info = nil;
    for (NSString *ifname in interfaces) {
        info = (__bridge_transfer NSDictionary*)CNCopyCurrentNetworkInfo((__bridge CFStringRef)ifname);
        if (info && [info count]) {
            break;
        }
        info = nil;
    }
    
    NSData *ssidData = nil;
    
    if ( info ){
        ssidData = [info objectForKey:(__bridge_transfer NSString*)kCNNetworkInfoKeySSIDData];
    }
    info = nil;
    return ssidData? ssidData:[NSData data];
}


+ (NSDictionary *)infoForConnectedNetwork
{
    NSArray *interfaces = (__bridge_transfer NSArray*)CNCopySupportedInterfaces();
    NSDictionary *info = nil;
    for (NSString *ifname in interfaces) {
        info = (__bridge_transfer NSDictionary*)CNCopyCurrentNetworkInfo((__bridge CFStringRef)ifname);
        if (info && [info count]) {
            break;
        }
        info = nil;
    }
    return info;
}

/*!!!!!!!!!!!!!
 retrieving the IP Address from the connected WiFi
 @return value: the wifi address of currently connected wifi
 */
+ (NSString *)getIPAddress {
    NSString *address = @"";
    
    struct ifaddrs *interfaces = NULL;
    struct ifaddrs *temp_addr = NULL;
    char straddr4[INET_ADDRSTRLEN];
    char straddr6[INET6_ADDRSTRLEN];
    int success = 0;
    // retrieve the current interfaces - returns 0 on success
    success = getifaddrs(&interfaces);
    if (success == 0) {
        // Loop through linked list of interfaces
        temp_addr = interfaces;
        while(temp_addr != NULL) {
            if(temp_addr->ifa_addr->sa_family == AF_INET) {
                // Check if interface is en0 which is the wifi connection on the iPhone
                if([[NSString stringWithUTF8String:temp_addr->ifa_name] isEqualToString:@"en0"]) {
                    // Get NSString from C String for IP
                    struct sockaddr_in *addr4 = (struct sockaddr_in *)(temp_addr->ifa_addr);
                    inet_ntop(AF_INET, &(addr4->sin_addr), straddr4, sizeof(straddr4));
                    address = [NSString stringWithUTF8String: straddr4];
                }
            }
            else if(temp_addr->ifa_addr->sa_family == AF_INET6) {
                // Check if interface is en0 which is the wifi connection on the iPhone
                if([[NSString stringWithUTF8String:temp_addr->ifa_name] isEqualToString:@"en0"]) {
                    // Get NSString from C String for IP
                    struct sockaddr_in6 *addr6 = (struct sockaddr_in6 *)(temp_addr->ifa_addr);
                    inet_ntop(AF_INET6, &(addr6->sin6_addr), straddr6, sizeof(straddr6));
                    address = [NSString stringWithUTF8String: straddr6];
                }
            }
            temp_addr = temp_addr->ifa_next;
        }
    }
    // Free/release memory
    freeifaddrs(interfaces);
    return address;
}

+ (NSString *)getNetMask{
    NSString *address = @"";
    struct ifaddrs *interfaces = NULL;
    struct ifaddrs *temp_addr = NULL;
    char straddr4[INET_ADDRSTRLEN];
    char straddr6[INET6_ADDRSTRLEN];
    int success = 0;
    // retrieve the current interfaces - returns 0 on success
    success = getifaddrs(&interfaces);
    if (success == 0) {
        // Loop through linked list of interfaces
        temp_addr = interfaces;
        while(temp_addr != NULL) {
            if(temp_addr->ifa_addr->sa_family == AF_INET) {
                // Check if interface is en0 which is the wifi connection on the iPhone
                if([[NSString stringWithUTF8String:temp_addr->ifa_name] isEqualToString:@"en0"]) {
                    // Get NSString from C String for IP
                    struct sockaddr_in *addr4 = (struct sockaddr_in *)(temp_addr->ifa_netmask);
                    if(addr4 != NULL){
                        inet_ntop(AF_INET, &(addr4->sin_addr), straddr4, sizeof(straddr4));
                        address = [NSString stringWithUTF8String: straddr4];
                    }
                }
            }
            else if(temp_addr->ifa_addr->sa_family == AF_INET6) {
                // Check if interface is en0 which is the wifi connection on the iPhone
                if([[NSString stringWithUTF8String:temp_addr->ifa_name] isEqualToString:@"en0"]) {
                    // Get NSString from C String for IP
                    struct sockaddr_in6 *addr6 = (struct sockaddr_in6 *)(temp_addr->ifa_netmask);
                    if(addr6 != NULL){
                        inet_ntop(AF_INET6, &(addr6->sin6_addr), straddr6, sizeof(straddr6));
                        address = [NSString stringWithUTF8String: straddr6];
                    }
                }
            }
            temp_addr = temp_addr->ifa_next;
        }
    }
    // Free/release memory
    freeifaddrs(interfaces);
    return address;
    
}


+ (NSString *)getBroadcastAddress{
    NSString *address = @"";
    struct ifaddrs *interfaces = NULL;
    struct ifaddrs *temp_addr = NULL;
    char straddr4[INET_ADDRSTRLEN];
    char straddr6[INET6_ADDRSTRLEN];
    int success = 0;
    // retrieve the current interfaces - returns 0 on success
    success = getifaddrs(&interfaces);
    if (success == 0) {
        // Loop through linked list of interfaces
        temp_addr = interfaces;
        while(temp_addr != NULL) {
            if(temp_addr->ifa_addr->sa_family == AF_INET) {
                // Check if interface is en0 which is the wifi connection on the iPhone
                if([[NSString stringWithUTF8String:temp_addr->ifa_name] isEqualToString:@"en0"]) {
                    // Get NSString from C String for IP
                    struct sockaddr_in *addr4 = (struct sockaddr_in *)(temp_addr->ifa_dstaddr);
                    if(addr4 != NULL){
                        inet_ntop(AF_INET, &(addr4->sin_addr), straddr4, sizeof(straddr4));
                        address = [NSString stringWithUTF8String: straddr4];
                    }
                }
            }
            else if(temp_addr->ifa_addr->sa_family == AF_INET6) {
                // Check if interface is en0 which is the wifi connection on the iPhone
                if([[NSString stringWithUTF8String:temp_addr->ifa_name] isEqualToString:@"en0"]) {
                    // Get NSString from C String for IP
                    struct sockaddr_in6 *addr6 = (struct sockaddr_in6 *)(temp_addr->ifa_dstaddr);
                    if(addr6 != NULL){
                        inet_ntop(AF_INET6, &(addr6->sin6_addr), straddr6, sizeof(straddr6));
                        address = [NSString stringWithUTF8String: straddr6];
                    }
                }
            }
            temp_addr = temp_addr->ifa_next;
        }
    }
    // Free/release memory
    freeifaddrs(interfaces);
    return address;
}


#define CTL_NET         4               /* network, see socket.h */

#if defined(BSD) || defined(__APPLE__)

#define ROUNDUP(a) \
((a) > 0 ? (1 + (((a) - 1) | (sizeof(long) - 1))) : sizeof(long))

+ (NSString *)getGatewayAddress;
{
    /* net.route.0.inet.flags.gateway */
    int mib[] = {CTL_NET, PF_ROUTE, 0, AF_INET,
        NET_RT_FLAGS, RTF_GATEWAY};
    size_t l;
    char * buf, * p;
    struct rt_msghdr * rt;
    struct sockaddr * sa;
    struct sockaddr * sa_tab[RTAX_MAX];
    int i;
    //char *address = NULL;
    char address[INET_ADDRSTRLEN];
    
    NSString *routerAddrses = @"";
    
    if(sysctl(mib, sizeof(mib)/sizeof(int), 0, &l, 0, 0) < 0) {
        return routerAddrses;
    }
    if(l<=0)
        return routerAddrses;
    
    buf = malloc(l);
    if(sysctl(mib, sizeof(mib)/sizeof(int), buf, &l, 0, 0) < 0) {
        free(buf);
        return nil;
    }
    
    for(p=buf; p<buf+l; p+=rt->rtm_msglen) {
        rt = (struct rt_msghdr *)p;
        sa = (struct sockaddr *)(rt + 1);
        for(i=0; i<RTAX_MAX; i++) {
            if(rt->rtm_addrs & (1 << i)) {
                sa_tab[i] = sa;
                sa = (struct sockaddr *)((char *)sa + ROUNDUP(sa->sa_len));
            } else {
                sa_tab[i] = NULL;
            }
        }
        
        if( ((rt->rtm_addrs & (RTA_DST|RTA_GATEWAY)) == (RTA_DST|RTA_GATEWAY))
           && sa_tab[RTAX_DST]->sa_family == AF_INET
           && sa_tab[RTAX_GATEWAY]->sa_family == AF_INET) {
            
            
            if(((struct sockaddr_in *)sa_tab[RTAX_DST])->sin_addr.s_addr == 0) {
                struct sockaddr_in *addr4 = (struct sockaddr_in *)sa_tab[RTAX_GATEWAY];
                inet_ntop(AF_INET, &(addr4->sin_addr), address, sizeof(address));
                //address = inet_ntoa(((struct sockaddr_in *)(sa_tab[RTAX_GATEWAY]))->sin_addr);
                break;
            }
        }
    }
    free(buf);
    
    routerAddrses = [NSString stringWithUTF8String: address];
    return routerAddrses;
}
#endif

@end
