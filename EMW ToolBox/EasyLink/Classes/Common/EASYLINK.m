//
//  EASYLINK.m
//  EasyLink
//
//  Created by William Xu on 13-7-24.
//  Copyright (c) 2013年 MXCHIP. All rights reserved.
//

#import "EASYLINK.h"
#import "sys/sysctl.h"
#include <ifaddrs.h>
#include <arpa/inet.h>
#import "Reachability.h"

#if TARGET_IPHONE_SIMULATOR
#include <net/route.h>
#else
#include "route.h"
#endif

#define DefaultEasyLinkPlusDelayPerByte    0.005
#define DefaultEasyLinkPlusDelayPerBlock   0.08
#define DefaultEasyLinkV2DelayPerBlock     0.02

<<<<<<< HEAD
#define EasyLinkPlusDelayPerByte    0.005
#define EasyLinkPlusDelayPerBlock   0.08
#define EasyLinkV2DelayPerBlock     0.04


CFHTTPMessageRef inComingMessageArray[MessageCount];
=======
#define kEasyLinkConfigServiceType @"_easylink_config._tcp"
#define kInitialDomain  @"local"
>>>>>>> EasyLink-Soft-AP

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
        [self addObject:[NSDictionary dictionaryWithObjectsAndKeys: [NSMutableData dataWithLength:(0x500+ *blockIndex)], @"sendData", [NSNumber numberWithFloat:delay], @"Delay", nil]];
    }
}

@end

@interface EASYLINK ()

- (void)broadcastStartConfigure:(id)sender;
- (void)multicastStartConfigure:(id)sender;
- (void)closeClient:(NSTimer *)timer;
- (BOOL)isFTCServerStarted;
- (void)closeFTCServer;


- (void)prepareEasyLinkV2:(NSData *)bSSID password:(NSString *)bpasswd info: (NSData *)userInfo;
- (void)prepareEasyLinkPlus:(NSData *)bSSID password:(NSString *)bpasswd info: (NSData *)userInfo;


@end

@implementation EASYLINK
@synthesize softAPStage = _softAPStage;
@synthesize softAPSending = _softAPSending;
@synthesize mode = _mode;
@synthesize easyLinkPlusDelayPerByte;
@synthesize easyLinkPlusDelayPerBlock;
@synthesize easyLinkV2DelayPerBlock;


-(id)init{
    return [self initWithDelegate:nil];
}

-(id)initWithDelegate:(id)delegate
{
    NSLog(@"Init EasyLink");
    self = [super init];
    NSError *err;
    if (self) {
        // Initialization code
        _mode = EASYLINK_V2_PLUS;
        
        broadcastArray = [NSMutableArray array];
        multicastArray = [NSMutableArray array];
        _softAPStage = eState_initialize;
        
        ftcClients = [NSMutableArray arrayWithCapacity:10];
        
        ftcServerSocket = [[AsyncSocket alloc] initWithDelegate:self];
        [ftcServerSocket acceptOnPort:FTC_PORT error:&err];
        if (err) {
            NSLog(@"Setup TCP server failed:%@", [err localizedDescription]);
        }
        //theDelegate = delegate;
        
        
        _multicastSending = false;
        _broadcastSending = false;
        _softAPSending = false;
        _wlanUnConfigured = false;
        easyLinkPlusDelayPerByte = DefaultEasyLinkPlusDelayPerByte;
        easyLinkPlusDelayPerBlock = DefaultEasyLinkPlusDelayPerBlock;
        easyLinkV2DelayPerBlock = DefaultEasyLinkV2DelayPerBlock;
        
        for(NSUInteger idx = 0; idx<MessageCount; idx++){
            inComingMessageArray[idx] = nil;
        }
        
        _broadcastcount = 0;
        _multicastCount = 0;
        
        wifiReachability = [Reachability reachabilityForLocalWiFi];  //监测Wi-Fi连接状态
        [wifiReachability startNotifier];
        
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(appEnterInforground:) name:UIApplicationDidBecomeActiveNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(appEnterInBackground:) name:UIApplicationDidEnterBackgroundNotification object:nil];
        
        
        // wifi notification when changed.
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(wifiStatusChanged:) name:kReachabilityChangedNotification object:nil];
        
        theDelegate = delegate;
        
    }
    return self;
}

-(void) unInit{
    theDelegate = nil;
    [self closeFTCServer];
}

-(void)dealloc{
    NSLog(@"unInit EasyLink");
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
        NSLog(@"Close FTC clients");
        AsyncSocket *clientSocket = [object objectForKey:@"Socket"];
        [clientSocket setDelegate:nil];
        [clientSocket disconnect];
        clientSocket = nil;
    }
    if(ftcServerSocket != nil){
        NSLog(@"Close FTC server");
        [ftcServerSocket setDelegate:nil];
        [ftcServerSocket disconnect];
        ftcServerSocket = nil;
    }
    
    ftcClients = nil;
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


