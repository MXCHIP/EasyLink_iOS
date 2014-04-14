//
//  EASYLINK.m
//  EasyLink
//
//  Created by William Xu on 13-7-24.
//  Copyright (c) 2013年 MXCHIP. All rights reserved.
//

#import "EASYLINK.h"
#import "sys/sysctl.h"

#define MessageCount 100
CFHTTPMessageRef inComingMessageArray[MessageCount];

static NSUInteger count = 0;


@interface EASYLINK (privates)

- (void)startConfigure:(id)sender;
- (void)closeClient:(NSTimer *)timer;

@end

@implementation EASYLINK
@synthesize array;
@synthesize ftcClients;
@synthesize socket;
@synthesize ftcServerSocket;
//@synthesize firstTimeConfig;

-(id)init{
    NSLog(@"Init EasyLink");
    self = [super init];
    if (self) {
        // Initialization code
        self.array = [NSMutableArray array];
        self.ftcClients = [NSMutableArray arrayWithCapacity:10];
        self.socket = [[AsyncUdpSocket alloc] initWithDelegate:nil];
        sendInterval = nil;
        firstTimeConfig = NO;
        
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


- (void)prepareEasyLinkV2_withFTC:(NSString *)bSSID password:(NSString *)bpasswd info: (NSData *)userInfo
{
    struct ifaddrs *interfaces = NULL;
    struct ifaddrs *temp_addr = NULL;
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
    
    NSMutableData *userInfoWithIP = [NSMutableData dataWithCapacity:([userInfo length]+sizeof(uint32_t))];
    [userInfoWithIP appendData:userInfo];
    [userInfoWithIP appendBytes:(const void *)&address length:sizeof(uint32_t)];
    
    [self prepareEasyLinkV2:bSSID password:bpasswd info: userInfoWithIP];
    firstTimeConfig = YES;
}


- (void)prepareEasyLinkV2:(NSString *)bSSID password:(NSString *)bpasswd info: (NSData *)userInfo
{
    if (bSSID == nil) bSSID = @"";
    if (bpasswd == nil) bpasswd = @"";
    if (userInfo == nil) userInfo = [NSData dataWithBytes:nil length:0];
    NSString *mergeString =  [bSSID stringByAppendingString:bpasswd];
    version = EASYLINK_V2;
    
    const char *bSSID_UTF8 = [bSSID UTF8String];
    const char *bpasswd_UTF8 = [bpasswd UTF8String];
    const char *userInfo_UTF8 = [userInfo bytes];
    const char *mergeString_UTF8 = [mergeString UTF8String];
    
    NSUInteger bSSID_length = strlen(bSSID_UTF8);
    NSUInteger bpasswd_length = strlen(bpasswd_UTF8);
    NSUInteger userInfo_length = [userInfo length];
    NSUInteger mergeString_Length = strlen(mergeString_UTF8);
    
    NSUInteger headerLength = 20;
    [self.array removeAllObjects];
    
    // 239.118.0.0
    for (NSUInteger idx = 0; idx != 5; ++idx) {
        NSMutableDictionary *dictionary = [NSMutableDictionary dictionary];
        [dictionary setValue:[NSMutableData dataWithLength:headerLength] forKey:@"sendData"];
        [dictionary setValue:@"239.118.0.0" forKey:@"host"];
        [self.array addObject:dictionary];
    }
    
    // 239.126.ssidlen.passwdlen
    NSMutableDictionary *dictionary = [NSMutableDictionary dictionary];
    [dictionary setValue:[NSMutableData dataWithLength:headerLength] forKey:@"sendData"];
    [dictionary setValue:[NSString stringWithFormat:@"239.126.%lu.%lu", (unsigned long)bSSID_length, (unsigned long)bpasswd_length] forKey:@"host"];
    [self.array addObject:dictionary];
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
        [self.array addObject:dictionary];
    }
    
    // 239.126.userinfolen.0
    dictionary = [NSMutableDictionary dictionary];
    [dictionary setValue:[NSMutableData dataWithLength:headerLength] forKey:@"sendData"];
    [dictionary setValue:[NSString stringWithFormat:@"239.126.%lu.0", (unsigned long)userInfo_length] forKey:@"host"];
    [self.array addObject:dictionary];
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
        [self.array addObject:dictionary];
    }
    firstTimeConfig = NO;

}

