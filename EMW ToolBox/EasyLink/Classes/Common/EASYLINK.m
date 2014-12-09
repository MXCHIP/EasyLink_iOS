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



#define EasyLinkPlusDelayPerByte    0.005
#define EasyLinkPlusDelayPerBlock   0.08
#define EasyLinkV2DelayPerBlock     0.04

#define kEasyLinkConfigServiceType @"_easylink_config._tcp"
#define kInitialDomain  @"local"



@implementation NSMutableArray (Additions)
- (void)insertEasyLinkPlusData:(NSUInteger)length
{
    [self addObject:[NSMutableDictionary dictionaryWithObjectsAndKeys: [NSMutableData dataWithLength:length], @"sendData", [NSNumber numberWithFloat:EasyLinkPlusDelayPerByte], @"Delay", nil]];
}

- (void)insertEasyLinkPlusBlockIndex:(uint32_t *)blockIndex forSeqNo: (uint32_t)seqNo
{
    if (((seqNo)%4)==3) {
        (*blockIndex)++;
        [(NSMutableDictionary *)([self lastObject]) setObject:[NSNumber numberWithFloat:EasyLinkPlusDelayPerBlock] forKey:@"Delay"];
        [self addObject:[NSDictionary dictionaryWithObjectsAndKeys: [NSMutableData dataWithLength:(0x500+ *blockIndex)], @"sendData", [NSNumber numberWithFloat:EasyLinkPlusDelayPerBlock], @"Delay", nil]];
    }
}

@end


@interface EASYLINK ()

@property (nonatomic, retain, readwrite) NSNetServiceBrowser* netServiceBrowser;
@property (nonatomic, retain, readwrite) NSMutableArray* netServiceArray;


- (void)broadcastStartConfigure:(id)sender;
- (void)multicastStartConfigure:(id)sender;
- (void)closeClient:(NSTimer *)timer;
- (BOOL)isFTCServerStarted;
- (void)prepareEasyLinkV2:(NSString *)bSSID password:(NSString *)bpasswd info: (NSData *)userInfo;
- (void)prepareEasyLinkPlus:(NSString *)bSSID password:(NSString *)bpasswd info: (NSData *)userInfo;

@end

@implementation EASYLINK

@synthesize ftcClients;
@synthesize multicastSocket;
@synthesize broadcastSocket;
@synthesize ftcServerSocket;
@synthesize netServiceBrowser = _netServiceBrowser;
@synthesize netServiceArray = _netServiceArray;

-(id)init{
    NSLog(@"Init EasyLink");
    self = [super init];
    NSError *err;
    if (self) {
        // Initialization code
        mode = EASYLINK_PLUS;
        
        broadcastArray = [NSMutableArray array];
        multicastArray = [NSMutableArray array];
        
        self.ftcClients = [NSMutableArray arrayWithCapacity:10];
        self.broadcastSocket = [[AsyncUdpSocket alloc] initWithDelegate:nil];
        [self.broadcastSocket enableBroadcast:YES error:&err];
        
        self.multicastSocket = [[AsyncUdpSocket alloc] initWithDelegate:nil];
        
        multicastSending = false;
        broadcastSending = false;
        softAPSending = false;
        wlanUnConfigured = false;
        
        for(NSUInteger idx = 0; idx<MessageCount; idx++){
            inComingMessageArray[idx] = nil;
        }
        
        broadcastcount = 0;
        multicastCount = 0;
        
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(appEnterInforground:) name:UIApplicationDidBecomeActiveNotification object:nil];
        
        // wifi notification when changed.
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(wifiStatusChanged:) name:kReachabilityChangedNotification object:nil];

    }
    return self;
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


- (void)startFTCServerWithDelegate:(id)delegate;
{
    NSError *err = nil;
    NSLog(@"Start FTC server");
    ftcServerSocket = [[AsyncSocket alloc] initWithDelegate:self];
    [ftcServerSocket acceptOnPort:FTC_PORT error:&err];
    if (err) {
        NSLog(@"Setup TCP server failed:%@", [err localizedDescription]);
    }
	theDelegate = delegate;
}