- (void)prepareEasyLink_withFTC:(NSDictionary *)wlanConfigDict info: (NSData *)userInfo mode: (EasyLinkMode)easyLinkMode
{
    NSString *ipAddress;

    _mode = easyLinkMode;
    _configDict = wlanConfigDict;
    
    NSData *ssid = [_configDict objectForKey:KEY_SSID];
    NSString *passwd = [_configDict objectForKey:KEY_PASSWORD];
    
    ipAddress = [_configDict objectForKey:KEY_IP];
    in_addr_t ip = ipAddress==nil? -1:htonl(inet_addr([ipAddress cStringUsingEncoding:NSASCIIStringEncoding]));
    
    ipAddress = [_configDict objectForKey:KEY_NETMASK];
    in_addr_t netmask = ipAddress==nil? -1:htonl(inet_addr([ipAddress cStringUsingEncoding:NSASCIIStringEncoding]));
    
    ipAddress = [_configDict objectForKey:KEY_GATEWAY];
    in_addr_t gateway = ipAddress==nil? -1:htonl(inet_addr([ipAddress cStringUsingEncoding:NSASCIIStringEncoding]));
    
    ipAddress = [_configDict objectForKey:KEY_DNS1];
    in_addr_t dns1 = ipAddress==nil? -1:htonl(inet_addr([ipAddress cStringUsingEncoding:NSASCIIStringEncoding]));
    
    ipAddress = [_configDict objectForKey:KEY_DNS2];
    in_addr_t dns2 = ipAddress==nil? -1:htonl(inet_addr([ipAddress cStringUsingEncoding:NSASCIIStringEncoding]));
    
    bool dhcp = [[_configDict objectForKey:KEY_DHCP]  boolValue];

    if(dhcp==YES)
        ip = -1;
    
    if (userInfo == nil) userInfo = [NSData dataWithBytes:nil length:0];
    
    uint32_t address = htonl(inet_addr([[EASYLINK getIPAddress] cStringUsingEncoding:NSUTF8StringEncoding])) ;
    
    NSMutableData * userInfoWithIP = [NSMutableData dataWithCapacity:200];
    char seperate = '#';
    
    [userInfoWithIP appendData:userInfo];
    [userInfoWithIP appendData:[NSData dataWithBytes:&seperate length:1]];
    [userInfoWithIP appendBytes:(const void *)&address length:sizeof(uint32_t)];
    if(dhcp == NO){
        [userInfoWithIP appendBytes:&ip length:sizeof(uint32_t)];
        [userInfoWithIP appendBytes:&netmask length:sizeof(uint32_t)];
        [userInfoWithIP appendBytes:&gateway length:sizeof(uint32_t)];
        [userInfoWithIP appendBytes:&dns1 length:sizeof(uint32_t)];
        [userInfoWithIP appendBytes:&dns2 length:sizeof(uint32_t)];
    }
    
    if(easyLinkMode != EASYLINK_SOFT_AP){
        [self prepareEasyLinkV2:ssid password:passwd info: userInfoWithIP];
        [self prepareEasyLinkPlus:ssid password:passwd info: userInfoWithIP];
    }
    
    _softAPStage = eState_initialize;
}


- (void)prepareEasyLinkV2:(NSData *)bSSID password:(NSString *)bpasswd info: (NSData *)userInfo
{
    if (bSSID == nil) bSSID = [NSData data];
    if (bpasswd == nil) bpasswd = @"";
    if (userInfo == nil) userInfo = [NSData dataWithBytes:nil length:0];
    NSMutableData *mergeSsidPass = [NSMutableData dataWithCapacity:100];
    [mergeSsidPass appendData:bSSID];
    [mergeSsidPass appendData: [bpasswd dataUsingEncoding:NSUTF8StringEncoding]];
    
    const char *bpasswd_UTF8 = [bpasswd UTF8String];
    const uint8_t *userInfo_UTF8 = [userInfo bytes];
    const char *cMergeSsidPass = [mergeSsidPass bytes];
    
    NSUInteger bSSID_length = [bSSID length];
    NSUInteger bpasswd_length = strlen(bpasswd_UTF8);
    NSUInteger userInfo_length = [userInfo length];
    NSUInteger mergeSsidPass_Length = [mergeSsidPass length];
    
    NSUInteger headerLength = 20;
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
    [dictionary setValue:[NSString stringWithFormat:@"239.126.%lu.%lu", (unsigned long)bSSID_length, (unsigned long)bpasswd_length] forKey:@"host"];
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
        Byte a = userInfo_UTF8[idx];
        Byte b = 0;
        if (idx + 1 != userInfo_length)
            b = userInfo_UTF8[idx+1];
        
        dictionary = [NSMutableDictionary dictionary];
        [dictionary setValue:[NSMutableData dataWithLength:headerLength] forKey:@"sendData"];
        [dictionary setValue:[NSString stringWithFormat:@"239.126.%d.%d", a, b] forKey:@"host"];
        [dictionary setValue:[NSNumber numberWithFloat:easyLinkV2DelayPerBlock] forKey:@"Delay"];
        [multicastArray addObject:dictionary];
    }
}