- (void)prepareEasyLinkV1:(NSString *)bSSID password:(NSString *)bpasswd
{
    version = EASYLINK_V1;
    if (bSSID == nil) bSSID = @"";
    if (bpasswd == nil) bpasswd = @"";
    
    Byte tempData[128], PD;
    NSUInteger sendData;
    firstTimeConfig = NO;
    
    const NSUInteger header1 = 3;
    const NSUInteger header2 = 23;
    
    const char *bSSID_UTF8 = [bSSID UTF8String];
    const char *bpasswd_UTF8 = [bpasswd UTF8String];
    
    NSUInteger bSSID_length = strlen(bSSID_UTF8);
    NSUInteger bpasswd_length = strlen(bpasswd_UTF8);
    
    [self.array removeAllObjects];
    for (NSUInteger idx = 0; idx != 10; ++idx) {
        [self.array addObject:[NSMutableData dataWithLength:header1]];
        [self.array addObject:[NSMutableData dataWithLength:header2]];
    }
    
    [self.array addObject:[NSMutableData dataWithLength:1399]];
    [self.array addObject:[NSMutableData dataWithLength:(28+bSSID_length)]];
    
    for (NSUInteger idx = 0; idx != bSSID_length; ++idx) {
        tempData[idx*2] = (bSSID_UTF8[idx]&0xF0)>>4;
        tempData[idx*2+1] = bSSID_UTF8[idx]&0xF;
    }
    
    //ND= ((PD^CP)&0xF<<4)|CD+0x251
    for (NSUInteger idx = 0; idx != bSSID_length*2; ++idx) {
        PD = (idx == 0)? 0x0:tempData[idx-1];
        sendData = 0x251 + ((((PD^idx)&0xF)<<4)|tempData[idx]);
        [self.array addObject:[NSMutableData dataWithLength:sendData]];
    }
    
    [self.array addObject:[NSMutableData dataWithLength:1459]];
    [self.array addObject:[NSMutableData dataWithLength:(28+bpasswd_length)]];
    
    for (NSUInteger idx = 0; idx != bpasswd_length; ++idx) {
        tempData[idx*2] = (bpasswd_UTF8[idx]&0xF0)>>4;
        tempData[idx*2+1] = bpasswd_UTF8[idx]&0xF;
    }
    
    //ND= ((PD^CP)&0xF<<4)|CD+0x251
    for (NSUInteger idx = 0; idx != bpasswd_length*2; ++idx) {
        PD = (idx == 0)? 0x0:tempData[idx-1];
        sendData = 0x251 + ((((PD^idx)&0xF)<<4)|tempData[idx]);
        [self.array addObject:[NSMutableData dataWithLength:sendData]];
    }
}

- (void)transmitSettings
{
    NSTimeInterval delay = 0.01;
    [self stopTransmitting];
    if(version == EASYLINK_V1)
        delay = 0.004;
    count = 0;

    sendInterval =[NSTimer scheduledTimerWithTimeInterval:delay target:self selector:@selector(startConfigure:) userInfo:nil repeats:YES];
    
}

- (void)stopTransmitting
{
    if(sendInterval != nil){
        [sendInterval invalidate];
        sendInterval = nil;
    }

}

- (void)startConfigure:(id)sender{
    if(version==EASYLINK_V2){
        //NSLog(@"Send data %@, length %d", [[self.array objectAtIndex:count] objectForKey:@"host"],[[[self.array objectAtIndex:count] objectForKey:@"sendData"] length] );
        [self.socket sendData:[[self.array objectAtIndex:count] objectForKey:@"sendData"] toHost:[[self.array objectAtIndex:count] objectForKey:@"host"] port:65523 withTimeout:10 tag:0];
        ++count;
        if (count == [self.array count]) count = 0;
    }
    else if (version==EASYLINK_V1){
        NSString *host=[EASYLINK getGatewayAddress];
        //NSLog(@"Send data %@, length %d", host, [[self.array objectAtIndex:count] length]);
        [self.socket sendData:[self.array objectAtIndex:count] toHost:host port:65523 withTimeout:10 tag:0];
        ++count;
        if (count == [self.array count]) count = 0;
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
        CFStringRef length = CFStringCreateWithCharacters (kCFAllocatorDefault, (unichar *)contentLen, strlen(contentLen));
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
    if([closeFTCClientTimer userInfo] == sock){
        [closeFTCClientTimer invalidate];
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
}

- (void)onSocket:(AsyncSocket *)sock didWriteDataWithTag:(long)tag
{
    NSLog(@"Send complete!");
}

- (void)closeClient:(NSTimer *)timer
{
    [(AsyncSocket *)[timer userInfo] disconnect];
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
