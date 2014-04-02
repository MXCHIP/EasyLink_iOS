//
//  moduleBrowserCell.m
//  EasyLink
//
//  Created by William Xu on 14-4-2.
//  Copyright (c) 2014年 MXCHIP Co;Ltd. All rights reserved.
//

#import "moduleBrowserCell.h"
#import <sys/socket.h>
#import <netinet/in.h>
#include <arpa/inet.h>
#import "AsyncSocket.h"

#define kProgressIndicatorSize 20.0

@implementation NSData (Additions)
- (NSString *)host
{
    struct sockaddr *addr = (struct sockaddr *)[self bytes];
    if(addr->sa_family == AF_INET) {
        char *address = inet_ntoa(((struct sockaddr_in *)addr)->sin_addr);
        if (address)
            return [NSString stringWithCString: address encoding: NSASCIIStringEncoding];
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

@implementation moduleBrowserCell
@synthesize moduleService = _moduleService;

- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier
{
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
        // Initialization code
    }
    return self;
}

- (void)awakeFromNib
{
    // Initialization code
}

- (void)setSelected:(BOOL)selected animated:(BOOL)animated
{
    [super setSelected:selected animated:animated];

    // Configure the view for the selected state
}

- (void)setModuleService:(NSMutableDictionary *)newModuleService {
	_moduleService = newModuleService;
    
    NSString *serviceName, *hostName, *macAddress, *hardware;
    NSNetService *service;
    BOOL resolving;
    NSString *displayServiceName;
    NSData *ipAddress = nil;
    
    // Set up the text for the cell
    serviceName = [_moduleService objectForKey:@"Name"];
    service = [_moduleService objectForKey:@"BonjourService"];
    hostName = [service hostName];
    resolving = [[_moduleService objectForKey:@"resolving"] boolValue];
    NSData *mac = [[NSNetService dictionaryFromTXTRecordData:[service TXTRecordData]] objectForKey:@"MAC"];
    macAddress = [[NSString alloc] initWithData: mac encoding:NSASCIIStringEncoding];
    NSData *hd = [[NSNetService dictionaryFromTXTRecordData:[service TXTRecordData]] objectForKey:@"Hardware"];
    hardware = [[NSString alloc] initWithData: hd encoding:NSASCIIStringEncoding];
    
    if (resolving == YES){
        self.imageView.image = [UIImage imageNamed:@"known_logo.png"];
    }
    else{
        if([hardware isEqualToString:@"EMW3161"])
            self.imageView.image = [UIImage imageNamed:@"EMW3161_logo.png"];
        else if([hardware isEqualToString:@"EMW3280"])
            self.imageView.image = [UIImage imageNamed:@"EMW3280_logo.png"];
        else if([hardware isEqualToString:@"EMW3162"])
            self.imageView.image = [UIImage imageNamed:@"EMW3162_logo.png"];
        else
            self.imageView.image = [UIImage imageNamed:@"known_logo.png"];
    }
    
    NSRange range = [serviceName rangeOfCharacterFromSet:[NSCharacterSet characterSetWithCharactersInString:@"#"]
                                                 options:NSBackwardsSearch];
    if(range.location == NSNotFound)
        range.length = [serviceName length];
    else
        range.length = range.location;
    range.location = 0;
    displayServiceName = [serviceName substringWithRange:range];
    self.textLabel.text = displayServiceName;
    self.textLabel.textColor = [UIColor blackColor];
    if([[[_moduleService objectForKey:@"BonjourService"] addresses] count])
        ipAddress = [[service addresses] objectAtIndex:0];
    
    NSString *detailString = [[NSString alloc] initWithFormat:
                              @"MAC: %@\nIP :%@",
                              macAddress,
                              (ipAddress!=nil)? [ipAddress host]:@"Unknow"];
    
    self.detailTextLabel.text = detailString;
    
    
	if (resolving == NO){
        //cell.accessoryType = UITableViewCellAccessoryCheckmark;
        self.accessoryType = UITableViewCellAccessoryCheckmark;
        if (self.accessoryView) {
            self.accessoryView = nil;
        }
    }
	// Note that the underlying array could have changed, and we want to show the activity indicator on the correct cell
	else{
		if (!self.accessoryView) {
			CGRect frame = CGRectMake(0.0, 0.0, kProgressIndicatorSize, kProgressIndicatorSize);
			UIActivityIndicatorView* spinner = [[UIActivityIndicatorView alloc] initWithFrame:frame];
			[spinner startAnimating];
			spinner.activityIndicatorViewStyle = UIActivityIndicatorViewStyleGray;
			[spinner sizeToFit];
			spinner.autoresizingMask = (UIViewAutoresizingFlexibleLeftMargin |
										UIViewAutoresizingFlexibleRightMargin |
										UIViewAutoresizingFlexibleTopMargin |
										UIViewAutoresizingFlexibleBottomMargin);
			self.accessoryView = spinner;
		}
	}

//    self.textLabel.text = [self.ftcConfig objectForKey:@"N"];
//    self.contentSwitch.on = [[self.ftcConfig valueForKey:@"C"] boolValue];
//    
//    if ([[self.ftcConfig objectForKey:@"P"] isEqualToString:@"RO"]) {
//        [self.contentSwitch setUserInteractionEnabled:NO];
//    }
    
    
}

@end
