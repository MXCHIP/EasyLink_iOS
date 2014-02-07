//
//  EasyLinkMainViewController.m
//  EMW ToolBox
//
//  Created by William Xu on 13-7-28.
//  Copyright (c) 2013年 MXCHIP Co;Ltd. All rights reserved.
//

#import "EasyLinkMainViewController.h"
#import "APManager.h"

extern BOOL newModuleFound;


@interface EasyLinkMainViewController (Private)

/* button action, where we need to start or stop the request 
 @param: button ... tag value defines the action 
 */
- (IBAction)easyLinkV1ButtonAction:(UIButton*)button;
- (IBAction)easyLinkV2ButtonAction:(UIButton*)button;

/* 
 Prepare a cell that is created with respect to the indexpath 
 @param cell is an object of UITableViewcell which is newly created 
 @param indexpath  is respective indexpath of the cell of the row. 
*/
-(UITableViewCell *) prepareCell:(UITableViewCell *)cell atIndexPath:(NSIndexPath *)indexPath;

/* 
 Notification method handler when app enter in forground
 @param the fired notification object
 */
- (void)appEnterInforground:(NSNotification*)notification;

/* 
 Notification method handler when app enter in background
 @param the fired notification object
 */
- (void)appEnterInBackground:(NSNotification*)notification;

/* 
 Notification method handler when status of wifi changes 
 @param the fired notification object
 */
- (void)wifiStatusChanged:(NSNotification*)notification;


/* enableUIAccess
  * enable / disable the UI access like enable / disable the textfields 
  * and other component while transmitting the packets.
  * @param: vbool is to validate the controls.
 */
-(void) enableUIAccess:(BOOL) isEnable;


@end

@implementation EasyLinkMainViewController

- (void)awakeFromNib
{
    [super awakeFromNib];
}

- (void)didReceiveMemoryWarning {
    // Releases the view if it doesn't have a superview.
    [super didReceiveMemoryWarning];
    // Release any cached data, images, etc that aren't in use.
}

#pragma mark - View lifecycle -

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view from its nib.

    easylink_config = [[EASYLINK alloc] init];
    self.navigationItem.title = @"EasyLink";
    
    //按钮加边框
    [EasylinkV1Button.layer setMasksToBounds:YES];
    [EasylinkV1Button.layer setCornerRadius:8.0];
    [EasylinkV1Button.layer setBorderWidth:1.5];
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    CGColorRef colorref = CGColorCreate(colorSpace,(CGFloat[]){ 0, 122.0/255, 1, 1 });
    [EasylinkV1Button.layer setBorderColor:colorref];
    
    [EasylinkV2Button.layer setMasksToBounds:YES];
    [EasylinkV2Button.layer setCornerRadius:8.0];
    [EasylinkV2Button.layer setBorderWidth:1.5];
    [EasylinkV2Button.layer setBorderColor:colorref];
    
    [configTableView setScrollEnabled:FALSE];

    // wifi notification when changed.
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(wifiStatusChanged:) name:kReachabilityChangedNotification object:nil];
    
    EasylinkV1Button.exclusiveTouch = YES;
    EasylinkV2Button.exclusiveTouch = YES;
    wifiReachability = [Reachability reachabilityForLocalWiFi];  //监测Wi-Fi连接状态
	[wifiReachability startNotifier];
    
    NetworkStatus netStatus = [wifiReachability currentReachabilityStatus];	
    if ( netStatus == NotReachable ) {// No activity if no wifi
        UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:@"Alert" message:@"WiFi not available. Please check your WiFi connection" delegate:Nil cancelButtonTitle:@"OK" otherButtonTitles: nil];
        [alertView show];
    }
    
    //// stoping the process in app backgroud state
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(appEnterInBackground:) name:UIApplicationDidEnterBackgroundNotification object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(appEnterInforground:) name:UIApplicationWillEnterForegroundNotification object:nil];
    
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
}