- (void)prepareEasyLinkPlus:(NSData *)bSSID password:(NSString *)bpasswd info: (NSData *)userInfo
{
    if (bSSID == nil) bSSID = [NSData data];
    if (bpasswd == nil) bpasswd = @"";
    if (userInfo == nil) userInfo = [NSData dataWithBytes:nil length:0];
    
    const unsigned char *cSSID = [bSSID bytes];
    const char *bpasswd_UTF8 = [bpasswd UTF8String];
    const uint8_t *userInfo_UTF8 = [userInfo bytes];
    
    NSUInteger bssid_length = [bSSID length];
    NSUInteger bpasswd_length = strlen(bpasswd_UTF8);
    NSUInteger userInfo_length = [userInfo length];

    uint16_t chechSum = 0;

    uint32_t seqNo = 0;
    uint32_t seqHook = 0;
    
    NSUInteger totalLen = 0x5 + bssid_length + bpasswd_length + userInfo_length;
    
    NSUInteger addedConst[4] = {0x100, 0x200, 0x300, 0x400};
    NSUInteger addedConstIdx = 0;
    
    [broadcastArray removeAllObjects];
    
    [broadcastArray insertEasyLinkPlusData:0x5AA delay:easyLinkPlusDelayPerByte];
    [broadcastArray insertEasyLinkPlusData:0x5AB delay:easyLinkPlusDelayPerByte];
    [broadcastArray insertEasyLinkPlusData:0x5AC delay:easyLinkPlusDelayPerByte];
    
    /*Total len*/
    [broadcastArray insertEasyLinkPlusData:( totalLen + addedConst[(addedConstIdx++)%4] ) delay:easyLinkPlusDelayPerByte];
    [broadcastArray insertEasyLinkPlusBlockIndex: &seqHook forSeqNo:seqNo++ delay:easyLinkPlusDelayPerByte blockDelay:easyLinkPlusDelayPerBlock];
    chechSum += totalLen;

    /*SSID len*/
    [broadcastArray insertEasyLinkPlusData:( bssid_length + addedConst[(addedConstIdx++)%4] ) delay:easyLinkPlusDelayPerByte];
    [broadcastArray insertEasyLinkPlusBlockIndex: &seqHook forSeqNo:seqNo++ delay:easyLinkPlusDelayPerByte blockDelay:easyLinkPlusDelayPerBlock];
    chechSum += bssid_length;
    
    /*Key len*/
    [broadcastArray insertEasyLinkPlusData:( bpasswd_length + addedConst[(addedConstIdx++)%4] ) delay:easyLinkPlusDelayPerByte];
    [broadcastArray insertEasyLinkPlusBlockIndex: &seqHook forSeqNo:seqNo++ delay:easyLinkPlusDelayPerByte blockDelay:easyLinkPlusDelayPerBlock];
    chechSum += bpasswd_length;
    
    /*SSID*/
    for (NSUInteger idx = 0; idx != bssid_length; ++idx) {
        [broadcastArray insertEasyLinkPlusData:( cSSID[idx] + addedConst[(addedConstIdx++)%4] ) delay:easyLinkPlusDelayPerByte];
        [broadcastArray insertEasyLinkPlusBlockIndex: &seqHook forSeqNo:seqNo++ delay:easyLinkPlusDelayPerByte blockDelay:easyLinkPlusDelayPerBlock];
        chechSum += cSSID[idx];
    }

    /*Key*/
    for (NSUInteger idx = 0; idx != bpasswd_length; ++idx) {
        [broadcastArray insertEasyLinkPlusData:( bpasswd_UTF8[idx] + addedConst[(addedConstIdx++)%4] ) delay:easyLinkPlusDelayPerByte];
        [broadcastArray insertEasyLinkPlusBlockIndex: &seqHook forSeqNo:seqNo++ delay:easyLinkPlusDelayPerByte blockDelay:easyLinkPlusDelayPerBlock];
        chechSum += bpasswd_UTF8[idx];
    }
    

    /*User info*/
    for (NSUInteger idx = 0; idx != userInfo_length; ++idx) {
        [broadcastArray insertEasyLinkPlusData:( userInfo_UTF8[idx] + addedConst[(addedConstIdx++)%4] ) delay:easyLinkPlusDelayPerByte];
        [broadcastArray insertEasyLinkPlusBlockIndex: &seqHook forSeqNo:seqNo++ delay:easyLinkPlusDelayPerByte blockDelay:easyLinkPlusDelayPerBlock];
        chechSum += userInfo_UTF8[idx];
    }
    
    /*Checksum high*/
    [broadcastArray insertEasyLinkPlusData:( ((chechSum&0xFF00)>>8) + addedConst[(addedConstIdx++)%4] ) delay:easyLinkPlusDelayPerByte];
    [broadcastArray insertEasyLinkPlusBlockIndex: &seqHook forSeqNo:seqNo++ delay:easyLinkPlusDelayPerByte blockDelay:easyLinkPlusDelayPerBlock];
    
    /*Checksum low*/
    [broadcastArray insertEasyLinkPlusData:( (chechSum&0x00FF) + addedConst[(addedConstIdx++)%4] ) delay:easyLinkPlusDelayPerByte];
    [broadcastArray insertEasyLinkPlusBlockIndex: &seqHook forSeqNo:seqNo++ delay:easyLinkPlusDelayPerByte blockDelay:easyLinkPlusDelayPerBlock];
}


