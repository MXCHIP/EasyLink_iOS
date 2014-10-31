//
//  easyLinkIpConfigTableViewController.m
//  MICO
//
//  Created by William Xu on 14-4-20.
//  Copyright (c) 2014年 MXCHIP Co;Ltd. All rights reserved.
//

#import "easyLinkIpConfigTableViewController.h"
#import "EMWHeader.h"
#import "EASYLINK.h"

#import <UIKit/UIKit.h>
#include <sys/socket.h>
#include <netdb.h>
#include <AssertMacros.h>
#import <CFNetwork/CFNetwork.h>
#include <netinet/in.h>
#include <errno.h>
#include <ifaddrs.h>
#include <arpa/inet.h>

@interface easyLinkIpConfigTableViewController ()
- (void)switchChanged: (UISwitch *)switcher;
- (UITextField *)prepareTextField;

@end

@implementation easyLinkIpConfigTableViewController
@synthesize deviceIPConfig = _deviceIPConfig;

- (id)initWithStyle:(UITableViewStyle)style
{
    self = [super initWithStyle:style];
    if (self) {
        [self.navigationController.navigationBar setDelegate:self];
        // Custom initialization
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    //self.firmwareList = [NSArray arrayWithObject:<#(id)#>
    
    // Uncomment the following line to preserve selection between presentations.
    // self.clearsSelectionOnViewWillAppear = NO;
    
    // Uncomment the following line to display an Edit button in the navigation bar for this view controller.
    // self.navigationItem.rightBarButtonItem = self.editButtonItem;
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)setDeviceIPConfig:(NSMutableDictionary *)newDeviceIPConfig
{
    if (_deviceIPConfig != newDeviceIPConfig) {
        _deviceIPConfig = newDeviceIPConfig;
        dhcp = [[self.deviceIPConfig objectForKey:@"DHCP"] boolValue];
    }
}


#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    // Return the number of sections.
    return 2;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    // Return the number of rows in the section.
    if(dhcp == YES || section == 1)
        return 1;
    else
        return 5;
}


- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    NSUInteger sectionRow = [ indexPath indexAtPosition: 0 ];
    NSArray *identifierArray = [NSArray arrayWithObjects:@"DHCP", @"IP", @"NetMask", @"GateWay", @"DnsServer", nil];
    
    UITableViewCell *cell;

    if(sectionRow == 0){
        cell = (UITableViewCell *)[tableView dequeueReusableCellWithIdentifier:[identifierArray objectAtIndex:indexPath.row]];
        if ( cell == nil ) {
            cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:[identifierArray objectAtIndex:indexPath.row]];
            cell.selectionStyle = UITableViewCellSelectionStyleNone;
        }
        switch(indexPath.row){
            case DHCP_ROW:
                if(dhcpSwitch == nil){
                    dhcpSwitch = [[UISwitch alloc] initWithFrame:CGRectMake(CELL_IPHONE_SWITCH_X,
                                                                            CELL_iPHONE_SWITCH_Y,
                                                                            CELL_iPHONE_SWITCH_WIDTH,
                                                                            CELL_iPHONE_SWITCH_HEIGHT)];
                    [dhcpSwitch addTarget:self action:@selector(switchChanged:) forControlEvents:UIControlEventValueChanged];
                    [cell addSubview:dhcpSwitch];
                }
                dhcpSwitch.on = dhcp;
                cell.textLabel.font = [UIFont boldSystemFontOfSize:17.0];
                cell.textLabel.text = @"Automatically";
                break;
            case LOCAL_IP_ROW:
                if(ipAddressField == nil){
                    ipAddressField = [self prepareTextField];
                    [cell addSubview:ipAddressField];
                }
                
                [ipAddressField setText:[self.deviceIPConfig objectForKey:@"IP"]];
                
                cell.textLabel.font = [UIFont boldSystemFontOfSize:17.0];
                cell.textLabel.text = @"IP Address";
                break;
            case NETMASK_ROW:
                if(netMaskField == nil){
                    netMaskField = [self prepareTextField];
                    [cell addSubview:netMaskField];
                }
                
                
                [netMaskField setText:[self.deviceIPConfig objectForKey:@"NetMask"]];
                
                cell.textLabel.font = [UIFont boldSystemFontOfSize:17.0];
                cell.textLabel.text = @"Subnet Mask";
                break;
            case GATEWAY_ROW:
                if(gatewayField == nil){
                    gatewayField = [self prepareTextField];
                    [cell addSubview:gatewayField];
                }
                
                [gatewayField setText:[self.deviceIPConfig objectForKey:@"GateWay"]];
                cell.textLabel.font = [UIFont boldSystemFontOfSize:17.0];
                cell.textLabel.text = @"Router";

                break;
            case DNS_ROW:
                if(dnsServerField == nil){
                    dnsServerField = [self prepareTextField];
                    [cell addSubview:dnsServerField];
                }
                
                [dnsServerField setText:[self.deviceIPConfig objectForKey:@"DnsServer"]];
                cell.textLabel.font = [UIFont boldSystemFontOfSize:17.0];
                cell.textLabel.text = @"DNS";

                break;
                
        }
    }else{
        cell = (UITableViewCell *)[tableView dequeueReusableCellWithIdentifier:@"OK"];
    }
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    UIAlertView *alertView;
    in_addr_t ip, netmask,gateway,dns;
    NSUInteger sectionRow = [ indexPath indexAtPosition: 0 ];

    if(sectionRow == 0)
        return;
    
    [self.deviceIPConfig setObject:[NSNumber numberWithBool: dhcpSwitch.on] forKey:@"DHCP"];
    if(dhcp == NO){
        if([ipAddressField.text isEqualToString:[EASYLINK getIPAddress]]){
            alertView = [[UIAlertView alloc] initWithTitle:@"IP address is in use" message:@"Device IP address should be unique in the local network! Pleae recheck your input." delegate:Nil cancelButtonTitle:@"OK" otherButtonTitles: nil];
            [alertView show];
            [ipConfigTable deselectRowAtIndexPath:indexPath animated:YES];
            return;
        };
        
        ip = [ipAddressField.text length]==0? 0:inet_addr([ipAddressField.text cStringUsingEncoding:NSASCIIStringEncoding]);
        netmask = [netMaskField.text length]==0? 0:inet_addr([netMaskField.text cStringUsingEncoding:NSASCIIStringEncoding]);
        gateway = [gatewayField.text length]==0? 0:inet_addr([gatewayField.text cStringUsingEncoding:NSASCIIStringEncoding]);
        dns = [dnsServerField.text length]==0? 0:inet_addr([dnsServerField.text cStringUsingEncoding:NSASCIIStringEncoding]);
        
        if( ip == -1||netmask == -1||gateway == -1||dns == -1 ){
            alertView = [[UIAlertView alloc] initWithTitle:@"Illegal IP address format" message:@"Pleae recheck your input." delegate:Nil cancelButtonTitle:@"OK" otherButtonTitles: nil];
            [alertView show];
            [ipConfigTable deselectRowAtIndexPath:indexPath animated:YES];
            return;
        };
        
        if(ipAddressField.text!=nil)
            [self.deviceIPConfig setObject:ipAddressField.text forKey:@"IP"];
        if(netMaskField.text!=nil)
            [self.deviceIPConfig setObject:netMaskField.text forKey:@"NetMask"];
        if(gatewayField.text!=nil)
            [self.deviceIPConfig setObject:gatewayField.text forKey:@"GateWay"];
        if(dnsServerField.text!=nil)
            [self.deviceIPConfig setObject:dnsServerField.text forKey:@"DnsServer"];
    }
    
    [self.navigationController popViewControllerAnimated:YES];
}