- (void)closeFTCServer
{
    for (NSMutableDictionary *object in self.ftcClients)
    {
        NSLog(@"Close FTC clients");
        AsyncSocket *clientSocket = [object objectForKey:@"Socket"];
        [clientSocket setDelegate:nil];
        [clientSocket disconnect];
        clientSocket = nil;
    }
    if(self.ftcServerSocket != nil){
        NSLog(@"Close FTC server");
        [self.ftcServerSocket setDelegate:nil];
        [self.ftcServerSocket disconnect];
        self.ftcServerSocket = nil;
    }
    
    self.ftcClients = nil;
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
    if(self.ftcServerSocket == nil)
        return NO;
    else
        return YES;
}


//- (void)prepareEasyLinkV2_withFTC:(NSString *)bSSID password:(NSString *)bpasswd info: (NSData *)userInfo
- (void)prepareEasyLink_withFTC:(NSDictionary *)wlanConfigArray info: (NSData *)userInfo mode: (EasyLinkMode)easyLinkMode;
{
    NSString *ipAddress;
    char seperate = '#';
    
    mode = easyLinkMode;
    configDict = wlanConfigArray;
    
    ssid = [wlanConfigArray objectForKey:KEY_SSID];
    passwd = [wlanConfigArray objectForKey:KEY_PASSWORD];
    
    ipAddress = [wlanConfigArray objectForKey:KEY_IP];
    ip = ipAddress==nil? -1:htonl(inet_addr([ipAddress cStringUsingEncoding:NSASCIIStringEncoding]));
    
    ipAddress = [wlanConfigArray objectForKey:KEY_NETMASK];
    netmask = ipAddress==nil? -1:htonl(inet_addr([ipAddress cStringUsingEncoding:NSASCIIStringEncoding]));
    
    ipAddress = [wlanConfigArray objectForKey:KEY_GATEWAY];
    gateway = ipAddress==nil? -1:htonl(inet_addr([ipAddress cStringUsingEncoding:NSASCIIStringEncoding]));
    
    ipAddress = [wlanConfigArray objectForKey:KEY_DNS1];
    dns1 = ipAddress==nil? -1:htonl(inet_addr([ipAddress cStringUsingEncoding:NSASCIIStringEncoding]));
    
    ipAddress = [wlanConfigArray objectForKey:KEY_DNS2];
    dns2 = ipAddress==nil? -1:htonl(inet_addr([ipAddress cStringUsingEncoding:NSASCIIStringEncoding]));
    
    dhcp = [[wlanConfigArray objectForKey:KEY_DHCP]  boolValue];
    if(dhcp==YES)
        ip = -1;
    
    if (userInfo == nil) userInfo = [NSData dataWithBytes:nil length:0];
    
    uint32_t address = htonl(inet_addr([[EASYLINK getIPAddress] cStringUsingEncoding:NSUTF8StringEncoding])) ;
    
    userInfoWithIP = [NSMutableData dataWithCapacity:200];
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
    
    if(easyLinkMode == EASYLINK_V2 || easyLinkMode == EASYLINK_PLUS){
        [self prepareEasyLinkV2:ssid password:passwd info: userInfoWithIP];
        [self prepareEasyLinkPlus:ssid password:passwd info: userInfoWithIP];
    }


}


