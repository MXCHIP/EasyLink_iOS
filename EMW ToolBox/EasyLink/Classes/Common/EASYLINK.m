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

#if TARGET_IPHONE_SIMULATOR
#include <net/route.h>
#else
#include "route.h"
#endif

#define MessageCount 100
CFHTTPMessageRef inComingMessageArray[MessageCount];

@interface EASYLINK (privates)

- (void)broadcastStartConfigure:(id)sender;
- (void)multicastStartConfigure:(id)sender;
- (void)closeClient:(NSTimer *)timer;
- (BOOL)isFTCServerStarted;
- (void)prepareEasyLinkV1:(NSString *)bSSID password:(NSString *)bpasswd;
- (void)prepareEasyLinkV2:(NSString *)bSSID password:(NSString *)bpasswd info: (NSData *)userInfo;
- (void)prepareEasyLinkPlus:(NSString *)bSSID password:(NSString *)bpasswd info: (NSData *)userInfo;

@end

@implementation EASYLINK
@synthesize multicastArray;
@synthesize broadcastArray;
@synthesize ftcClients;
@synthesize multicastSocket;
@synthesize broadcastSocket;
@synthesize ftcServerSocket;

-(id)init{
    NSLog(@"Init EasyLink");
    self = [super init];
    NSError *err;
    if (self) {
        // Initialization code
        self.broadcastArray = [NSMutableArray array];
        self.multicastArray = [NSMutableArray array];
        
        self.ftcClients = [NSMutableArray arrayWithCapacity:10];
        self.broadcastSocket = [[AsyncUdpSocket alloc] initWithDelegate:nil];
        [self.broadcastSocket enableBroadcast:YES error:&err];
        
        self.multicastSocket = [[AsyncUdpSocket alloc] initWithDelegate:nil];
        
        multicastSendInterval = nil;
        broadcastSendInterval = nil;
        
        for(NSUInteger idx = 0; idx<MessageCount; idx++){
            inComingMessageArray[idx] = nil;
        }
        

    }
    return self;
}

-(void)dealloc{
    NSLog(@"unInit EasyLink");
    [self closeFTCServer];
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
- (void)prepareEasyLink_withFTC:(NSArray *)wlanConfigArray info: (NSData *)userInfo version: (NSUInteger)ver
{
    struct ifaddrs *interfaces = NULL;
    struct ifaddrs *temp_addr = NULL;
    in_addr_t ip, netmask, gateway, dns1, dns2;
    bool dhcp;
    NSUInteger idx ;
    
    NSString *wlanConfig[20] = {nil};
    
    NSString *bSSID, *bpasswd;
    char seperate = '#';
    
    for(idx = 0; idx < [wlanConfigArray count]; idx++){
        wlanConfig[idx] = [wlanConfigArray objectAtIndex:idx];
    }
    
    version = ver;
    
    bSSID = wlanConfig[INDEX_SSID];
    bpasswd = wlanConfig[INDEX_PASSWORD];
    
    ip = wlanConfig[INDEX_IP]==nil? -1:htonl(inet_addr([ wlanConfig[INDEX_IP] cStringUsingEncoding:NSASCIIStringEncoding]));
    netmask = wlanConfig[INDEX_NETMASK]==nil? -1:htonl(inet_addr([wlanConfig[INDEX_NETMASK] cStringUsingEncoding:NSASCIIStringEncoding]));
    gateway = wlanConfig[INDEX_GATEWAY]==nil? -1:htonl(inet_addr([wlanConfig[INDEX_GATEWAY] cStringUsingEncoding:NSASCIIStringEncoding]));
    dns1 = wlanConfig[INDEX_DNS1]==nil? -1:htonl(inet_addr([wlanConfig[INDEX_DNS1] cStringUsingEncoding:NSASCIIStringEncoding]));
    dns2 = wlanConfig[INDEX_DNS2]==nil? -1:htonl(inet_addr([wlanConfig[INDEX_DNS2] cStringUsingEncoding:NSASCIIStringEncoding]));
    dhcp = [wlanConfig[INDEX_DHCP] boolValue];
    if(dhcp==YES)
        ip = -1;
    
    if (userInfo == nil) userInfo = [NSData dataWithBytes:nil length:0];
    
    int success = 0;
    uint32_t address = 0;
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
                    address = htonl(((struct sockaddr_in *)temp_addr->ifa_addr)->sin_addr.s_addr);
                }
            }
            temp_addr = temp_addr->ifa_next;
        }
    }
    // Free/release memory
    freeifaddrs(interfaces);
    
    NSMutableData *userInfoWithIP = [NSMutableData dataWithCapacity:200];
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
    
    [self prepareEasyLinkV2:bSSID password:bpasswd info: userInfoWithIP];
    [self prepareEasyLinkPlus:bSSID password:bpasswd info: userInfoWithIP];

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
    [self.multicastArray removeAllObjects];
    
    // 239.118.0.0
    for (NSUInteger idx = 0; idx != 5; ++idx) {
        NSMutableDictionary *dictionary = [NSMutableDictionary dictionary];
        [dictionary setValue:[NSMutableData dataWithLength:headerLength] forKey:@"sendData"];
        [dictionary setValue:@"239.118.0.0" forKey:@"host"];
        [self.multicastArray addObject:dictionary];
    }
    
    // 239.126.ssidlen.passwdlen
    NSMutableDictionary *dictionary = [NSMutableDictionary dictionary];
    [dictionary setValue:[NSMutableData dataWithLength:headerLength] forKey:@"sendData"];
    [dictionary setValue:[NSString stringWithFormat:@"239.126.%lu.%lu", (unsigned long)bSSID_length, (unsigned long)bpasswd_length] forKey:@"host"];
    [self.multicastArray addObject:dictionary];
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
        [self.multicastArray addObject:dictionary];
    }
    
    // 239.126.userinfolen.0
    dictionary = [NSMutableDictionary dictionary];
    [dictionary setValue:[NSMutableData dataWithLength:headerLength] forKey:@"sendData"];
    [dictionary setValue:[NSString stringWithFormat:@"239.126.%lu.0", (unsigned long)userInfo_length] forKey:@"host"];
    [self.multicastArray addObject:dictionary];
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
        [self.multicastArray addObject:dictionary];
    }
}

