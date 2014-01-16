//
//  EASYLINK.m
//  EasyLink
//
//  Created by William Xu on 13-7-24.
//  Copyright (c) 2013年 MXCHIP. All rights reserved.
//

#import "EASYLINK.h"

@implementation EASYLINK
@synthesize array;
@synthesize socket;
@synthesize sendInterval;

- (void)setSettingsWithSsid:(NSString *)bSSID password:(NSString *)bpasswd version: (NSUInteger)ver{

    self.sendInterval = nil;
    
    if (bSSID == nil) bSSID = @"";
    if (bpasswd == nil) bpasswd = @"";
    
    self.array = [NSMutableArray array];
    NSString *mergeString =  [bSSID stringByAppendingString:bpasswd];
    const NSUInteger headerLength = 20;
    const NSUInteger dataBaseLength = 20;
    
    // 239.0x76.0.0
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

- (void)transmitSettings
{
    self.sendInterval = [NSTimer scheduledTimerWithTimeInterval:0.01 target:self selector:@selector(startConfigure:) userInfo:nil repeats:YES];
}

- (void)stopTransmitting
{
    if(self.sendInterval != nil){
        [self.sendInterval invalidate];
        self.sendInterval = nil;
    }
}


- (void)startConfigure:(id)sender{
    static NSUInteger count = 0;
    if (count == [self.array count]) count = 0;
    
    self.socket = [[AsyncUdpSocket alloc] initWithDelegate:nil] ;
    NSError *error;
    [self.socket enableBroadcast:YES error:&error];
    [self.socket sendData:[[self.array objectAtIndex:count] objectForKey:@"sendData"] toHost:[[self.array objectAtIndex:count] objectForKey:@"host"] port:8080 withTimeout:10 tag:0];
    
    ++count;
}

/*!!!!!!!!!!!!
 retriving the SSID of the connected network
 @return value: the SSID of currently connected wifi
 '!!!!!!!!!!*/
- (NSString*)ssidForConnectedNetwork{
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
- (NSString *)getGatewayAddress {
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
                }
            }
            temp_addr = temp_addr->ifa_next;
        }
    }
    // Free/release memory
    freeifaddrs(interfaces);
    return address;
}

//- (void)dealloc
//{
//    [self stopTransmitting];
//}

@end