- (void)prepareEasyLinkV2:(NSString *)bSSID password:(NSString *)bpasswd info: (NSData *)userInfo
{
    if (bSSID == nil) bSSID = @"";
    if (bpasswd == nil) bpasswd = @"";
    if (userInfo == nil) userInfo = [NSData dataWithBytes:nil length:0];
    NSString *mergeString =  [bSSID stringByAppendingString:bpasswd];
    
    const char *bSSID_UTF8 = [bSSID UTF8String];
    const char *bpasswd_UTF8 = [bpasswd UTF8String];
    const uint8_t *userInfo_UTF8 = [userInfo bytes];
    const char *mergeString_UTF8 = [mergeString UTF8String];
    
    NSUInteger bSSID_length = strlen(bSSID_UTF8);
    NSUInteger bpasswd_length = strlen(bpasswd_UTF8);
    NSUInteger userInfo_length = [userInfo length];
    NSUInteger mergeString_Length = strlen(mergeString_UTF8);
    
    NSUInteger headerLength = 20;
    [multicastArray removeAllObjects];
    
    // 239.118.0.0
    for (NSUInteger idx = 0; idx != 5; ++idx) {
        NSMutableDictionary *dictionary = [NSMutableDictionary dictionary];
        [dictionary setValue:[NSMutableData dataWithLength:headerLength] forKey:@"sendData"];
        [dictionary setValue:@"239.118.0.0" forKey:@"host"];
        [dictionary setValue:[NSNumber numberWithFloat:EasyLinkV2DelayPerBlock] forKey:@"Delay"];
        [multicastArray addObject:dictionary];
    }
    
    // 239.126.ssidlen.passwdlen
    NSMutableDictionary *dictionary = [NSMutableDictionary dictionary];
    [dictionary setValue:[NSMutableData dataWithLength:headerLength] forKey:@"sendData"];
    [dictionary setValue:[NSString stringWithFormat:@"239.126.%lu.%lu", (unsigned long)bSSID_length, (unsigned long)bpasswd_length] forKey:@"host"];
    [dictionary setValue:[NSNumber numberWithFloat:EasyLinkV2DelayPerBlock] forKey:@"Delay"];
    [multicastArray addObject:dictionary];
    headerLength++;
    
    // 239.126.mergeString[idx],mergeString[idx+1]
    for (NSUInteger idx = 0; idx < mergeString_Length; idx += 2, headerLength++) {
        Byte a = mergeString_UTF8[idx];
        Byte b = 0;
        if (idx + 1 != mergeString_Length)
            b = mergeString_UTF8[idx+1];
        
        dictionary = [NSMutableDictionary dictionary];
        
        [dictionary setValue:[NSMutableData dataWithLength:headerLength] forKey:@"sendData"];
        [dictionary setValue:[NSString stringWithFormat:@"239.126.%d.%d", a, b] forKey:@"host"];
        [dictionary setValue:[NSNumber numberWithFloat:EasyLinkV2DelayPerBlock] forKey:@"Delay"];
        [multicastArray addObject:dictionary];
    }
    
    // 239.126.userinfolen.0
    dictionary = [NSMutableDictionary dictionary];
    [dictionary setValue:[NSMutableData dataWithLength:headerLength] forKey:@"sendData"];
    [dictionary setValue:[NSString stringWithFormat:@"239.126.%lu.0", (unsigned long)userInfo_length] forKey:@"host"];
    [dictionary setValue:[NSNumber numberWithFloat:EasyLinkV2DelayPerBlock] forKey:@"Delay"];
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
        [dictionary setValue:[NSNumber numberWithFloat:EasyLinkV2DelayPerBlock] forKey:@"Delay"];
        [multicastArray addObject:dictionary];
    }
}