- (void)transmitSettings
{
<<<<<<< HEAD
    multicastCount = 0;
    broadcastcount = 0;
    
    CFSocketRef tempSocket;
    tempSocket = CFSocketCreate(kCFAllocatorDefault,
                                PF_INET,
                                SOCK_DGRAM,
                                IPPROTO_UDP,
                                kCFSocketNoCallBack,
                                NULL,
                                NULL);
    uint8_t loop = 0x1;
    setsockopt(CFSocketGetNative(tempSocket), SOL_SOCKET, IP_MULTICAST_LOOP, &loop, sizeof(uint8_t));
    NSString *ipAddressStr = [EASYLINK getIPAddress];
    NSString *multicastAddressStr;
    struct in_addr interface;
    interface.s_addr= inet_addr([ipAddressStr cStringUsingEncoding:NSASCIIStringEncoding]);
    
    struct ip_mreq mreq;
    mreq.imr_interface = interface;
    NSDictionary *object;
    for(object in self.multicastArray){
        multicastAddressStr = [object objectForKey:@"host"];
        mreq.imr_multiaddr.s_addr =  inet_addr([multicastAddressStr cStringUsingEncoding:NSASCIIStringEncoding]);
        setsockopt(CFSocketGetNative(tempSocket),IPPROTO_IP,IP_ADD_MEMBERSHIP,&mreq,sizeof(mreq));
    }
    for(object in self.multicastArray){
        multicastAddressStr = [object objectForKey:@"host"];
        mreq.imr_multiaddr.s_addr =  inet_addr([multicastAddressStr cStringUsingEncoding:NSASCIIStringEncoding]);
        setsockopt(CFSocketGetNative(tempSocket),IPPROTO_IP,IP_ADD_MEMBERSHIP,&mreq,sizeof(mreq));
    }
    
#ifdef INTERVAL_EASYLINK
    easyLinkSuspend = false;
    easyLinkTemporarySuspendTimer = [NSTimer scheduledTimerWithTimeInterval:10 target:self selector:@selector(easyLinkTemperarySuspend:) userInfo:nil repeats:YES];
#endif

    if(version == EASYLINK_PLUS){
        if(broadcastSending == false){
            broadcastSending = true;
            [self performSelector:@selector(broadcastStartConfigure:) withObject:self];
        }
=======
    NSError *err;
    [self stopTransmitting];
    
    if(_mode == EASYLINK_V2_PLUS){
        _broadcastSending = true;
        _multicastSending = true;
        
        broadcastSocket = [[AsyncUdpSocket alloc] initWithDelegate:nil];
        [broadcastSocket enableBroadcast:YES error:&err];
        
        multicastSocket = [[AsyncUdpSocket alloc] initWithDelegate:nil];
        
        [self performSelector:@selector(broadcastStartConfigure:) withObject:self];
        [self performSelector:@selector(multicastStartConfigure:) withObject:self];

    }else if(_mode == EASYLINK_PLUS){
        _broadcastSending = true;
        broadcastSocket = [[AsyncUdpSocket alloc] initWithDelegate:nil];
        [broadcastSocket enableBroadcast:YES error:&err];
        [self performSelector:@selector(broadcastStartConfigure:) withObject:self];
        
    }else if(_mode == EASYLINK_V2){
        _multicastSending = true;
        multicastSocket = [[AsyncUdpSocket alloc] initWithDelegate:nil];
        [self performSelector:@selector(multicastStartConfigure:) withObject:self];
        
    }else if(_mode == EASYLINK_SOFT_AP) {
        _softAPSending = true;
        
        _netServiceBrowser.delegate = nil;
        _netServiceBrowser = nil;
>>>>>>> EasyLink-Soft-AP
        
        for (NSNetService *service in _netServiceArray){
            service.delegate = nil;
        }
        _netServiceArray = nil;
        
        NSNetServiceBrowser *aNetServiceBrowser = [[NSNetServiceBrowser alloc] init];
        if(!aNetServiceBrowser) {
            // The NSNetServiceBrowser couldn't be allocated and initialized.
            NSLog(@"Network service error!");
        }
        aNetServiceBrowser.delegate = self;
        _netServiceBrowser = aNetServiceBrowser;
        _netServiceArray = [[NSMutableArray alloc]initWithCapacity:10];
        
        [_netServiceBrowser searchForServicesOfType:kEasyLinkConfigServiceType inDomain:kInitialDomain];
    }
}

- (void)stopTransmitting
{
<<<<<<< HEAD
    broadcastSending = false;
    multicastSending = false;
    
#ifdef INTERVAL_EASYLINK
    [easyLinkTemporarySuspendTimer invalidate];
    easyLinkTemporarySuspendTimer = nil;
#endif
}

#ifdef INTERVAL_EASYLINK
- (void)easyLinkTemperarySuspend:(id)userInfo
{
    if(easyLinkSuspend == false){
        NSLog(@"Suspend...");
        easyLinkSuspend = true;
    }
    else{
        NSLog(@"Unsuspend...");
        easyLinkSuspend = false;
    }
=======
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(broadcastStartConfigure: ) object:self];
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(multicastStartConfigure: ) object:self];
    _broadcastSending = false;
    _multicastSending = false;
    _softAPSending = false;