- (void)viewWillDisappear:(BOOL)animated{
    [self stopAction];
    // Retain the UI access for the user.
    [self enableUIAccess:YES];
    [super viewWillDisappear:animated];
}


- (void)viewDidUnload {
    [super viewDidUnload];
    // Release any retained subviews of the main view.
    // e.g. self.myOutlet = nil;
    [easylink_config stopTransmitting];
    easylink_config = nil;
    
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    // Return YES for supported orientations
    return (interfaceOrientation == UIInterfaceOrientationPortrait);
}

#pragma mark - TRASMITTING DATA -

/*
 This method begins configuration transmit
 In case of a failure the method throws an OSFailureException.
 */
-(void) sendAction{
    newModuleFound = NO;
    [easylink_config transmitSettings];
}

/*
 This method stop the sending of the configuration to the remote device
  In case of a failure the method throws an OSFailureException.
 */
-(void) stopAction{
    [easylink_config stopTransmitting];
}

/*
 This method waits for an acknowledge from the remote device than it stops the transmit to the remote device and returns with data it got from the remote device.
 This method blocks until it gets respond.
 The method will return true if it got the ack from the remote device or false if it got aborted by a call to stopTransmitting.
 In case of a failure the method throws an OSFailureException.
 */

- (void) waitForAckThread: (id)sender{
    while(1){
        if ( newModuleFound==YES ){
            [self stopAction];
            [self enableUIAccess:YES];
            [self.navigationController popToRootViewControllerAnimated:YES];
            break;
        }
        sleep(1);
    }
    sleep(1);
    
}


/*
 This method start the transmitting the data to connected 
 AP. Nerwork validation is also done here. All exceptions from
 library is handled. 
 */
- (void)startTransmitting: (int)version {
    NetworkStatus netStatus = [wifiReachability currentReachabilityStatus];
    if ( netStatus == NotReachable ){// No activity if no wifi
            
        UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:@"Alert" message:@"WiFi not available. Please check your WiFi connection" delegate:Nil cancelButtonTitle:@"OK" otherButtonTitles: nil];
        [alertView show];
        return;
    }

    NSString *ssid = [ssidField.text length] ? ssidField.text : nil;
    NSString *passwordKey = [passwordField.text length] ? passwordField.text : nil;
        
    [easylink_config setSettingsWithSsid:ssid password:passwordKey version:version];
    [self sendAction];
    //[NSThread detachNewThreadSelector:@selector(waitForAckThread:) toTarget:self withObject:nil];

    [self enableUIAccess:NO];
}

/*!!!!!!
  This is the button action, where we need to start or stop the request 
 @param: button ... tag value defines the action !!!!!!!!!
 !!!*/
- (IBAction)easyLinkV1ButtonAction:(UIButton*)button{

    switch (button.selected) {
      case 0:
            [EasylinkV1Button setBackgroundColor:[UIColor colorWithRed:0 green:122.0/255 blue:1 alpha:1]];
            [EasylinkV1Button setSelected:YES];
            [EasylinkV2Button setBackgroundColor:[UIColor colorWithRed:1 green:1 blue:1 alpha:0]];
            [EasylinkV2Button setSelected:NO];
            [self startTransmitting: EASYLINK_V1];
          break;
      case 1: /// stop the loop
            [button setBackgroundColor:[UIColor colorWithRed:1 green:1 blue:1 alpha:0]];
            [EasylinkV1Button setSelected:NO];
            [self stopAction];
            // Retain the UI access for the user.
            [self enableUIAccess:YES];
            break;
      default:
            break;
    }
}