- (void)prepareEasyLinkPlus:(NSString *)bSSID password:(NSString *)bpasswd info: (NSData *)userInfo
{
    if (bSSID == nil) bSSID = @"";
    if (bpasswd == nil) bpasswd = @"";
    if (userInfo == nil) userInfo = [NSData dataWithBytes:nil length:0];
    
    const char *bSSID_UTF8 = [bSSID UTF8String];
    NSUInteger bssid_length = [bSSID length];
    const char *bpasswd_UTF8 = [bpasswd UTF8String];
    NSUInteger bpasswd_length = [bpasswd length];
    const uint8_t *userInfo_UTF8 = [userInfo bytes];
    NSUInteger userInfo_length = [userInfo length];
    uint16_t chechSum = 0;
    uint32_t seqNo = 0;
    uint32_t seqHook = 0;
    
    NSUInteger totalLen = 0x5 + bssid_length + bpasswd_length + userInfo_length;
    
    NSUInteger addedConst[4] = {0x100, 0x200, 0x300, 0x400};
    NSUInteger addedConstIdx = 0;
    
    [broadcastArray removeAllObjects];
    /*0x5AA|0x5AB|0x5AC|Total len|BSSID[3]|BSSID[4]|BSSID[5]|Key len|Key|User info|Checksum high|Checksum low*/
    
    [broadcastArray insertEasyLinkPlusData:0x5AA];
    [broadcastArray insertEasyLinkPlusData:0x5AB];
    [broadcastArray insertEasyLinkPlusData:0x5AC];
    
    /*Total len*/
    [broadcastArray insertEasyLinkPlusData:( totalLen + addedConst[(addedConstIdx++)%4] )];
    [broadcastArray insertEasyLinkPlusBlockIndex: &seqHook forSeqNo:seqNo++];
    chechSum += totalLen;

    /*SSID len*/
    [broadcastArray insertEasyLinkPlusData:( bssid_length + addedConst[(addedConstIdx++)%4] )];
    [broadcastArray insertEasyLinkPlusBlockIndex: &seqHook forSeqNo:seqNo++];
    chechSum += bssid_length;
    
    /*Key len*/
    [broadcastArray insertEasyLinkPlusData:( bpasswd_length + addedConst[(addedConstIdx++)%4] )];
    [broadcastArray insertEasyLinkPlusBlockIndex: &seqHook forSeqNo:seqNo++];
    chechSum += bpasswd_length;
    
    /*SSID*/
    for (NSUInteger idx = 0; idx != bssid_length; ++idx) {
        [broadcastArray insertEasyLinkPlusData:( bSSID_UTF8[idx] + addedConst[(addedConstIdx++)%4] )];
        [broadcastArray insertEasyLinkPlusBlockIndex: &seqHook forSeqNo:seqNo++];
        chechSum += bSSID_UTF8[idx];
    }

    /*Key*/
    for (NSUInteger idx = 0; idx != bpasswd_length; ++idx) {
        [broadcastArray insertEasyLinkPlusData:( bpasswd_UTF8[idx] + addedConst[(addedConstIdx++)%4] )];
        [broadcastArray insertEasyLinkPlusBlockIndex: &seqHook forSeqNo:seqNo++];
        chechSum += bpasswd_UTF8[idx];
    }
    

    /*User info*/
    for (NSUInteger idx = 0; idx != userInfo_length; ++idx) {
        [broadcastArray insertEasyLinkPlusData:( userInfo_UTF8[idx] + addedConst[(addedConstIdx++)%4] )];
        [broadcastArray insertEasyLinkPlusBlockIndex: &seqHook forSeqNo:seqNo++];
        chechSum += userInfo_UTF8[idx];
    }
    
    /*Checksum high*/
    [broadcastArray insertEasyLinkPlusData:( ((chechSum&0xFF00)>>8) + addedConst[(addedConstIdx++)%4] )];
    [broadcastArray insertEasyLinkPlusBlockIndex: &seqHook forSeqNo:seqNo++];
    
    /*Checksum low*/
    [broadcastArray insertEasyLinkPlusData:( (chechSum&0x00FF) + addedConst[(addedConstIdx++)%4] )];
    [broadcastArray insertEasyLinkPlusBlockIndex: &seqHook forSeqNo:seqNo++];
}


- (void)transmitSettings
{
    [self stopTransmitting];
    
    if(mode == EASYLINK_PLUS){
        broadcastSending = true;
        multicastSending = true;
        [self performSelector:@selector(broadcastStartConfigure:) withObject:self];
        [self performSelector:@selector(multicastStartConfigure:) withObject:self];

    }else if(mode == EASYLINK_V2){
        multicastSending = true;
        [self performSelector:@selector(multicastStartConfigure:) withObject:self];
        
    }else if(mode == EASYLINK_SOFT_AP) {
        softAPSending = true;
        self.netServiceBrowser.delegate = nil;
        NSNetServiceBrowser *aNetServiceBrowser = [[NSNetServiceBrowser alloc] init];
        if(!aNetServiceBrowser) {
            // The NSNetServiceBrowser couldn't be allocated and initialized.
            NSLog(@"Network service error!");
        }
        aNetServiceBrowser.delegate = self;
        self.netServiceBrowser = aNetServiceBrowser;
        self.netServiceArray = [[NSMutableArray alloc]initWithCapacity:10];
        
        [self.netServiceBrowser searchForServicesOfType:kEasyLinkConfigServiceType inDomain:kInitialDomain];
    }
}