>>>>>>> EasyLink-Soft-AP
}
#endif


- (void)broadcastStartConfigure:(id)sender{
<<<<<<< HEAD
#ifdef INTERVAL_EASYLINK
    if(easyLinkSuspend == false)
        [self.broadcastSocket sendData:[[self.broadcastArray objectAtIndex:broadcastcount] objectForKey:@"sendData"] toHost:[EASYLINK getBroadcastAddress] port:65523 withTimeout:10 tag:0];
#else
    [self.broadcastSocket sendData:[[self.broadcastArray objectAtIndex:broadcastcount] objectForKey:@"sendData"] toHost:[EASYLINK getBroadcastAddress] port:65523 withTimeout:10 tag:0];
#endif
    ++broadcastcount;
    if (broadcastcount == [self.broadcastArray count]) broadcastcount = 0;
    if(broadcastSending == true)
        [self performSelector:@selector(broadcastStartConfigure:) withObject:self afterDelay:[(NSNumber *)([[self.broadcastArray objectAtIndex:broadcastcount] objectForKey:@"Delay"]) floatValue]];
}

- (void)multicastStartConfigure:(id)sender{
#ifdef INTERVAL_EASYLINK
    if(easyLinkSuspend == false)
        [self.multicastSocket sendData:[[self.multicastArray objectAtIndex:multicastCount] objectForKey:@"sendData"] toHost:[[self.multicastArray objectAtIndex:multicastCount] objectForKey:@"host"] port:65523 withTimeout:10 tag:0];
#else
    [self.multicastSocket sendData:[[self.multicastArray objectAtIndex:multicastCount] objectForKey:@"sendData"] toHost:[[self.multicastArray objectAtIndex:multicastCount] objectForKey:@"host"] port:65523 withTimeout:10 tag:0];
#endif
    ++multicastCount;
    if (multicastCount == [self.multicastArray count]) multicastCount = 0;
    if(multicastSending == true)
        [self performSelector:@selector(multicastStartConfigure:) withObject:self afterDelay:[(NSNumber *)([[self.multicastArray objectAtIndex:multicastCount] objectForKey:@"Delay"]) floatValue]];
=======
    [broadcastSocket sendData:[[broadcastArray objectAtIndex:_broadcastcount] objectForKey:@"sendData"] toHost:[EASYLINK getBroadcastAddress] port:65523 withTimeout:10 tag:0];
    ++_broadcastcount;
    if (_broadcastcount == [broadcastArray count]) _broadcastcount = 0;
    if(_broadcastSending == true)
        [self performSelector:@selector(broadcastStartConfigure:) withObject:self afterDelay:[(NSNumber *)([[broadcastArray objectAtIndex:_broadcastcount] objectForKey:@"Delay"]) floatValue]];
}