- (IBAction)easyLinkV2ButtonAction:(UIButton*)button{
    
    switch (button.selected) {
        case 0:
            [EasylinkV2Button setBackgroundColor:[UIColor colorWithRed:0 green:122.0/255 blue:1 alpha:1]];
            [EasylinkV2Button setSelected:YES];
            [EasylinkV1Button setBackgroundColor:[UIColor colorWithRed:1 green:1 blue:1 alpha:0]];
            [EasylinkV1Button setSelected:NO];
            [self startTransmitting: EASYLINK_V2];
            break;
        case 1: /// stop the loop
            [button setBackgroundColor:[UIColor colorWithRed:1 green:1 blue:1 alpha:0]];
            [EasylinkV2Button setSelected:NO];
            [self stopAction];
            // Retain the UI access for the user.
            [self enableUIAccess:YES];
            break;
        default:
            break;
    }
}


#pragma mark - UITableview Delegate -

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView{
    return 1;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath{
    
   // NSString *str = [[NSString alloc] initWithFormat:@"%d-%d",indexPath.row,indexPath.section];
    static NSString *tableCellIdentifier = @"APInfo";
   
    UITableViewCell *cell = (UITableViewCell *)[tableView dequeueReusableCellWithIdentifier:tableCellIdentifier];
    if ( cell == nil ) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:tableCellIdentifier];
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
        UIImage *image = nil;
        if ( indexPath.row == 0 ){// top row
            image = [UIImage imageNamed:@"top_cell_iPhone.png"];
        }else if ( indexPath.row == 2 ){// last row
            image = [UIImage imageNamed:@"bottom_cell_iPhone.png"];
        }else {
           image = [UIImage imageNamed:@"middle_cell_iPhone.png"];
        }
        
        UIImageView* imageView = [[UIImageView alloc] initWithImage:image];
        [cell setBackgroundView:imageView];
        [cell setBackgroundColor:[UIColor clearColor]];
        cell = [self prepareCell:cell
                     atIndexPath:indexPath];
        
    }
    return cell;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section{
    return 3;
}

#pragma mark - UITextfiled delegate -