- (UITextField *)prepareTextField
{
    UITextField *textField = [[UITextField alloc] initWithFrame:CGRectMake(CELL_IPHONE_FIELD_X,
                                                                 CELL_iPHONE_FIELD_Y,
                                                                 CELL_iPHONE_FIELD_WIDTH,
                                                                 CELL_iPHONE_FIELD_HEIGHT)];
    [textField setDelegate:self];
    [textField setClearButtonMode:UITextFieldViewModeNever];
    
    [textField setTextAlignment:NSTextAlignmentRight];
    [textField setReturnKeyType:UIReturnKeyDone];
    [textField setAutocapitalizationType:UITextAutocapitalizationTypeNone];
    [textField setAutocorrectionType:UITextAutocorrectionTypeNo];
    [textField setBackgroundColor:[UIColor clearColor]];
    textField.keyboardType = UIKeyboardTypeDecimalPad;
    return textField;
}

- (void)switchChanged: (UISwitch *)switcher
{
    NSLog(@"Value changed!");
    NSArray *indexPathArray = [NSArray arrayWithObjects:[NSIndexPath indexPathForRow:1 inSection:0],
                                                        [NSIndexPath indexPathForRow:2 inSection:0],
                                                        [NSIndexPath indexPathForRow:3 inSection:0],
                                                        [NSIndexPath indexPathForRow:4 inSection:0], nil];
    if(dhcpSwitch.on == YES){
        dhcp = YES;
        if([ipConfigTable numberOfRowsInSection:0]==5)
            [ipConfigTable deleteRowsAtIndexPaths:indexPathArray withRowAnimation:UITableViewRowAnimationTop];
    }else{
        dhcp = NO;
        if([ipConfigTable numberOfRowsInSection:0]==1)
            [ipConfigTable insertRowsAtIndexPaths:indexPathArray withRowAnimation:UITableViewRowAnimationTop];
    }
}

#pragma mark - UITextfiled delegate -

- (BOOL)textFieldShouldReturn:(UITextField *)textField
{
    [textField resignFirstResponder];
    return YES;
}

- (void)textFieldDidBeginEditing:(UITextField *)textField{
    double delayInMSeconds = 100.0;
    dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, delayInMSeconds * NSEC_PER_MSEC);
    dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
        [ ipConfigTable scrollToRowAtIndexPath:[NSIndexPath indexPathForRow:0 inSection:1]
                              atScrollPosition:UITableViewScrollPositionTop
                                      animated:YES];
    });
}

/*
// Override to support conditional editing of the table view.
- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath
{
    // Return NO if you do not want the specified item to be editable.
    return YES;
}
*/

/*
// Override to support editing the table view.
- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (editingStyle == UITableViewCellEditingStyleDelete) {
        // Delete the row from the data source
        [tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationFade];
    } else if (editingStyle == UITableViewCellEditingStyleInsert) {
        // Create a new instance of the appropriate class, insert it into the array, and add a new row to the table view
    }   
}
*/

/*
// Override to support rearranging the table view.
- (void)tableView:(UITableView *)tableView moveRowAtIndexPath:(NSIndexPath *)fromIndexPath toIndexPath:(NSIndexPath *)toIndexPath
{
}
*/

/*
// Override to support conditional rearranging of the table view.
- (BOOL)tableView:(UITableView *)tableView canMoveRowAtIndexPath:(NSIndexPath *)indexPath
{
    // Return NO if you do not want the item to be re-orderable.
    return YES;
}
*/

/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/

@end