- (void)addSeqHook: (uint32_t)seqNo forBroadcastArray: (NSMutableArray *)inArray
{
    if (((seqNo)%4)==3) {
        seqHook++;
        [inArray addObject:[NSMutableData dataWithLength:(0x500+seqHook)]];
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
    //UInt8 intnum;
    UInt16 chechSum = 0;
    uint32_t seqNo = 0;
    seqHook = 0;
    
    
    NSUInteger totalLen = 0x5 + bssid_length + bpasswd_length + userInfo_length;
    
    NSUInteger addedConst[4] = {0x100, 0x200, 0x300, 0x400};
    NSUInteger addedConstIdx = 0;
    
    [self.broadcastArray removeAllObjects];
    /*0x5AA|0x5AB|0x5AC|Total len|BSSID[3]|BSSID[4]|BSSID[5]|Key len|Key|User info|Checksum high|Checksum low*/
    
    [self.broadcastArray addObject:[NSMutableData dataWithLength:0x5AA]];
    [self.broadcastArray addObject:[NSMutableData dataWithLength:0x5AB]];
    [self.broadcastArray addObject:[NSMutableData dataWithLength:0x5AC]];
    
    /*Total len*/
    [self.broadcastArray addObject:[NSMutableData dataWithLength:( totalLen + addedConst[(addedConstIdx++)%4] )]];
    chechSum += totalLen;
    [self addSeqHook: seqNo++ forBroadcastArray: self.broadcastArray];
    
    /*SSID len*/
    [self.broadcastArray addObject:[NSMutableData dataWithLength:( bssid_length + addedConst[(addedConstIdx++)%4] )]];
    chechSum += bssid_length;
    [self addSeqHook: seqNo++ forBroadcastArray: self.broadcastArray];
    
    /*Key len*/
    [self.broadcastArray addObject:[NSMutableData dataWithLength:( bpasswd_length + addedConst[(addedConstIdx++)%4] )]];
    chechSum += bpasswd_length;
    [self addSeqHook: seqNo++ forBroadcastArray: self.broadcastArray];
    
    /*SSID*/
    for (NSUInteger idx = 0; idx != bssid_length; ++idx) {
        [self.broadcastArray addObject:[NSMutableData dataWithLength:( bSSID_UTF8[idx] + addedConst[(addedConstIdx++)%4] )]];
        chechSum += bSSID_UTF8[idx];
        [self addSeqHook: seqNo++ forBroadcastArray: self.broadcastArray];
    }

    /*Key*/
    for (NSUInteger idx = 0; idx != bpasswd_length; ++idx) {
        [self.broadcastArray addObject:[NSMutableData dataWithLength:( bpasswd_UTF8[idx] + addedConst[(addedConstIdx++)%4] )]];
        chechSum += bpasswd_UTF8[idx];
        [self addSeqHook: seqNo++ forBroadcastArray: self.broadcastArray];
    }
    

    /*User info*/
    for (NSUInteger idx = 0; idx != userInfo_length; ++idx) {
        [self.broadcastArray addObject:[NSMutableData dataWithLength:( userInfo_UTF8[idx] + addedConst[(addedConstIdx++)%4] )]];
        chechSum += userInfo_UTF8[idx];
        [self addSeqHook: seqNo++ forBroadcastArray: self.broadcastArray];
    }
    
    /*Checksum high*/
    [self.broadcastArray addObject:[NSMutableData dataWithLength:( ((chechSum&0xFF00)>>8) + addedConst[(addedConstIdx++)%4] )]];
    [self addSeqHook: seqNo++ forBroadcastArray: self.broadcastArray];
    
    /*Checksum low*/
    [self.broadcastArray addObject:[NSMutableData dataWithLength:( (chechSum&0x00FF) + addedConst[(addedConstIdx++)%4] )]];
    [self addSeqHook: seqNo++ forBroadcastArray: self.broadcastArray];
}

- (void)transmitSettings
{
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

    if(version == EASYLINK_PLUS){
        broadcastSendInterval =[NSTimer scheduledTimerWithTimeInterval:0.01 target:self selector:@selector(broadcastStartConfigure:) userInfo:nil repeats:YES];
        multicastSendInterval =[NSTimer scheduledTimerWithTimeInterval:0.05 target:self selector:@selector(multicastStartConfigure:) userInfo:nil repeats:YES];
    }else{
        multicastSendInterval =[NSTimer scheduledTimerWithTimeInterval:0.01 target:self selector:@selector(multicastStartConfigure:) userInfo:nil repeats:YES];
    }
        
    
    
}

- (void)stopTransmitting
{
    if(broadcastSendInterval != nil){
        [broadcastSendInterval invalidate];
        broadcastSendInterval = nil;
    }
    if(multicastSendInterval != nil){
        [multicastSendInterval invalidate];
        multicastSendInterval = nil;
    }

}

- (void)broadcastStartConfigure:(id)sender{
    [self.broadcastSocket sendData:[self.broadcastArray objectAtIndex:broadcastcount] toHost:[EASYLINK getBroadcastAddress] port:65523 withTimeout:10 tag:0];
    ++broadcastcount;
    if (broadcastcount == [self.broadcastArray count]) broadcastcount = 0;
}

- (void)multicastStartConfigure:(id)sender{
    [self.multicastSocket sendData:[[self.multicastArray objectAtIndex:multicastCount] objectForKey:@"sendData"] toHost:[[self.multicastArray objectAtIndex:multicastCount] objectForKey:@"host"] port:65523 withTimeout:10 tag:0];
    ++multicastCount;
    if (multicastCount == [self.multicastArray count]) multicastCount = 0;
}

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
    
    httpRespondMessage = CFHTTPMessageCreateResponse ( kCFAllocatorDefault, 200, NULL, kCFHTTPVersion1_1 );
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
    
    httpRespondMessage = CFHTTPMessageCreateResponse ( kCFAllocatorDefault, 200, NULL, kCFHTTPVersion1_1 );
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
- (void)onSocket:(AsyncSocket *)sock didAcceptNewSocket:(AsyncSocket *)newSocket
{
    NSNumber *tag = nil;
    AsyncSocket *clientSocket = newSocket;
    //NSLog(@"New socket client");
    
    NSMutableDictionary *client = [[NSMutableDictionary alloc]initWithCapacity:5];
    for (NSUInteger idx=0; idx!=MessageCount; idx++) {
        if(inComingMessageArray[idx]==nil){
            inComingMessageArray[idx] = CFHTTPMessageCreateEmpty(kCFAllocatorDefault, TRUE);
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
    
    CFRelease(inComingMessageArray[[tag intValue]]);
    inComingMessageArray[[tag intValue]] = nil;
    [self.ftcClients removeObject: disconnnectedClient];
    if([theDelegate respondsToSelector:@selector(onDisconnectFromFTC:)])
        [theDelegate onDisconnectFromFTC:tag];
}

- (void)onSocket:(AsyncSocket *)sock didReadData:(NSData *)data withTag:(long)tag
{
    CFHTTPMessageRef inComingMessage, httpRespondMessage;
    NSUInteger contentLength, currentLength;
    NSMutableDictionary *client;
    inComingMessage = inComingMessageArray[tag];

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

    
    CFURLRef urlRef = CFHTTPMessageCopyRequestURL(inComingMessage);
    CFStringRef urlPathRef= CFURLCopyPath (urlRef);
    CFRelease(urlRef);
    NSString *urlPath= (__bridge_transfer NSString*)urlPathRef;
    NSLog(@"URL: %@", urlPath);
    
    if([urlPath rangeOfString:@"/auth-setup"].location != NSNotFound){
        httpRespondMessage = CFHTTPMessageCreateResponse ( kCFAllocatorDefault, 202, NULL, kCFHTTPVersion1_1 );
        CFDataRef httpData = CFHTTPMessageCopySerializedMessage ( httpRespondMessage );
        [sock writeData:(__bridge_transfer NSData*)httpData withTimeout:20 tag:[[client objectForKey:@"Tag"] longValue]];
        if([theDelegate respondsToSelector:@selector(onFoundByFTC: currentConfig:)])
            [theDelegate onFoundByFTC:[NSNumber numberWithLong:tag] currentConfig: body];
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

#pragma mark -
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
