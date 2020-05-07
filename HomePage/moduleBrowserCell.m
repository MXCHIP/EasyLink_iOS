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
    CGRect cellFrame = self.contentView.frame;
    CGRect frame = CGRectMake(283, (cellFrame.size.height)/2-32, 25, 25);
    checkMarkView = [[UIView alloc] initWithFrame:frame];
    [self.contentView addSubview:checkMarkView];
    [super awakeFromNib];
}

- (void)closeClient:(NSTimer *)timer
{
    //[self setSelected:NO animated:(BOOL)YES];
    //self.accessoryView = nil;
}

- (void)setSelected:(BOOL)selected animated:(BOOL)animated
{
    if(selected==YES){
        NSLog(@"selected");
    }else{
        NSLog(@"unselected");
    }
    [super setSelected:selected animated:animated];

    // Configure the view for the selected state
}

- (void)setModuleService:(NSDictionary *)newModuleService {
	_moduleService = newModuleService;
    
    NSString *serviceName, *hostName, *macAddress, *module;
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
    NSData *hd = [[NSNetService dictionaryFromTXTRecordData:[service TXTRecordData]] objectForKey:@"Model"];
    module = [[NSString alloc] initWithData: hd encoding:NSASCIIStringEncoding];
    
    if (resolving == YES){
        self.imageView.image = [UIImage imageNamed:@"known_logo.png"];
    }
    else{
        self.imageView.image = [UIImage imageNamed:[NSString stringWithFormat:@"%@.png", module]];
        if(self.imageView.image==nil)
            self.imageView.image = [UIImage imageNamed:@"known_logo.png"];
    }
    
    self.imageView.contentMode = UIViewContentModeScaleAspectFit;
    
    NSRange range = [serviceName rangeOfCharacterFromSet:[NSCharacterSet characterSetWithCharactersInString:@"#"]
                                                 options:NSBackwardsSearch];
    
    if(range.location == NSNotFound)
        range.length = [serviceName length];
    else
        range.length = range.location;
    range.location = 0;
    displayServiceName = [serviceName substringWithRange:range];
    self.textLabel.backgroundColor = [UIColor clearColor];
    self.textLabel.text = displayServiceName;
    self.textLabel.textColor = [UIColor blackColor];
    if([[service addresses] count])
        ipAddress = [[service addresses] objectAtIndex:0];
    
    NSString *detailString = [[NSString alloc] initWithFormat:
                              @"MAC: %@\nIP :%@",
                              macAddress,
                              (ipAddress!=nil)? [ipAddress host]:@"Unknow"];
    
    self.detailTextLabel.backgroundColor = [UIColor clearColor];
    self.detailTextLabel.text = detailString;
    
    //[self startCheckIndicator:YES];
    self.accessoryType = UITableViewCellAccessoryDetailButton;
    //[self startActivityIndicator: YES];
}

- (void)startActivityIndicator: (BOOL) enable
{
    for(UIView *subview in [checkMarkView subviews])
        [subview removeFromSuperview];
    
    if(enable == YES){
        CGRect frame = CGRectMake(0.0, 0.0, kProgressIndicatorSize, kProgressIndicatorSize);
        UIActivityIndicatorView* spinner = [[UIActivityIndicatorView alloc] initWithFrame:frame];
        [spinner setBackgroundColor:[UIColor whiteColor]];
        [spinner startAnimating];
        spinner.activityIndicatorViewStyle = UIActivityIndicatorViewStyleGray;
        [spinner sizeToFit];
        spinner.autoresizingMask = (UIViewAutoresizingFlexibleLeftMargin |
                                    UIViewAutoresizingFlexibleRightMargin |
                                    UIViewAutoresizingFlexibleTopMargin |
                                    UIViewAutoresizingFlexibleBottomMargin);
        [checkMarkView addSubview:spinner];

    }
}

- (void)startCheckIndicator: (BOOL) enable
{
    for(UIView *subview in [checkMarkView subviews])
        [subview removeFromSuperview];
    
    if(enable == YES){
        CGRect frame = CGRectMake(0.0, 0.0, kProgressIndicatorSize, kProgressIndicatorSize);
        UIActivityIndicatorView* spinner = [[UIActivityIndicatorView alloc] initWithFrame:frame];
        [spinner startAnimating];
        spinner.activityIndicatorViewStyle = UIActivityIndicatorViewStyleGray;
        [spinner sizeToFit];
        spinner.autoresizingMask = (UIViewAutoresizingFlexibleLeftMargin |
                                    UIViewAutoresizingFlexibleRightMargin |
                                    UIViewAutoresizingFlexibleTopMargin |
                                    UIViewAutoresizingFlexibleBottomMargin);
        [checkMarkView addSubview:spinner];
    }
}



@end
