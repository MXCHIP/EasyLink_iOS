//
//  bonjourDetailTableViewController.m
//  MICO
//
//  Created by William Xu on 14-4-30.
//  Copyright (c) 2014年 MXCHIP Co;Ltd. All rights reserved.
//

#import "bonjourDetailTableViewController.h"
#import "EasyLinkFTCTableViewController.h"
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

-(void)showConnectingAlert;

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

- (void)dealloc
{
    CFRelease(inComingMessage);
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
            NSString *content = [[NSString alloc]initWithData:obj encoding:NSUTF8StringEncoding];
            NSDictionary *dict = [NSDictionary dictionaryWithObject:content forKey:key];
            [_txtRecordArray addObject: dict];
        }];
        
         _majourInfo = [NSMutableArray arrayWithCapacity:20];
        [_majourInfo addObject: [NSDictionary dictionaryWithObject:[newService type] forKey:@"Service"] ];
        _address = [[[newService addresses] objectAtIndex: 0] host];
        [_majourInfo addObject: [NSDictionary dictionaryWithObject:_address forKey:@"IP address"] ];
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

- (IBAction)edit:(UIBarButtonItem *)sender
{
    
    NSError *err;
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    configSocket = [[AsyncSocket alloc] initWithDelegate:self];
    
    inComingMessage = CFHTTPMessageCreateEmpty(kCFAllocatorDefault, TRUE);
    [configSocket connectToHost:_address onPort:8000 withTimeout:4.0 error:&err];
    [self showConnectingAlert];
        
    //[self performSegueWithIdentifier:@"Configuration" sender:sender];
}


#pragma mark - AsyncSocket delegate

- (void)onSocket:(AsyncSocket *)sock didConnectToHost:(NSString *)host port:(UInt16)port
{
    NSLog(@"connected");
    if(customAlertView){
        [customAlertView close];
        customAlertView = nil;
    }
    
    [sock readDataWithTimeout:-1 tag:0];
    
}

- (void)onSocket:(AsyncSocket *)sock didReadData:(NSData *)data withTag:(long)tag
{
    //CFHTTPMessageRef httpRespondMessage;
    NSError *err;
    UIAlertView *alertView;
    NSMutableDictionary *updateSettings;
    NSUInteger contentLength, currentLength;
    
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
        
        configData = [NSJSONSerialization JSONObjectWithData:body
                                                      options:NSJSONReadingMutableContainers|NSJSONReadingMutableLeaves
                                                        error:&err];
        NSLog(@"Recv JSON data, length: %lu", (unsigned long)[body length]);
        
        if (err) {
            NSString *temp = [[NSString alloc] initWithData:body encoding:NSASCIIStringEncoding];
            NSLog(@"Unpackage JSON data failed:%@, %@", [err localizedDescription], temp);
            alertView = [[UIAlertView alloc] initWithTitle:@"Get unrecognized data!" message:nil delegate:Nil cancelButtonTitle:@"OK" otherButtonTitles: nil];
            [alertView show];
            return;
        }
        
        [configData setValue:[NSNumber numberWithInteger:0] forKey:@"client"];
        updateSettings = [NSMutableDictionary dictionaryWithCapacity:10];
        [configData setValue:updateSettings forKey:@"update"];
        [self performSegueWithIdentifier:@"Configuration" sender:nil];
        
//        httpRespondMessage = CFHTTPMessageCreateResponse ( kCFAllocatorDefault, 202, NULL, kCFHTTPVersion1_1 );
//        CFDataRef httpData = CFHTTPMessageCopySerializedMessage ( httpRespondMessage );
//        [sock writeData:(__bridge_transfer NSData*)httpData withTimeout:20 tag:[[client objectForKey:@"Tag"] longValue]];
//        if([theDelegate respondsToSelector:@selector(onFoundByFTC: currentConfig:)])
//            [theDelegate onFoundByFTC:[NSNumber numberWithLong:tag] currentConfig: body];
    }
    else{
        [configSocket disconnect];
        alertView = [[UIAlertView alloc] initWithTitle:@"Get unrecognized data!" message:nil delegate:Nil cancelButtonTitle:@"OK" otherButtonTitles: nil];
        [alertView show];
    }
    
    /*Recv data that server can send FIN+ACK when client disconnect*/
    [sock readDataWithTimeout:-1 tag:(long)tag];
    
}