- (void)multicastStartConfigure:(id)sender{
    [multicastSocket sendData:[[multicastArray objectAtIndex:_multicastCount] objectForKey:@"sendData"] toHost:[[multicastArray objectAtIndex:_multicastCount] objectForKey:@"host"] port:65523 withTimeout:10 tag:0];
    ++_multicastCount;
    if (_multicastCount == [multicastArray count]) _multicastCount = 0;
    if(_multicastSending == true)
        [self performSelector:@selector(multicastStartConfigure:) withObject:self afterDelay:[(NSNumber *)([[multicastArray objectAtIndex:_multicastCount] objectForKey:@"Delay"]) floatValue]];
>>>>>>> EasyLink-Soft-AP
}

#pragma mark - Service browser

- (void)netServiceBrowser:(NSNetServiceBrowser*)netServiceBrowser didFindService:(NSNetService*)service moreComing:(BOOL)moreComing {
    // If a service came online, add it to the list and update the table view if no more events are queued.
    service.delegate = self;
    
    NSLog(@"service found %@",[service name]);
    [service resolveWithTimeout:0.0];
    [_netServiceArray addObject:service];
}

- (void)netServiceDidResolveAddress:(NSNetService *)service
{
    NSDictionary *txtData;
    NSError *err;
    NSString *_address;
    NSNumber *tag = nil;
    
    [service stop];
    service.delegate = nil;
    
    _address = [[[service addresses] objectAtIndex: 0] host];
    NSLog(@"Found address: %@", _address);
    
    for (NSDictionary *client in ftcClients){
        if( [[client objectForKey:@"Host"]isEqualToString:_address]){
            [[client objectForKey:@"Socket"] disconnect];
        }
    }
    
    NSMutableDictionary *client = [[NSMutableDictionary alloc] initWithCapacity:5];
    
    for (NSUInteger idx=0; idx!=MessageCount; idx++) {
        if(inComingMessageArray[idx]==nil){
            inComingMessageArray[idx] = CFHTTPMessageCreateEmpty(kCFAllocatorDefault, false);
            tag = [NSNumber numberWithLong:(long)idx];
            break;
        }
    }
    if(tag == nil)
        return;
    
    AsyncSocket *sock = [[AsyncSocket alloc] initWithDelegate:self];
    [client setObject:sock forKey:@"Socket"];
    [client setObject:tag forKey:@"Tag"];
    [client setObject:_address forKey:@"Host"];
    
    [ftcClients addObject:client];
    NSLog(@"New socket client, %d", [tag intValue]);

    
    
    
    txtData = [NSNetService dictionaryFromTXTRecordData: [service TXTRecordData]];
    if([[NSString alloc]initWithData:[txtData objectForKey:@"wlan unconfigured"] encoding:NSASCIIStringEncoding].boolValue == YES){
        _wlanUnConfigured = true;
    }
    else{
        _wlanUnConfigured = false;
    }
    
    
    NSLog(@"Connect to: %@:%d", _address, service.port);
    [sock connectToHost:_address onPort:service.port withTimeout:5 error:&err];
    [_netServiceArray removeObject:service];
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
    
    NSLog(@"Close FTC client %d", [client intValue]);
    AsyncSocket *clientSocket = [clientDict objectForKey:@"Socket"];
    //[clientSocket setDelegate:nil];
    [clientSocket disconnect];
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
    NSLog(@"Configured");
    char contentLen[50];
    
    NSData *configData = [NSJSONSerialization dataWithJSONObject:configDict options:0 error:&err];
    
    for (NSMutableDictionary *object in ftcClients){
        if( [[object objectForKey:@"Tag"] longValue] == [client longValue]){
            clientDict = object;
            break;
        }
    }
    
    if( CFHTTPMessageIsRequest (inComingMessageArray[[client intValue]]) == false){
        CFURLRef urlRef = CFURLCreateWithString(kCFAllocatorDefault, CFSTR("/config-write"), NULL);
        httpRespondMessage = CFHTTPMessageCreateRequest(kCFAllocatorDefault, CFSTR("POST"), urlRef, kCFHTTPVersion1_1) ;
    }else{
        httpRespondMessage = CFHTTPMessageCreateResponse ( kCFAllocatorDefault, 200, NULL, kCFHTTPVersion1_1 );
    }
    
    CFHTTPMessageSetHeaderFieldValue(httpRespondMessage, CFSTR("Content-Type"), CFSTR("application/json"));
    
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
    NSLog(@"Configured");
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
}


#pragma mark - TCP delegate

