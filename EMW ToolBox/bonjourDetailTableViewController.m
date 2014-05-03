//
//  bonjourDetailTableViewController.m
//  MICO
//
//  Created by William Xu on 14-4-30.
//  Copyright (c) 2014年 MXCHIP Co;Ltd. All rights reserved.
//

#import "bonjourDetailTableViewController.h"
#import <sys/socket.h>
#import <netinet/in.h>
#include <arpa/inet.h>


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



@interface bonjourDetailTableViewController ()

@end

@implementation bonjourDetailTableViewController
@synthesize service = _service;

- (id)initWithStyle:(UITableViewStyle)style
{
    self = [super initWithStyle:style];
    if (self) {
        // Custom initialization
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    // Uncomment the following line to preserve selection between presentations.
    // self.clearsSelectionOnViewWillAppear = NO;
    
    // Uncomment the following line to display an Edit button in the navigation bar for this view controller.
    // self.navigationItem.rightBarButt onItem = self.editButtonItem;
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)setService:(NSNetService *)newService
{
    if (_service != newService) {
        _service = newService;
        
        // Update the view.
        self.navigationItem.title = @"Bonjour";
    
        _txtRecordArray = [NSMutableArray arrayWithCapacity:20];
        _txtRecord = [NSNetService dictionaryFromTXTRecordData: [newService TXTRecordData]];
        [_txtRecord enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
            //if(obj isKindOfClass:[NSString class])
            NSString *content = [[NSString alloc]initWithData:obj encoding:NSUTF8StringEncoding];
            NSDictionary *dict = [NSDictionary dictionaryWithObject:content forKey:key];
            [_txtRecordArray addObject: dict];
        }];
        
         _majourInfo = [NSMutableArray arrayWithCapacity:20];
        [_majourInfo addObject: [NSDictionary dictionaryWithObject:[newService type] forKey:@"Service"] ];
        [_majourInfo addObject: [NSDictionary dictionaryWithObject:[[[newService addresses] objectAtIndex: 0] host] forKey:@"IP address"] ];
        [_majourInfo addObject: [NSDictionary dictionaryWithObject:[[NSNumber numberWithInteger:[newService port]] stringValue] forKey:@"Port"] ];
        _name = [newService name];
        //[_majourInfo addObject:[newService name]];
        
        [bonjourDetailTable reloadData];
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
    if(section == 0)
      return [_majourInfo count];
    else
      return [_txtRecordArray count];
}


- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    UITableViewCell *cell;
    NSDictionary *dict;
    NSUInteger section = [indexPath indexAtPosition:0];
    NSUInteger row = [indexPath indexAtPosition:1];

    if(section == 0){
        dict = [_majourInfo objectAtIndex:row];
        cell = [tableView dequeueReusableCellWithIdentifier:@"Major info" forIndexPath:indexPath];
    }
    else{
        dict = [_txtRecordArray objectAtIndex:row];
        cell = [tableView dequeueReusableCellWithIdentifier:@"Txt record" forIndexPath:indexPath];
    }
    
    NSEnumerator *enumerator = [dict keyEnumerator];
    id key = [enumerator nextObject];
    cell.textLabel.text = key;
    cell.detailTextLabel.text = [dict objectForKey:key];
    
    return cell;
}

//- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section
//{
//    
//}
- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    if([indexPath indexAtPosition:0] == 0)
        return 40.0;
    else
        return 30.0;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
    if(section == 0)
        return _name;
    else
        return @"TXT record";
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