- (void)onSocket:(AsyncSocket *)sock willDisconnectWithError:(NSError *)err
{
    if(customAlertView){
        [customAlertView close];
        customAlertView = nil;
        UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:@"Connect to module failed." message:nil delegate:Nil cancelButtonTitle:@"OK" otherButtonTitles: nil];
        [alertView show];
    }
}

- (void)onSocketDidDisconnect:(AsyncSocket *)sock
{
    NSError *err;
    NSLog(@"disconnected");
    if(inComingMessage) CFRelease(inComingMessage);
    
    //if(isInforground == YES)
    //    [socket connectToHost:_address onPort:_port error:&err];
}

-(void)showConnectingAlert
{
    customAlertView = [[CustomIOS7AlertView alloc] init];
    NSString *alertContent = [NSString stringWithFormat:@"Connecting to %@ on port 8000 ...", _address];
    
    UIView *alertContentView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 290, 170)];
    
    UILabel *title = [[UILabel alloc] initWithFrame:CGRectMake(alertContentView.frame.size.width/2-130, 20, 260, 25)];
    title.text = @"Please wait...";
    title.font= [UIFont boldSystemFontOfSize:19.0];
    title.textAlignment = NSTextAlignmentCenter;
    [alertContentView addSubview:title];
    
    UILabel *content = [[UILabel alloc] initWithFrame:CGRectMake(alertContentView.frame.size.width/2-130, 50, 260, 50)];
    
    NSMutableParagraphStyle *paragraphStyle = [[NSMutableParagraphStyle alloc] init];
    paragraphStyle.lineBreakMode = NSLineBreakByCharWrapping;
    paragraphStyle.alignment = NSTextAlignmentCenter;
    paragraphStyle.lineSpacing = 5.0f;
    NSDictionary *attributes = [NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:paragraphStyle,
                                                                    nil]
                                                           forKeys:[NSArray arrayWithObjects:NSParagraphStyleAttributeName,
                                                                    nil]];
    NSAttributedString *contentText =  [[NSAttributedString alloc] initWithString:alertContent
                                                                       attributes:attributes];
    
    content.attributedText = contentText;
    content.numberOfLines = 2;
    [alertContentView addSubview:content];
    
    CGRect frame = CGRectMake(0, 0, 50, 50);
    UIActivityIndicatorView* spinner = [[UIActivityIndicatorView alloc] initWithFrame:frame];
    [spinner startAnimating];
    spinner.activityIndicatorViewStyle = UIActivityIndicatorViewStyleWhiteLarge;
    [spinner sizeToFit];
    [spinner setColor: [UIColor colorWithRed:0 green:122.0/255 blue:1 alpha:1]];
    spinner.frame = CGRectMake(alertContentView.frame.size.width/2-17, 110, 50, 50);
    [alertContentView addSubview:spinner];
    [customAlertView setContainerView:alertContentView];
    
    [customAlertView setButtonTitles:[NSMutableArray arrayWithObjects:@"Cancel",nil]];
    __weak AsyncSocket *_tempsocket = configSocket;
    [customAlertView setOnButtonTouchUpInside:^(CustomIOS7AlertView *alertView, NSInteger buttonIndex) {
        [_tempsocket disconnect];
        NSLog(@"Block: Button at position %ld is clicked on alertView %ld.", (long)buttonIndex, (long)[alertView tag]);
        [alertView close];
    }];
    
    [customAlertView setUseMotionEffects:true];
    [customAlertView show];
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


#pragma mark - Navigation

 - (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
 {
     if ([[segue identifier] isEqualToString:@"Configuration"]) {
 
        [[segue destinationViewController] setConfigData:configData];
         [[segue destinationViewController] setDelegate:self];
     }
 }

@end
