//
//  EASYLINK.m
//  EasyLink
//
//  Created by William Xu on 13-7-24.
//  Copyright (c) 2013年 MXCHIP. All rights reserved.
//

#import "EASYLINK.h"
//#import "route.h"
#import "sys/sysctl.h"


static NSUInteger count = 0;

@interface EASYLINK (privates)
- (void)initEasylinkV1:(NSString *)bSSID password:(NSString *)bpasswd;
- (void)initEasylinkV2:(NSString *)bSSID password:(NSString *)bpasswd;
@end

@implementation EASYLINK
@synthesize array;
@synthesize socket;

-(id)init{
    self.array = [NSMutableArray array];
    self.socket = [[AsyncUdpSocket alloc] initWithDelegate:nil];
    sendInterval = nil;
    return [super init];
}

- (void)initEasylinkV1:(NSString *)bSSID password:(NSString *)bpasswd{
    if (bSSID == nil) bSSID = @"";
    if (bpasswd == nil) bpasswd = @"";
    
    char tempData[128], PD;
    NSUInteger sendData;
    
    //NSString *mergeString =  [bSSID stringByAppendingString:bpasswd];
    const NSUInteger header1 = 3;
    const NSUInteger header2 = 23;
    NSUInteger bSSIDLength = [bSSID length];
    NSUInteger bpasswdLength = [bpasswd length];
    
    [self.array removeAllObjects];
    for (NSUInteger idx = 0; idx != 10; ++idx) {
        [self.array addObject:[NSMutableData dataWithLength:header1]];
        [self.array addObject:[NSMutableData dataWithLength:header2]];
    }
    
    [self.array addObject:[NSMutableData dataWithLength:1399]];
    [self.array addObject:[NSMutableData dataWithLength:(28+bSSIDLength)]];
    
    for (NSUInteger idx = 0; idx != bSSIDLength; ++idx) {
        tempData[idx*2] = ([bSSID characterAtIndex:idx]&0xF0)>>4;
        tempData[idx*2+1] = [bSSID characterAtIndex:idx]&0xF;
    }
    
    //ND= ((PD^CP)&0xF<<4)|CD+0x251
    for (NSUInteger idx = 0; idx != bSSIDLength*2; ++idx) {
        PD = (idx == 0)? 0x0:tempData[idx-1];
        sendData = 0x251 + ((((PD^idx)&0xF)<<4)|tempData[idx]);
        [self.array addObject:[NSMutableData dataWithLength:sendData]];
    }
    
    [self.array addObject:[NSMutableData dataWithLength:1459]];
    [self.array addObject:[NSMutableData dataWithLength:(28+bpasswdLength)]];
    
    for (NSUInteger idx = 0; idx != bpasswdLength; ++idx) {
        tempData[idx*2] = ([bpasswd characterAtIndex:idx]&0xF0)>>4;
        tempData[idx*2+1] = [bpasswd characterAtIndex:idx]&0xF;
    }
    
    //ND= ((PD^CP)&0xF<<4)|CD+0x251
    for (NSUInteger idx = 0; idx != bpasswdLength*2; ++idx) {
        PD = (idx == 0)? 0x0:tempData[idx-1];
        sendData = 0x251 + ((((PD^idx)&0xF)<<4)|tempData[idx]);
        [self.array addObject:[NSMutableData dataWithLength:sendData]];
    }
}

- (void)initEasylinkV2:(NSString *)bSSID password:(NSString *)bpasswd{
    if (bSSID == nil) bSSID = @"";
    if (bpasswd == nil) bpasswd = @"";
    
    
    NSString *mergeString =  [bSSID stringByAppendingString:bpasswd];
    const NSUInteger headerLength = 20;
    const NSUInteger dataBaseLength = 20;
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
    [dictionary setValue:[NSString stringWithFormat:@"239.126.%d.%d", [bSSID length], [bpasswd length]] forKey:@"host"];
    [self.array addObject:dictionary];
    
    // 239.126.mergeString[idx],mergeString[idx+1]
    for (NSUInteger idx = 0; idx < [mergeString length]; idx += 2) {
        unichar a = [mergeString characterAtIndex:idx];
        unichar b = 0;
        if (idx + 1 != [mergeString length])
            b = [mergeString characterAtIndex:idx + 1];
        
        NSDictionary *dictionary = [NSMutableDictionary dictionary];
        [dictionary setValue:[NSMutableData dataWithLength:dataBaseLength + idx / 2 + 1] forKey:@"sendData"];
        [dictionary setValue:[NSString stringWithFormat:@"239.126.%d.%d", a, b] forKey:@"host"];
        [self.array addObject:dictionary];
    }
}