- (void)textFieldDidEndEditing:(UITextField *)textField
{
    [configTableView setScrollEnabled:FALSE];
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField
{
    [textField resignFirstResponder];
    return YES;
}


#pragma mark - Private Methods -

/* enableUIAccess
 * enable / disable the UI access like enable / disable the textfields 
 * and other component while transmitting the packets.
 * @param: vbool is to validate the controls.
 */
-(void) enableUIAccess:(BOOL) isEnable{
    passwordField.userInteractionEnabled = isEnable;
    
    // rotating the wheel is app transmitting the data
    [[EMWUtility sharedInstance] rotateSpinner:spinnerView onButton:EasylinkV2Button isStart:!isEnable];
}

/* 
 Prepare a cell that is created with respect to the indexpath 
 @param cell is an object of UITableViewcell which is newly created 
 @param indexpath  is respective indexpath of the cell of the row. 
 */
-(UITableViewCell *) prepareCell:(UITableViewCell *)cell atIndexPath:(NSIndexPath *)indexPath
{
    if ( indexPath.row == SSID_ROW ){/// this is SSID row 
        ssidField = [[UITextField alloc] initWithFrame:CGRectMake(CELL_IPHONE_FIELD_X,
                                                                  CELL_iPHONE_FIELD_Y,
                                                                  CELL_iPHONE_FIELD_WIDTH,
                                                                  CELL_iPHONE_FIELD_HEIGHT)];
        [ssidField setDelegate:self];
        [ssidField setClearButtonMode:UITextFieldViewModeNever];
        [ssidField setPlaceholder:@"SSID"];
        [ssidField setBackgroundColor:[UIColor clearColor]];
        [ssidField setReturnKeyType:UIReturnKeyDone];
        [ssidField setText:[EASYLINK ssidForConnectedNetwork]];
        [cell addSubview:ssidField];
        
        cell.textLabel.font = [UIFont boldSystemFontOfSize:15.0];
        cell.textLabel.text = @"SSID";
    }else if(indexPath.row == PASSWORD_ROW ){// this is password field 
        passwordField = [[UITextField alloc] initWithFrame:CGRectMake(CELL_IPHONE_FIELD_X,
                                                                      CELL_iPHONE_FIELD_Y,
                                                                      CELL_iPHONE_FIELD_WIDTH,
                                                                      CELL_iPHONE_FIELD_HEIGHT)];
        [passwordField setDelegate:self];
        [passwordField setClearButtonMode:UITextFieldViewModeNever];
        [passwordField setPlaceholder:@"Password"];
        [passwordField setReturnKeyType:UIReturnKeyDone];
        [passwordField setAutocapitalizationType:UITextAutocapitalizationTypeNone];
        [passwordField setAutocorrectionType:UITextAutocorrectionTypeNo];
        [passwordField setBackgroundColor:[UIColor clearColor]];
        [cell addSubview:passwordField];
        
        cell.textLabel.font = [UIFont boldSystemFontOfSize:15.0];
        cell.textLabel.text = @"Password";
    }
    else if ( indexPath.row == GATEWAY_ADDRESS_ROW){
        /// this is Gateway Address field
        gatewayAddress = [[UITextField alloc] initWithFrame:CGRectMake(CELL_IPHONE_FIELD_X,
                                                                  CELL_iPHONE_FIELD_Y,
                                                                  CELL_iPHONE_FIELD_WIDTH,
                                                                  CELL_iPHONE_FIELD_HEIGHT)];
        [gatewayAddress setDelegate:self];
        [gatewayAddress setClearButtonMode:UITextFieldViewModeNever];
        [gatewayAddress setPlaceholder:@"Gateway IP Address"];
        [gatewayAddress setReturnKeyType:UIReturnKeyDone];
        [gatewayAddress setBackgroundColor:[UIColor clearColor]];
        [gatewayAddress setUserInteractionEnabled:NO];
        [gatewayAddress setText:[EASYLINK getGatewayAddress]];

        [cell addSubview:gatewayAddress];
        
        cell.textLabel.font = [UIFont boldSystemFontOfSize:15.0];
        cell.textLabel.text = @"Gateway";
    }

    return cell;
}


/* 
 Notification method handler when app enter in forground
 @param the fired notification object
 */
- (void)appEnterInforground:(NSNotification*)notification{
    NSLog(@"%s", __func__);
    ssidField.text = [EASYLINK ssidForConnectedNetwork];
    gatewayAddress.text = [EASYLINK getGatewayAddress];
}

/*
 Notification method handler when app enter in background
 @param the fired notification object
 */
- (void)appEnterInBackground:(NSNotification*)notification{
    NSLog(@"%s", __func__);
    if ( EasylinkV1Button.selected )
        [self easyLinkV1ButtonAction:EasylinkV1Button]; /// Simply revert the state
    if ( EasylinkV2Button.selected )
        [self easyLinkV2ButtonAction:EasylinkV2Button]; /// Simply revert the state
}

/* 
 Notification method handler when status of wifi changes 
 @param the fired notification object
 */
- (void)wifiStatusChanged:(NSNotification*)notification{
    NSLog(@"%s", __func__);
    Reachability *verifyConnection = [notification object];	
    NSAssert(verifyConnection != NULL, @"currentNetworkStatus called with NULL verifyConnection Object");
    NetworkStatus netStatus = [verifyConnection currentReachabilityStatus];	
    if ( netStatus == NotReachable ){
        if ( EasylinkV1Button.selected )
            [self easyLinkV1ButtonAction:EasylinkV1Button]; /// Simply revert the state
        if ( EasylinkV2Button.selected )
            [self easyLinkV2ButtonAction:EasylinkV2Button]; /// Simply revert the state
        // The operation couldn’t be completed. No route to host
        UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:@"EMW ToolBox Alert" message:@"Wifi Not available. Please check your wifi connection" delegate:Nil cancelButtonTitle:@"OK" otherButtonTitles: nil];
        [alertView show];
        ssidField.text = @"";
        gatewayAddress.text = @"";
    }else {
        ssidField.text = [EASYLINK ssidForConnectedNetwork];
        gatewayAddress.text = [EASYLINK getGatewayAddress];
    }
}



@end