- (void)stopTransmitting
{
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(broadcastStartConfigure: ) object:self];
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(multicastStartConfigure: ) object:self];
    broadcastSending = false;
    multicastSending = false;
    
    if(softAPSending == true){
        softAPSending = false;
        self.netServiceBrowser.delegate = nil;
        self.netServiceBrowser = nil;
        
        for (NSNetService *service in self.netServiceArray){
            service.delegate = nil;
        }
        self.netServiceArray = nil;
    }
}


- (void)broadcastStartConfigure:(id)sender{
    [self.broadcastSocket sendData:[[broadcastArray objectAtIndex:broadcastcount] objectForKey:@"sendData"] toHost:[EASYLINK getBroadcastAddress] port:65523 withTimeout:10 tag:0];
    ++broadcastcount;
    if (broadcastcount == [broadcastArray count]) broadcastcount = 0;
    if(broadcastSending == true)
        [self performSelector:@selector(broadcastStartConfigure:) withObject:self afterDelay:[(NSNumber *)([[broadcastArray objectAtIndex:broadcastcount] objectForKey:@"Delay"]) floatValue]];
}

- (void)multicastStartConfigure:(id)sender{
    [multicastSocket sendData:[[multicastArray objectAtIndex:multicastCount] objectForKey:@"sendData"] toHost:[[multicastArray objectAtIndex:multicastCount] objectForKey:@"host"] port:65523 withTimeout:10 tag:0];
    ++multicastCount;
    if (multicastCount == [multicastArray count]) multicastCount = 0;
    if(multicastSending == true)
        [self performSelector:@selector(multicastStartConfigure:) withObject:self afterDelay:[(NSNumber *)([[multicastArray objectAtIndex:multicastCount] objectForKey:@"Delay"]) floatValue]];
}

#pragma mark - Service browser

- (void)netServiceBrowser:(NSNetServiceBrowser*)netServiceBrowser didFindService:(NSNetService*)service moreComing:(BOOL)moreComing {
    // If a service came online, add it to the list and update the table view if no more events are queued.
    service.delegate = self;
    
    NSLog(@"service found %@",[service name]);
    [service resolveWithTimeout:0.0];
    [self.netServiceArray addObject:service];
}

- (void)netServiceDidResolveAddress:(NSNetService *)service
{
    NSDictionary *txtData;
    NSError *err;
    
    [service stop];
    
    txtData = [NSNetService dictionaryFromTXTRecordData: [service TXTRecordData]];
    if([[NSString alloc]initWithData:[txtData objectForKey:@"wlan unconfigured"] encoding:NSASCIIStringEncoding].boolValue == YES){
        wlanUnConfigured = true;
    }
    else{
        wlanUnConfigured = false;
    }
    
    //configSocket = [[AsyncSocket alloc] initWithDelegate:self];
    NSString *_address = [[[service addresses] objectAtIndex: 0] host];
    
    [[[AsyncSocket alloc] initWithDelegate:self] connectToHost:_address onPort:service.port withTimeout:4.0 error:&err];
}


#pragma mark - First time configuration