- (void)setSettingsWithSsid:(NSString *)bSSID password:(NSString *)bpasswd version: (NSUInteger)ver{
    switch (ver) {
        case EASYLINK_V1:
            version = EASYLINK_V1;
            [self initEasylinkV1:bSSID password:bpasswd];
            break;
        case EASYLINK_V2:
            version = EASYLINK_V2;
            [self initEasylinkV2:bSSID password:bpasswd];
            break;
        default:
            version = EASYLINK_V2;
            [self initEasylinkV2:bSSID password:bpasswd];
            break;
    }
}

- (void)transmitSettings
{
    NSTimeInterval delay = 0.01;
    [self stopTransmitting];
    if(version == EASYLINK_V1)
        delay = 0.005;
    
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
        NSLog(@"Send data %@, length %d", [[self.array objectAtIndex:count] objectForKey:@"host"],[[[self.array objectAtIndex:count] objectForKey:@"sendData"] length] );
        [self.socket sendData:[[self.array objectAtIndex:count] objectForKey:@"sendData"] toHost:[[self.array objectAtIndex:count] objectForKey:@"host"] port:65523 withTimeout:10 tag:0];
        ++count;
        if (count == [self.array count]) count = 0;
    }
    else if (version==EASYLINK_V1){
        NSString *host=[EASYLINK getGatewayAddress];
        NSLog(@"Send data %@, length %d", host, [[self.array objectAtIndex:count] length]);
        [self.socket sendData:[self.array objectAtIndex:count] toHost:host port:65523 withTimeout:10 tag:0];
        ++count;
        if (count == [self.array count]) count = 0;
    }
}

/*!!!!!!!!!!!!
 retriving the SSID of the connected network
 @return value: the SSID of currently connected wifi
 '!!!!!!!!!!*/
+ (NSString*)ssidForConnectedNetwork{
    NSArray *interfaces = (__bridge NSArray*)CNCopySupportedInterfaces();
    NSDictionary *info = nil;
    for (NSString *ifname in interfaces) {
        info = (__bridge NSDictionary*)CNCopyCurrentNetworkInfo((__bridge CFStringRef)ifname);
        if (info && [info count]) {
            break;
        }
        info = nil;
    }
    
    NSLog(@"SSID == %@  info === %@",[info objectForKey:@"SSID"],info);
    
    NSString *ssid = nil;
    if ( info ){
        ssid = [info objectForKey:@"SSID"];
    }
    return ssid? ssid:@"";
}

/*!!!!!!!!!!!!!
 retrieving the IP Address from the connected WiFi
 @return value: the wifi address of currently connected wifi
 */
//- (NSString *)getGatewayAddress {
//    NSString *address = @"";
//    struct ifaddrs *interfaces = NULL;
//    struct ifaddrs *temp_addr = NULL;
//    int success = 0;
//    // retrieve the current interfaces - returns 0 on success
//    success = getifaddrs(&interfaces);
//    if (success == 0) {
//        // Loop through linked list of interfaces
//        temp_addr = interfaces;
//        while(temp_addr != NULL) {
//            if(temp_addr->ifa_addr->sa_family == AF_INET) {
//                // Check if interface is en0 which is the wifi connection on the iPhone
//                if([[NSString stringWithUTF8String:temp_addr->ifa_name] isEqualToString:@"en0"]) {
//                    // Get NSString from C String for IP
//                    address = [NSString stringWithUTF8String:inet_ntoa(((struct sockaddr_in *)temp_addr->ifa_dstaddr)->sin_addr)];
//                }
//            }
//            temp_addr = temp_addr->ifa_next;
//        }
//    }
//    // Free/release memory
//    freeifaddrs(interfaces);
//    return address;
//}

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
