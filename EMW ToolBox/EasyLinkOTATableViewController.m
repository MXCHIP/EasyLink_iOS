//
//  EasyLinkOTATableViewController.m
//  MICO
//
//  Created by William Xu on 14-4-15.
//  Copyright (c) 2014年 MXCHIP Co;Ltd. All rights reserved.
//

#import "EasyLinkOTATableViewController.h"
#import "AsyncSocket.h"
#import "EasyLinkMainViewController.h"

@interface EasyLinkOTATableViewController ()

@end

@implementation EasyLinkOTATableViewController
@synthesize protocol;
@synthesize hardwareVersion;
@synthesize firmwareVersion;
@synthesize rfVersion;
@synthesize requestsManager;
@synthesize firmwareListArray;
@synthesize firmwareListCurrentState;
@synthesize client;


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
    
    currentSelectedIndex = -1;
    
    // Uncomment the following line to preserve selection between presentations.
    // self.clearsSelectionOnViewWillAppear = NO;
    
    // Uncomment the following line to display an Edit button in the navigation bar for this view controller.
    // self.navigationItem.rightBarButtonItem = self.editButtonItem;
}

- (id)delegate
{
	return theDelegate;
}

- (void)setDelegate:(id)delegate
{
    theDelegate = delegate;
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];

    NSLog(@"OTA selected");
        
    customAlertView = [[CustomIOS7AlertView alloc] init];
        
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
    NSAttributedString *contentText =  [[NSAttributedString alloc] initWithString:@"Reading available firmwares from MXCHIP OTA center"
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
    [customAlertView setOnButtonTouchUpInside:^(CustomIOS7AlertView *alertView, int buttonIndex) {
        self.requestsManager = nil;
        
        [self.navigationController popToViewController:[self.navigationController.viewControllers objectAtIndex:2] animated:YES];
        NSLog(@"Block: Button at position %d is clicked on alertView %ld.", buttonIndex, (long)[alertView tag]);
        [alertView close];
    }];
    
    [customAlertView setUseMotionEffects:true];
    [customAlertView show];
        
        
    self.requestsManager = [[GRRequestsManager alloc] initWithHostname:@"neooxu88.gicp.net"
                                                                      user:@"OTA_user"
                                                                  password:@"mxchipota"];
    self.requestsManager.delegate = self;
        
    /*OTA path = "/protocol/hardwareversion/*/
    NSString *path = [NSString stringWithFormat:@"/Firmwares/%@/%@/", self.protocol, self.hardwareVersion];
    [self.requestsManager addRequestForListDirectoryAtPath: path];
    [self.requestsManager startProcessingRequests];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
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
        return [self.firmwareListArray count];
    else{
        if(currentSelectedIndex == -1)
            return 0;
        else
            return 1;
    }
}


- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    UITableViewCell *cell;
    NSString *binFile;
    NSUInteger section = [indexPath indexAtPosition:0];
    if(section == 0){
        cell = [tableView dequeueReusableCellWithIdentifier:@"Firmware list" forIndexPath:indexPath];


        binFile = [self.firmwareListArray objectAtIndex:[indexPath indexAtPosition:1]];
        cell.textLabel.text = [binFile substringToIndex: [binFile length]-4];\
        cell.detailTextLabel.text = [firmwareListCurrentState objectAtIndex:[indexPath indexAtPosition:1]];
        
        if( [indexPath indexAtPosition:1] == currentSelectedIndex )
            cell.accessoryType = UITableViewCellAccessoryCheckmark;
        else
            cell.accessoryType = UITableViewCellAccessoryNone;
    }
    else if(section == 1)
        cell = [tableView dequeueReusableCellWithIdentifier:@"update" forIndexPath:indexPath];
    
    // Configure the cell...
    
    return cell;
}


- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    //moduleBrowserCell *cell;
    UITableViewCell *cell;
    NSUInteger section = [indexPath indexAtPosition:0];
    NSUInteger oldSelectedIndex = currentSelectedIndex;
    NSIndexPath *oldSelectedIndexPath = [NSIndexPath indexPathForRow:oldSelectedIndex inSection:0];
    NSIndexPath *updateButtonIndexPath = [NSIndexPath indexPathForRow:0 inSection:1];
    
    if(section == 0){ //Select a same row, just clear the previous status
        if(currentSelectedIndex == indexPath.row){
            [tableView deselectRowAtIndexPath:indexPath animated:NO];
            [firmwareListCurrentState replaceObjectAtIndex:currentSelectedIndex withObject:@""];
            [firmwareListTable reloadRowsAtIndexPaths:[NSArray arrayWithObjects:indexPath,nil] withRowAnimation:UITableViewRowAnimationNone];
            
            return;
        }
        
    currentSelectedIndex = indexPath.row;   
    /*Clear the previous status detail*/
    if(oldSelectedIndex != -1){
        [firmwareListCurrentState replaceObjectAtIndex:oldSelectedIndex withObject:@""];
    }else{ /*Add a update button*/
        [firmwareListTable insertRowsAtIndexPaths:[NSArray arrayWithObjects:updateButtonIndexPath, nil] withRowAnimation:UITableViewRowAnimationTop];
    }
        
    /*Set the current check mark and change the config data*/
    
    cell = [firmwareListTable cellForRowAtIndexPath:indexPath];
    [firmwareListCurrentState replaceObjectAtIndex:currentSelectedIndex withObject:@""];
        
    [firmwareListTable reloadRowsAtIndexPaths:[NSArray arrayWithObjects:indexPath, oldSelectedIndexPath, nil] withRowAnimation:UITableViewRowAnimationNone];
    }
    else{
        NSString *binFile;
        
        NSIndexPath *indexPathOfOTA = [NSIndexPath indexPathForRow:currentSelectedIndex inSection:0];

        cell = [firmwareListTable cellForRowAtIndexPath:indexPathOfOTA];
        [firmwareListCurrentState replaceObjectAtIndex:currentSelectedIndex withObject:@"Downloading"];
        [firmwareListTable reloadRowsAtIndexPaths:[NSArray arrayWithObjects:indexPathOfOTA, nil] withRowAnimation:UITableViewRowAnimationNone];
        binFile = [firmwareListArray objectAtIndex:currentSelectedIndex];
        NSString *remotePath = [NSString stringWithFormat:@"/Firmwares/%@/%@/%@", self.protocol, self.hardwareVersion, binFile];
        
        
        NSArray *cacPath = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES);
        NSString *cachePath = [cacPath objectAtIndex:0];
        localOTAFilePath = [cachePath stringByAppendingPathComponent:binFile];
                
        [self.requestsManager addRequestForDownloadFileAtRemotePath:remotePath
                                                        toLocalPath:localOTAFilePath];
        [self.requestsManager startProcessingRequests];
        
    }
    [tableView deselectRowAtIndexPath:indexPath animated:NO];
    
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

#pragma mark - GRRequestsManagerDelegate
- (void)requestsManager:(id<GRRequestsManagerProtocol>)requestsManager didCompleteListingRequest:(id<GRRequestProtocol>)request listing:(NSArray *)listing
{
    NSUInteger idx = 0;
    NSString *binFile;
    NSLog(@"requestsManager:didCompleteListingRequest:listing: \n%@", listing);
    firmwareListArray = listing;
    firmwareListCurrentState = [NSMutableArray arrayWithCapacity:[firmwareListArray count]];
    for(idx = 0; idx<[firmwareListArray count]; idx++){
        binFile = [self.firmwareListArray objectAtIndex:idx];
        [self.firmwareListCurrentState insertObject:@"" atIndex:idx];
        if([[binFile substringToIndex: [binFile length]-4] isEqualToString:self.firmwareVersion])
            currentSelectedIndex = idx;
    }
    
    [firmwareListTable reloadData];
    [customAlertView close];
    [self.requestsManager stopAndCancelAllRequests];
}

- (void)requestsManager:(id<GRRequestsManagerProtocol>)requestsManager didCompleteDownloadRequest:(id<GRDataExchangeRequestProtocol>)request
{
    NSLog(@"requestsManager:didCompleteDownloadRequest\n%@", request);
    NSIndexPath *indexPath = [NSIndexPath indexPathForRow:currentSelectedIndex inSection:0];

    [firmwareListCurrentState replaceObjectAtIndex:currentSelectedIndex withObject:@"Send to module..."];
    [firmwareListTable reloadRowsAtIndexPaths:[NSArray arrayWithObjects:indexPath, nil] withRowAnimation:UITableViewRowAnimationNone];

    if([theDelegate respondsToSelector:@selector(onStartOTA:toFTCClient:)])
        [theDelegate onStartOTA:localOTAFilePath toFTCClient:client];
}

- (void)requestsManager:(id<GRRequestsManagerProtocol>)requestsManager didFailRequest:(id<GRRequestProtocol>)request withError:(NSError *)error
{
    NSLog(@"requestsManager:didFailRequest:withError: \n %@", error);
    [self.requestsManager stopAndCancelAllRequests];
}



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