- (void)onSocket:(AsyncSocket *)sock didConnectToHost:(NSString *)host port:(UInt16)port
{
    NSLog(@"connected");
    
    char contentLen[50];
    NSError *err;
    NSNumber *tag = nil;
    if(_mode != EASYLINK_SOFT_AP)
        return;
    
    
    NSMutableDictionary *configDictTmp = [NSMutableDictionary dictionaryWithDictionary:_configDict];
    [configDictTmp setObject:[[NSString alloc] initWithData:[configDictTmp objectForKey:KEY_SSID] encoding:NSUTF8StringEncoding]
                              forKey:KEY_SSID];
    
    NSData *configData = [NSJSONSerialization dataWithJSONObject:configDictTmp options:0 error:&err];
    
    if(_wlanUnConfigured == true){ //uAP mode -> connected to uap, send config
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
    }else{ //uAP mode -> connected to target ap, read config
        CFURLRef urlRef = CFURLCreateWithString(kCFAllocatorDefault, CFSTR("/config-read"), NULL);
        CFHTTPMessageRef httpRequestMessage = CFHTTPMessageCreateRequest (kCFAllocatorDefault,
                                                                          CFSTR("GET"),
                                                                          urlRef,
                                                                          kCFHTTPVersion1_1);
        CFDataRef httpData = CFHTTPMessageCopySerializedMessage ( httpRequestMessage );
        [sock writeData:(__bridge NSData*)httpData withTimeout:-1 tag:0];
        CFRelease(httpData);
        CFRelease(httpRequestMessage);
        CFRelease(urlRef);
        
        [sock readDataWithTimeout:-1 tag:[tag intValue]];
    }
    
}

- (void)onSocket:(AsyncSocket *)sock didAcceptNewSocket:(AsyncSocket *)newSocket
{
    NSNumber *tag = nil;
    AsyncSocket *clientSocket = newSocket;
    
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
    [ftcClients addObject:client];
    NSLog(@"New socket client, %d", [tag intValue]);
    
    [clientSocket readDataWithTimeout:100 tag:[tag longValue]];
}

- (void)onSocket:(AsyncSocket *)sock willDisconnectWithError:(NSError *)err
{
    if (err) {
        NSLog(@"Socket connect failed: %@", [err localizedDescription]);
    }
}