- (void)closeFTCClient:(NSNumber *)client
{
    NSMutableDictionary *clientDict;
    for (NSMutableDictionary *object in self.ftcClients){
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


- (void)configFTCClient:(NSNumber *)client withConfigurationData:(NSData* )configData
{
    CFHTTPMessageRef httpRespondMessage;
    NSMutableDictionary *clientDict;
    NSLog(@"Configured");
    char contentLen[50];
    
    for (NSMutableDictionary *object in self.ftcClients){
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
    
    for (NSMutableDictionary *object in self.ftcClients){
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
    NSData *configData = [NSJSONSerialization dataWithJSONObject:configDict options:0 error:&err];
    NSMutableDictionary *client = [[NSMutableDictionary alloc]initWithCapacity:5];
    
    if(mode != EASYLINK_SOFT_AP)
        return;
    
    for (NSUInteger idx=0; idx!=MessageCount; idx++) {
        if(inComingMessageArray[idx]==nil){
            inComingMessageArray[idx] = CFHTTPMessageCreateEmpty(kCFAllocatorDefault, false);
            tag = [NSNumber numberWithLong:(long)idx];
            break;
        }
    }
    if(tag == nil)
        return;
    
    [client setObject:sock forKey:@"Socket"];
    [client setObject:tag forKey:@"Tag"];
    [ftcClients addObject:client];
    NSLog(@"New socket client, %d", [tag intValue]);
    
    if(wlanUnConfigured == true){
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
    }else{
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
    //NSLog(@"New socket client");
    
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
        NSLog(@"Setup TCP server failed:%@, %@", sock, [err localizedDescription]);
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
    for (NSDictionary *object in self.ftcClients) {
        if([object objectForKey:@"Socket"] ==sock){
            tag = [object objectForKey:@"Tag"];
            disconnnectedClient = object;
            break;
        }
    }
    
    if(tag != nil){
        CFRelease(inComingMessageArray[[tag intValue]]);
        inComingMessageArray[[tag intValue]] = nil;
        [self.ftcClients removeObject: disconnnectedClient];
        if([theDelegate respondsToSelector:@selector(onDisconnectFromFTC:)])
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
        
        if([urlPath rangeOfString:@"/config-read"].location != NSNotFound){
            httpRespondMessage = CFHTTPMessageCreateResponse ( kCFAllocatorDefault, 202, NULL, kCFHTTPVersion1_1 );
            CFDataRef httpData = CFHTTPMessageCopySerializedMessage ( httpRespondMessage );
            [sock writeData:(__bridge_transfer NSData*)httpData withTimeout:20 tag:[[client objectForKey:@"Tag"] longValue]];
            if([theDelegate respondsToSelector:@selector(onFoundByFTC: currentConfig:)])
                [theDelegate onFoundByFTC:[NSNumber numberWithLong:tag] currentConfig: body];
        }
    }else{
        NSMutableDictionary *foundModule = [NSJSONSerialization JSONObjectWithData:body
                                                                           options:NSJSONReadingMutableContainers|NSJSONReadingMutableLeaves
                                                                             error:&err];
        if ( [[foundModule objectForKey:@"T"] isEqualToString:@"Current Configuration"] == true ){
            if([theDelegate respondsToSelector:@selector(onFoundByFTC: currentConfig:)])
                [theDelegate onFoundByFTC:[NSNumber numberWithLong:tag] currentConfig: body];
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
    NSLog(@"%s", __func__);
    if(softAPSending == true){
        self.netServiceBrowser.delegate = nil;
        NSNetServiceBrowser *aNetServiceBrowser = [[NSNetServiceBrowser alloc] init];
        if(!aNetServiceBrowser) {
            // The NSNetServiceBrowser couldn't be allocated and initialized.
            NSLog(@"Network service error!");
        }
        aNetServiceBrowser.delegate = self;
        self.netServiceBrowser = aNetServiceBrowser;
        [self.netServiceBrowser searchForServicesOfType:kEasyLinkConfigServiceType inDomain:kInitialDomain];
    }
}

/*
 Notification method handler when status of wifi changes
 @param the fired notification object
 */
- (void)wifiStatusChanged:(NSNotification*)notification{
    NSLog(@"%s", __func__);
    Reachability *verifyConnection = [notification object];
    NSAssert(verifyConnection != NULL, @"currentNetworkStatus called with NULL verifyConnection Object");
    NetworkStatus netStatus = [verifyConnection currentReachabilityStatus];
    
    if ( netStatus != NotReachable ) {
        if(softAPSending == true){
            self.netServiceBrowser.delegate = nil;
            NSNetServiceBrowser *aNetServiceBrowser = [[NSNetServiceBrowser alloc] init];
            if(!aNetServiceBrowser) {
                // The NSNetServiceBrowser couldn't be allocated and initialized.
                NSLog(@"Network service error!");
            }
            aNetServiceBrowser.delegate = self;
            self.netServiceBrowser = aNetServiceBrowser;
            [self.netServiceBrowser searchForServicesOfType:kEasyLinkConfigServiceType inDomain:kInitialDomain];
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
        ssid = [info objectForKey:@"SSID"];
    }
    info = nil;
    return ssid? ssid:@"";
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

    NSString *routerAddrses;
    
    if(sysctl(mib, sizeof(mib)/sizeof(int), 0, &l, 0, 0) < 0) {
        return nil;
    }
    if(l<=0)
        return nil;
    
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