/**/
- (void)onSocketDidDisconnect:(AsyncSocket *)sock
{
    NSNumber *tag = nil;
    NSDictionary *disconnnectedClient;
    NSLog(@"TCP disconnect");
    
    /*Stop the timeout counter for closing a client after send the config data.*/
    if(closeFTCClientTimer != nil){
        if([closeFTCClientTimer userInfo] == sock){
            [closeFTCClientTimer invalidate];
            closeFTCClientTimer = nil;
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
        CFRelease(inComingMessageArray[[tag intValue]]);
        inComingMessageArray[[tag intValue]] = nil;
        [ftcClients removeObject: disconnnectedClient];
        if([theDelegate respondsToSelector:@selector(onDisconnectFromFTC:)] && _wlanUnConfigured == false)
            [theDelegate onDisconnectFromFTC:tag];
    }
}

- (void)onSocket:(AsyncSocket *)sock didReadData:(NSData *)data withTag:(long)tag
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
    NSLog(@"%lu/%lu", (unsigned long)currentLength, (unsigned long)contentLength);
    
    if(currentLength < contentLength){
        [sock readDataToLength:(contentLength-currentLength) withTimeout:100 tag:(long)tag];
        return;
    }

    if(CFHTTPMessageIsRequest(inComingMessage) == true ){
        CFURLRef urlRef = CFHTTPMessageCopyRequestURL(inComingMessage);
        CFStringRef urlPathRef= CFURLCopyPath (urlRef);
        CFRelease(urlRef);
        NSString *urlPath= (__bridge_transfer NSString*)urlPathRef;
        NSLog(@"URL: %@", urlPath);
        
        if([urlPath rangeOfString:@"/auth-setup"].location != NSNotFound || [urlPath rangeOfString:@"/config-read"].location != NSNotFound){
            httpRespondMessage = CFHTTPMessageCreateResponse ( kCFAllocatorDefault, 202, NULL, kCFHTTPVersion1_1 );
            CFDataRef httpData = CFHTTPMessageCopySerializedMessage ( httpRespondMessage );
            [sock writeData:(__bridge_transfer NSData*)httpData withTimeout:20 tag:[[client objectForKey:@"Tag"] longValue]];
            [self stopTransmitting];
            if([theDelegate respondsToSelector:@selector(onFoundByFTC: withConfiguration:)]){
                configuration = [NSJSONSerialization JSONObjectWithData:body
                                                              options:NSJSONReadingMutableContainers|NSJSONReadingMutableLeaves
                                                                error:&err];
                if (err) {
                    temp = [[NSString alloc] initWithData:body encoding:NSASCIIStringEncoding];
                    NSLog(@"Unpackage JSON data failed:%@, %@", [err localizedDescription], temp);
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
            
            [sock disconnect];
        }
        
        NSMutableDictionary *foundModule = [NSJSONSerialization JSONObjectWithData:body
                                                                           options:NSJSONReadingMutableContainers|NSJSONReadingMutableLeaves
                                                                             error:&err];
        if ( [[foundModule objectForKey:@"T"] isEqualToString:@"Current Configuration"] == true ){
            [self stopTransmitting];
            if([theDelegate respondsToSelector:@selector(onFoundByFTC: withConfiguration:)]){
                configuration = [NSJSONSerialization JSONObjectWithData:body
                                                                options:NSJSONReadingMutableContainers|NSJSONReadingMutableLeaves
                                                                  error:&err];
                if (err) {
                    temp = [[NSString alloc] initWithData:body encoding:NSASCIIStringEncoding];
                    NSLog(@"Unpackage JSON data failed:%@, %@", [err localizedDescription], temp);
                    return;
                }
                [theDelegate onFoundByFTC:[NSNumber numberWithLong:tag] withConfiguration: configuration];
            }
        }else{
            
        }
    }
    
    /*Recv data that server can send FIN+ACK when client disconnect*/
    [sock readDataWithTimeout:-1 tag:(long)tag];
}

- (void)onSocket:(AsyncSocket *)sock didWriteDataWithTag:(long)tag
{
    NSLog(@"Send complete!");
}

- (void)closeClient:(NSTimer *)timer
{
    [(AsyncSocket *)[timer userInfo] disconnect];
    [timer invalidate];
    timer = nil;
}

/*
 Notification method handler when app enter in forground
 @param the fired notification object
 */
- (void)appEnterInforground:(NSNotification*)notification{
    NSError *err = nil;
    ftcServerSocket = [[AsyncSocket alloc] initWithDelegate:self];
    [ftcServerSocket acceptOnPort:FTC_PORT error:&err];
    if (err) {
        NSLog(@"Setup TCP server failed:%@", [err localizedDescription]);
    }
    NetworkStatus netStatus = [wifiReachability currentReachabilityStatus];
    
    if ( netStatus != NotReachable ) {
        if(_softAPSending == true){
            [self transmitSettings];
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

- (void)appEnterInBackground:(NSNotification*)notification{
    if(ftcServerSocket != nil){
        NSLog(@"Close FTC server");
        [ftcServerSocket setDelegate:nil];
        [ftcServerSocket disconnect];
        ftcServerSocket = nil;
    }
}


/*
 Notification method handler when status of wifi changes
 @param the fired notification object
 */
- (void)wifiStatusChanged:(NSNotification*)notification{
    Reachability *verifyConnection = [notification object];
    NetworkStatus netStatus = [verifyConnection currentReachabilityStatus];
    
    if ( netStatus != NotReachable ) {
        if(_softAPSending == true){
            [self transmitSettings];
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
                    address = [NSString stringWithUTF8String:inet_ntoa(((struct sockaddr_in *)temp_addr->ifa_addr)->sin_addr)];
                    
                    //                    NSLog(@"subnet mask == %@",[NSString stringWithUTF8String:inet_ntoa(((struct sockaddr_in *)temp_addr->ifa_netmask)->sin_addr)]);
                    //
                    //                    NSLog(@"dest mask == %@",[NSString stringWithUTF8String:inet_ntoa(((struct sockaddr_in *)temp_addr->ifa_dstaddr)->sin_addr)]);
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
                    address = [NSString stringWithUTF8String:inet_ntoa(((struct sockaddr_in *)temp_addr->ifa_netmask)->sin_addr)];
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
                    address = [NSString stringWithUTF8String:inet_ntoa(((struct sockaddr_in *)temp_addr->ifa_dstaddr)->sin_addr)];
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
    char *address = NULL;

    NSString *routerAddrses = @"";
    
    if(sysctl(mib, sizeof(mib)/sizeof(int), 0, &l, 0, 0) < 0) {
        return routerAddrses;
    }
    if(l<=0)
        return routerAddrses;
    
    buf = malloc(l);
    if(sysctl(mib, sizeof(mib)/sizeof(int), buf, &l, 0, 0) < 0) {
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
                address = inet_ntoa(((struct sockaddr_in *)(sa_tab[RTAX_GATEWAY]))->sin_addr);
                break;
            }
        }
    }
    free(buf);

    routerAddrses = [[NSString alloc] initWithFormat:@"%s",address];    
    return routerAddrses;
}
#endif

@end
