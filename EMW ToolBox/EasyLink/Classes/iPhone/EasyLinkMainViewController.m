//
//  EasyLinkMainViewController.m
//  EMW ToolBox
//
//  Created by William Xu on 13-7-28.
//  Copyright (c) 2013年 MXCHIP Co;Ltd. All rights reserved.
//

#import "EasyLinkMainViewController.h"
#import "PulsingHaloLayer.h"
#import "EasyLinkFTCTableViewController.h"
#import "EasyLinkIpConfigTableViewController.h"

BOOL configTableMoved = NO;

@interface EasyLinkMainViewController ()

@end

@interface EasyLinkMainViewController (Private)

/* button action, where we need to start or stop the request 
 @param: button ... tag value defines the action 
 */
- (void)updateButtonTitle_NewDevices;
- (IBAction)easyLinkV2ButtonAction:(UIButton*)button;
- (IBAction)easyLinkuAPButtonAction:(UIButton*)button;
- (void)handleSingleTapPhoneImage:(UIGestureRecognizer *)gestureRecognizer;

/*
 This method start the transmitting the data to connected
 AP. Nerwork validation is also done here. All exceptions from
 library is handled.
 */
- (void)startTransmitting: (EasyLinkMode)mode;

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
@synthesize foundModules;

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
    
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *docPath = [paths objectAtIndex:0];
    apInforRecordFile = [docPath stringByAppendingPathComponent:@"ApInforRecord.plist"];
    apInforRecord = [[NSMutableDictionary alloc] initWithContentsOfFile:apInforRecordFile];
    if(apInforRecord == nil)
        apInforRecord = [NSMutableDictionary dictionaryWithCapacity:10];    
    
    if( easylink_config == nil){
        easylink_config = [[EASYLINK alloc]init];
        [easylink_config startFTCServerWithDelegate:self];
    }
    if( self.foundModules == nil)
        self.foundModules = [[NSMutableArray alloc]initWithCapacity:10];
    
    deviceIPConfig = [[NSMutableDictionary alloc] initWithCapacity:5];
<<<<<<< HEAD
=======
    
    ssidData = [NSData data];
    
//    CGRect screenBounds = [UIScreen mainScreen].bounds;
    
//    if( screenBounds.size.height == 480.0){
//        imagePhoneView.center = CGPointMake(imagePhoneView.center.x, imagePhoneView.center.y+MOVE_UP_ON_3_5_INCH/2);
//        imagePhoneView.transform =  CGAffineTransformMakeTranslation(0, MOVE_UP_ON_3_5_INCH);
//    }

>>>>>>> master

    //按钮加边框
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    CGColorRef colorref = CGColorCreate(colorSpace,(CGFloat[]){ 0, 122.0/255, 1, 1 });
    
    [configTableView.layer setCornerRadius:8.0];
    [configTableView.layer setBorderWidth:1.5];
    [configTableView.layer setBorderColor:colorref];
    CGColorRelease (colorref);
    CGColorSpaceRelease(colorSpace);
    self.automaticallyAdjustsScrollViewInsets = NO;
        
    // wifi notification when changed.
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(wifiStatusChanged:) name:kReachabilityChangedNotification object:nil];
    
    wifiReachability = [Reachability reachabilityForLocalWiFi];  //监测Wi-Fi连接状态
	[wifiReachability startNotifier];
    
    NetworkStatus netStatus = [wifiReachability currentReachabilityStatus];
    if ( netStatus != NotReachable ) {
        [deviceIPConfig setObject:@YES forKey:@"DHCP"];
        [deviceIPConfig setObject:[EASYLINK getIPAddress] forKey:@"IP"];
        [deviceIPConfig setObject:[EASYLINK getNetMask] forKey:@"NetMask"];
        [deviceIPConfig setObject:[EASYLINK getGatewayAddress] forKey:@"GateWay"];
        [deviceIPConfig setObject:[EASYLINK getGatewayAddress] forKey:@"DnsServer"];
    }
    
    [self updateButtonTitle_NewDevices];

    
    //// stoping the process in app backgroud state
    NSLog(@"regisister notificationcenter");
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(appEnterInBackground:) name:UIApplicationDidEnterBackgroundNotification object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(appEnterInforground:) name:UIApplicationDidBecomeActiveNotification object:nil];
    
    
}

- (void)viewWillAppear:(BOOL)animated {
    /*Update IP config cell*/
    [ipAddress setUserInteractionEnabled:NO];
    if(ipAddress != nil){
        if([[deviceIPConfig objectForKey:@"DHCP"] boolValue] == YES)
            [ipAddress setText:@"Automatic"];
        else
            [ipAddress setText:[deviceIPConfig objectForKey:@"IP"]];
    }


    [super viewWillAppear:animated];
}

- (void)viewWillDisappear:(BOOL)animated{
    if([self.navigationController.viewControllers indexOfObject:self] == NSNotFound){
        easylink_config.delegate = nil;
        [easylink_config closeFTCServer];
        easylink_config = nil;
        self.foundModules = nil;
    }
    
    [self stopAction];
    // Retain the UI access for the user.
    [self enableUIAccess:YES];
    [super viewWillDisappear:animated];
}

- (void)dealloc {
    NSLog(@"%s=>dealloc", __func__);
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    // Return YES for supported orientations
    return (interfaceOrientation == UIInterfaceOrientationPortrait);
}

#pragma mark - New Devices Button -

- (void)updateButtonTitle_NewDevices
{
    if ([foundModules count] == 0) {
        //newDevicesButton.titleLabel.text = @"hello";
        [newDevicesButton setTitle:@"New Devices(0)" forState: UIControlStateNormal];
        [newDevicesButton setUserInteractionEnabled:false];
    }else{
        NSString *title = [[NSString alloc]initWithFormat:@"New Devices(%d)",[foundModules count]];
        [newDevicesButton setTitle:title forState: UIControlStateNormal];
        [newDevicesButton setUserInteractionEnabled:true];
    }
}

#pragma mark - TRASMITTING DATA -

/*
 This method begins configuration transmit
 In case of a failure the method throws an OSFailureException.
 */
-(void) sendAction{
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
 This method start the transmitting the data to connected 
 AP. Nerwork validation is also done here. All exceptions from
 library is handled. 
 */
- (void)startTransmitting: (EasyLinkMode)mode {
    NSMutableDictionary *wlanConfig = [NSMutableDictionary dictionaryWithCapacity:20];

<<<<<<< HEAD
    if([ssidField.text length] > 0) [wlanConfig setObject:ssidField.text forKey:KEY_SSID];
    if([passwordField.text length] > 0) [wlanConfig setObject:passwordField.text forKey:KEY_PASSWORD];
    [wlanConfig setObject:[NSNumber numberWithBool:[[deviceIPConfig objectForKey:@"DHCP"] boolValue]] forKey:KEY_DHCP];
    
    if([[deviceIPConfig objectForKey:@"IP"] length] > 0)  [wlanConfig setObject:[deviceIPConfig objectForKey:@"IP"] forKey:KEY_IP];
    if([[deviceIPConfig objectForKey:@"NetMask"] length] > 0)  [wlanConfig setObject:[deviceIPConfig objectForKey:@"NetMask"] forKey:KEY_NETMASK];
    if([[deviceIPConfig objectForKey:@"GateWay"] length] > 0)  [wlanConfig setObject:[deviceIPConfig objectForKey:@"GateWay"] forKey:KEY_GATEWAY];
    if([[deviceIPConfig objectForKey:@"DnsServer"] length] > 0)  [wlanConfig setObject:[deviceIPConfig objectForKey:@"DnsServer"] forKey:KEY_DNS1];
=======
    NSString *passwordKey = [passwordField.text length] ? passwordField.text : @"";
    NSString *userInfo = [userInfoField.text length]? userInfoField.text : @"";
    NSNumber *dhcp = [NSNumber numberWithBool:[[deviceIPConfig objectForKey:@"DHCP"] boolValue]];
    NSString *ipString = [[deviceIPConfig objectForKey:@"IP"] length] ? [deviceIPConfig objectForKey:@"IP"] : @"";
    NSString *netmaskString = [[deviceIPConfig objectForKey:@"NetMask"] length] ? [deviceIPConfig objectForKey:@"NetMask"] : @"";
    NSString *gatewayString = [[deviceIPConfig objectForKey:@"GateWay"] length] ? [deviceIPConfig objectForKey:@"GateWay"] : @"";
    NSString *dnsString = [[deviceIPConfig objectForKey:@"DnsServer"] length] ? [deviceIPConfig objectForKey:@"DnsServer"] : @"";
    if([[deviceIPConfig objectForKey:@"DHCP"] boolValue] == YES) ipString = @"";
    
    wlanConfigArray = [NSArray arrayWithObjects: ssidData, passwordKey, dhcp, ipString, netmaskString, gatewayString, dnsString, nil];

>>>>>>> master

    NSString *userInfo = [userInfoField.text length]? userInfoField.text : @"";
    if(userInfo!=nil){
        const char *temp = [userInfo cStringUsingEncoding:NSUTF8StringEncoding];
        [easylink_config prepareEasyLink_withFTC:wlanConfig info:[NSData dataWithBytes:temp length:strlen(temp)] mode:mode ];
        [self sendAction];
    }else{
        [easylink_config prepareEasyLink_withFTC:wlanConfig info:nil mode:mode];
    }
    targetSsid = [wlanConfig objectForKey:KEY_SSID];

    [self enableUIAccess:NO];
}

- (IBAction)easyLinkV2ButtonAction:(UIButton*)button{
    
    CATransition *animation = [CATransition animation];
    animation.delegate = self;
    animation.duration = 0.5 ;
    animation.timingFunction = UIViewAnimationCurveEaseInOut;
    animation.type = kCATransitionFade;
    
    NetworkStatus netStatus = [wifiReachability currentReachabilityStatus];
    if ( netStatus == NotReachable) {// No activity if no wifi
        alertView = [[UIAlertView alloc] initWithTitle:@"Connection Error" message:@"WiFi not available. Please check your WiFi connection" delegate:Nil cancelButtonTitle:@"OK" otherButtonTitles: nil];
        [alertView show];
        return;
    }
    
    if([ssidField.text length] == 0){
        alertView = [[UIAlertView alloc] initWithTitle:@"Wi-Fi Settings Error" message:@"SSID field is empry." delegate:Nil cancelButtonTitle:@"OK" otherButtonTitles: nil];
        [alertView show];
        return;
    }
    
    if([ssidField.text hasPrefix:@"EasyLink_"]){
        alertView = [[UIAlertView alloc] initWithTitle:@"Wi-Fi Settings Error" message:@"You should not using a \"EasyLink_XXXXXX\" as a Wi-Fi's ssid, this name is used internally by MXCHIP module." delegate:Nil cancelButtonTitle:@"OK" otherButtonTitles: nil];
        [alertView show];
        return;
    }
    
    /*Pop up a Easylink sending dialog*/
    easyLinkSendingView = [[CustomIOS7AlertView alloc] init];
    
    UIView *alertContentView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 290, 300)];
    
    UILabel *title = [[UILabel alloc] initWithFrame:CGRectMake(alertContentView.frame.size.width/2-130, 20, 260, 25)];
    title.text = @"Transmitting Data...";
    title.font= [UIFont boldSystemFontOfSize:19.0];
    title.textAlignment = NSTextAlignmentCenter;
    [alertContentView addSubview:title];
    
    NSMutableParagraphStyle *paragraphStyle = [[NSMutableParagraphStyle alloc] init];
    paragraphStyle.lineBreakMode = NSLineBreakByWordWrapping;
    paragraphStyle.alignment = NSTextAlignmentCenter;
    paragraphStyle.lineSpacing = 5.0f;
    
    UIFont *font = [UIFont systemFontOfSize:14.0];
    
    NSDictionary *attributes = [NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:paragraphStyle,
                                                                    font,
                                                                    nil]
                                                           forKeys:[NSArray arrayWithObjects:NSParagraphStyleAttributeName,
                                                                    NSFontAttributeName,
                                                                    nil]];

    [easyLinkSendingView setContainerView:alertContentView];
    
    /*EasyLink button image*/
    UIImageView *easyLinkButtonView = [[UIImageView alloc] initWithFrame:CGRectMake(alertContentView.frame.size.width/2-45, 76, 90, 90)];
    easyLinkButtonView.image = [UIImage imageNamed:@"EASYLINK_BUTTON.png" ];
    [alertContentView addSubview:easyLinkButtonView];
    
    /*EasyLink pres image*/
    UIImageView *buttonPressView = [[UIImageView alloc] initWithFrame:CGRectMake(alertContentView.frame.size.width/2+80, 180, 120, 120)];
    buttonPressView.image = [UIImage imageNamed:@"EASYLINK_PRESS.png" ];
    [alertContentView addSubview:buttonPressView];
    
    [UIView animateWithDuration:0.5
                          delay:0.0
                        options:UIViewAnimationOptionCurveEaseIn
                     animations:^{
                         [buttonPressView setFrame:CGRectMake(alertContentView.frame.size.width/2-15, 130, 40, 40)];
                     }
                     completion:^(BOOL finished){
                         ;
                     }];

    /*Add Line 1*/
    UILabel *content = [[UILabel alloc] initWithFrame:CGRectMake(alertContentView.frame.size.width/2-130, 15, 260, 100)];
    NSAttributedString *contentText =  [[NSAttributedString alloc] initWithString:@"Press EasyLink button on your device!"
                                                                       attributes:attributes];
    content.attributedText = contentText;
    content.numberOfLines = 1;
    [alertContentView addSubview:content];
    
    UIImageView *phoneImageView = [[UIImageView alloc] initWithFrame:CGRectMake(alertContentView.frame.size.width/2-100, 180, 200, 200)];
    [phoneImageView setImage:[UIImage imageNamed:@"EasyLinkPhoneStarted.png"]];
    [alertContentView addSubview:phoneImageView];
    [phoneImageView setContentMode:UIViewContentModeScaleAspectFit];
    alertContentView.clipsToBounds = true;
    
    PulsingHaloLayer *pulsingHalo = [PulsingHaloLayer layer];
    pulsingHalo.position = CGPointMake(alertContentView.frame.size.width/2, phoneImageView.center.y-25);
    [alertContentView.layer insertSublayer:pulsingHalo above:phoneImageView.layer];
    pulsingHalo.radius = 300;
    pulsingHalo.backgroundColor = [UIColor colorWithRed:0 green:122.0/255 blue:1.0 alpha:1.0].CGColor;
    
    [pulsingHalo startAnimation:YES];
    
    [easyLinkSendingView setButtonTitles:[NSMutableArray arrayWithObjects:@"Stop", nil]];
    __weak EasyLinkMainViewController *_self = self;
    [easyLinkSendingView setOnButtonTouchUpInside:^(CustomIOS7AlertView *customIOS7AlertView, NSInteger buttonIndex) {
        if(buttonIndex == 0){
            [_self enableUIAccess:YES];
        }
        [_self stopAction];
        
        //[_imagePhoneView setImage:[UIImage imageNamed:@"EasyLinkPhone.png"]];
        NSLog(@"Block: Button at position %ld is clicked on alertView %ld.", (long)buttonIndex, (long)[customIOS7AlertView tag]);
        [customIOS7AlertView close];
    }];
    
    [easyLinkSendingView setUseMotionEffects:true];
    [easyLinkSendingView show];

    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    bool useEasyLinkV2Only = [defaults boolForKey:@"easylinkv2_only_preference"];
    NSLog(@"Preference %d", useEasyLinkV2Only);

    if(useEasyLinkV2Only == YES)
        [self startTransmitting: EASYLINK_V2];
    else
        [self startTransmitting: EASYLINK_PLUS];
}

- (IBAction)easyLinkuAPButtonAction:(UIButton*)button
{
    if([ssidField.text length] == 0){
        alertView = [[UIAlertView alloc] initWithTitle:@"Wi-Fi Settings Error" message:@"SSID field is empry." delegate:Nil cancelButtonTitle:@"OK" otherButtonTitles: nil];
        [alertView show];
        return;
    }
    
    if([ssidField.text hasPrefix:@"EasyLink_"]){
        alertView = [[UIAlertView alloc] initWithTitle:@"Wi-Fi Settings Error" message:@"You should not using a \"EasyLink_XXXXXX\" as a Wi-Fi's ssid, this name is used internally by MXCHIP module." delegate:Nil cancelButtonTitle:@"OK" otherButtonTitles: nil];
        [alertView show];
        return;
    }
    
    /*Pop up a Easylink sending dialog*/
    easyLinkUAPSendingView = [[CustomIOS7AlertView alloc] init];
    
    UIScrollView *alertContentView = [[UIScrollView alloc] initWithFrame:CGRectMake(0, 0, 290, 300)];
    
    alertContentView.tag = 0x1000;
    alertContentView.pagingEnabled = YES;
    alertContentView.userInteractionEnabled = false;
    alertContentView.showsHorizontalScrollIndicator = NO;
    alertContentView.contentSize = CGSizeMake(290*4, 300);
    
    [alertContentView scrollRectToVisible:CGRectMake(0, 0, 290, 300) animated:YES];
    
    /* uAP config Page 1*/
    UILabel *title = [[UILabel alloc] initWithFrame:CGRectMake(alertContentView.frame.size.width/2-130, 20, 260, 25)];
    title.text = @"Start EasyLink uAP mode...";
    title.font= [UIFont boldSystemFontOfSize:19.0];
    title.textAlignment = NSTextAlignmentCenter;
    [alertContentView addSubview:title];
    
    NSMutableParagraphStyle *paragraphStyle = [[NSMutableParagraphStyle alloc] init];
    paragraphStyle.lineBreakMode = NSLineBreakByWordWrapping;
    paragraphStyle.alignment = NSTextAlignmentCenter;
    paragraphStyle.lineSpacing = 5.0f;
    
    UIFont *font = [UIFont systemFontOfSize:14.0];
    
    NSDictionary *attributes = [NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:paragraphStyle,
                                                                    font,
                                                                    nil]
                                                           forKeys:[NSArray arrayWithObjects:NSParagraphStyleAttributeName,
                                                                    NSFontAttributeName,
                                                                    nil]];
    
    /*EasyLink button image*/
    UIImageView *easyLinkButtonView = [[UIImageView alloc] initWithFrame:CGRectMake(alertContentView.frame.size.width/2-45, 76, 90, 90)];
    easyLinkButtonView.image = [UIImage imageNamed:@"EASYLINK_BUTTON.png" ];
    [alertContentView addSubview:easyLinkButtonView];
    
    /*EasyLink pres image*/
    UIImageView *buttonPressView = [[UIImageView alloc] initWithFrame:CGRectMake(alertContentView.frame.size.width/2+80, 180, 120, 120)];
    buttonPressView.image = [UIImage imageNamed:@"EASYLINK_PRESS.png" ];
    [alertContentView addSubview:buttonPressView];
    
    [UIView animateWithDuration:0.5
                          delay:0.0
                        options:UIViewAnimationOptionCurveEaseIn
                     animations:^{
                         [buttonPressView setFrame:CGRectMake(alertContentView.frame.size.width/2-15, 130, 40, 40)];
                     }
                     completion:^(BOOL finished){
                         ;
                     }];
    
    /*Add Line 1*/
    UILabel *content = [[UILabel alloc] initWithFrame:CGRectMake(alertContentView.frame.size.width/2-130, 15, 260, 100)];
    content.attributedText = [[NSAttributedString alloc] initWithString:@"Press EasyLink button on your device!"
                                                             attributes:attributes];
    [alertContentView addSubview:content];
    
    
    /* uAP config Page 2*/
    title = [[UILabel alloc] initWithFrame:CGRectMake(alertContentView.frame.size.width/2-130 + alertContentView.frame.size.width, 20, 260, 25)];
    title.text = @"Connecting to module...";
    title.font= [UIFont boldSystemFontOfSize:19.0];
    title.textAlignment = NSTextAlignmentCenter;
    [alertContentView addSubview:title];
    
    content = [[UILabel alloc] initWithFrame:CGRectMake(alertContentView.frame.size.width/2-130 + alertContentView.frame.size.width, 15, 260, 100)];
    content.attributedText = [[NSAttributedString alloc] initWithString:@"Press Home button to exit current APP."
                                                             attributes:attributes];;
    [alertContentView addSubview:content];
    
    // 750 * 438
    UIImageView *homeButtonView = [[UIImageView alloc] initWithFrame:CGRectMake(alertContentView.frame.size.width/2-145 + alertContentView.frame.size.width, 76, 290, 80)];
    homeButtonView.image = [UIImage imageNamed:@"Home_Button.png" ];
    [alertContentView addSubview:homeButtonView];
    
    
    /* uAP config Page 3*/
    title = [[UILabel alloc] initWithFrame:CGRectMake(alertContentView.frame.size.width/2-130 + 2 * alertContentView.frame.size.width, 20, 260, 25)];
    title.text = @"Transmitting Data...";
    title.font= [UIFont boldSystemFontOfSize:19.0];
    title.textAlignment = NSTextAlignmentCenter;
    [alertContentView addSubview:title];
    
    /* uAP config Page 4*/
    title = [[UILabel alloc] initWithFrame:CGRectMake(alertContentView.frame.size.width/2-130 + 3 * alertContentView.frame.size.width, 20, 260, 25)];
    title.text = @"Scaning for new device...";
    title.font= [UIFont boldSystemFontOfSize:19.0];
    title.textAlignment = NSTextAlignmentCenter;
    [alertContentView addSubview:title];
    
    
    [easyLinkUAPSendingView setContainerView:alertContentView];
    
    [easyLinkUAPSendingView setButtonTitles:[NSMutableArray arrayWithObjects:@"Stop", @"Previous", @"Next", nil]];
    
    __weak EasyLinkMainViewController *_self = self;
    
    [easyLinkUAPSendingView setOnButtonTouchUpInside:^(CustomIOS7AlertView *customIOS7AlertView, NSInteger buttonIndex) {
        NSUInteger currentPage;
        UIScrollView *containerView = (UIScrollView *)customIOS7AlertView.containerView;
        currentPage = containerView.contentOffset.x / 290;
        if(buttonIndex == 0){
            [_self enableUIAccess:YES];
            [_self stopAction];
            [customIOS7AlertView close];
        }else if(buttonIndex == 1){
            [containerView scrollRectToVisible:CGRectMake( --currentPage * 290, 0, 290, 300) animated:YES];
        }else if(buttonIndex == 2){
            if(currentPage == 2) return;
            [containerView scrollRectToVisible:CGRectMake( ++currentPage * 290, 0, 290, 300) animated:YES];
        }
        
        if(currentPage == 0) {// This is the first page
            [(UIButton *)[customIOS7AlertView.dialogView viewWithTag: 1] setEnabled:NO];
        }else{
            [(UIButton *)[customIOS7AlertView.dialogView viewWithTag: 1] setEnabled:YES];
        };
        
        if(currentPage == 1) {// Should exit current app and connect to EasyLink_xxxxxx
            [(UIButton *)[customIOS7AlertView.dialogView viewWithTag: 2] setEnabled:NO];
        }else{
            [(UIButton *)[customIOS7AlertView.dialogView viewWithTag: 2] setEnabled:YES];
        };

        //[_imagePhoneView setImage:[UIImage imageNamed:@"EasyLinkPhone.png"]];
        NSLog(@"Block: Button at position %ld is clicked on alertView %ld.", (long)buttonIndex, (long)[customIOS7AlertView tag]);
        
    }];
    
    [easyLinkUAPSendingView setUseMotionEffects:true];
    [easyLinkUAPSendingView show];
    
    
    if([[EASYLINK ssidForConnectedNetwork] hasPrefix:@"EasyLink_"]){
        [(UIScrollView *)easyLinkUAPSendingView.containerView scrollRectToVisible:CGRectMake( 2 * 290, 0, 290, 300) animated:YES];
        [(UIButton *)[easyLinkUAPSendingView.dialogView viewWithTag: 3] setEnabled:NO];
        
    }else{
        [(UIButton *)[easyLinkUAPSendingView.dialogView viewWithTag: 1] setEnabled:NO];
    }
    
    [self startTransmitting: EASYLINK_SOFT_AP];
}


#pragma mark - UITableview Delegate -

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView{
        return 1;

}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath{
    UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"APInfo"];
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    [cell setBackgroundColor:[UIColor colorWithRed:0.100 green:0.478 blue:1.000 alpha:0.1]];
    cell = [self prepareCell:cell atIndexPath:indexPath];

    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    if(tableView == configTableView && indexPath.row == IP_ADDRESS_ROW){
        NSLog(@"selected");
        [self performSegueWithIdentifier:@"IP config" sender:configTableView];
        [tableView deselectRowAtIndexPath:indexPath animated:YES];
    }
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section{
    return 4;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
    return nil;
}


- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath
{
    NSUInteger row = [indexPath row];
    NSMutableDictionary *deleteModule = nil;
    deleteModule = [foundModules objectAtIndex:row];
    [easylink_config closeFTCClient: [deleteModule objectForKey:@"client"]];
}

- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath
{
    // Return NO if you do not want the specified item to be editable.
    return NO;
}

#pragma mark - UITextfiled delegate -

- (BOOL)textFieldShouldReturn:(UITextField *)textField
{
    [textField resignFirstResponder];
    return YES;
}

#pragma mark - EasyLink delegate -

- (void)onFoundByFTC:(NSNumber *)ftcClientTag currentConfig: (NSData *)config;
{
    NSError *err;
    NSIndexPath* indexPath;
    NSMutableDictionary *foundModule = nil;
    NSMutableDictionary *updateSettings;
    
    foundModule = [NSJSONSerialization JSONObjectWithData:config
                                                  options:NSJSONReadingMutableContainers|NSJSONReadingMutableLeaves
                                                    error:&err];
    NSLog(@"Recv JSON data, length: %lu", (unsigned long)[config length]);

    if (err) {
#ifdef DEBUG
        NSString *temp = [[NSString alloc] initWithData:config encoding:NSASCIIStringEncoding];
        NSLog(@"Unpackage JSON data failed:%@, %@", [err localizedDescription], temp);
#endif
        
        alertView = [[UIAlertView alloc] initWithTitle:@"EMW ToolBox Alert" message:@"JSON data err" delegate:Nil cancelButtonTitle:@"OK" otherButtonTitles: nil];
        [alertView show];
        return;
    }
    
    [foundModule setValue:ftcClientTag forKey:@"client"];
    updateSettings = [NSMutableDictionary dictionaryWithCapacity:10];
    [foundModule setValue:updateSettings forKey:@"update"];
    
    /*Replace an old device*/
    for( NSDictionary *object in self.foundModules){
        if ([[object objectForKey:@"N"] isEqualToString:[foundModule objectForKey:@"N"]] ){
            [easylink_config closeFTCClient:[object objectForKey:@"client"]];
        }
    }

    [self.foundModules addObject:foundModule];
    indexPath = [NSIndexPath indexPathForRow:[self.foundModules indexOfObject:foundModule] inSection:0];
    [foundTableViewController.tableView insertRowsAtIndexPaths:[NSArray arrayWithObject:indexPath]
                                withRowAnimation:UITableViewRowAnimationRight];
    
    /*Correct AP info input, save to file*/
    if([[apInforRecord objectForKey:ssidField.text] isEqualToString:passwordField.text] == NO){
        [apInforRecord setObject:passwordField.text forKey:ssidField.text];
        [apInforRecord writeToFile:apInforRecordFile atomically:YES];
    }
    
    [easyLinkSendingView close];
    [easyLinkUAPSendingView close];
    [self updateButtonTitle_NewDevices];
    [self stopAction];
    
    if(otaAlertView != nil){
        [otaAlertView close];
        otaAlertView = nil;
    }

    
}

- (void)onDisconnectFromFTC:(NSNumber *)ftcClientTag
{
    NSIndexPath* indexPath;
    NSDictionary *disconnectedClient;
    

    //if([self.navigationController topViewController] == )

    for( NSDictionary *object in self.foundModules){
        if ([[object objectForKey:@"client"] isEqualToNumber:ftcClientTag] ){
            indexPath = [NSIndexPath indexPathForRow:[self.foundModules indexOfObject:object] inSection:0];
            disconnectedClient = object;
            break;
        }
    }
    
    if(disconnectedClient != nil){
        [self.foundModules removeObject: disconnectedClient ];
        [foundTableViewController.tableView deleteRowsAtIndexPaths:[NSArray arrayWithObject:indexPath]
                                    withRowAnimation:UITableViewRowAnimationAutomatic];
    }

    if(customAlertView != nil){
        [customAlertView close];
        customAlertView = nil;
    }
    
    
    if(otaAlertView != nil){
        NSMutableParagraphStyle *paragraphStyle = [[NSMutableParagraphStyle alloc] init];
        paragraphStyle.lineBreakMode = NSLineBreakByCharWrapping;
        paragraphStyle.alignment = NSTextAlignmentCenter;
        paragraphStyle.lineSpacing = 5.0f;
        NSDictionary *attributes = [NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:paragraphStyle,
                                                                        nil]
                                                               forKeys:[NSArray arrayWithObjects:NSParagraphStyleAttributeName,
                                                                        nil]];
        NSAttributedString *contentText =  [[NSAttributedString alloc] initWithString:@"OTA processing..."
                                                                           attributes:attributes];
        
        for(UIView *object in [[otaAlertView containerView] subviews]){
            if(object.tag == 0x1001){
                [(UILabel *)object setAttributedText:contentText];
                [(UILabel *)object setNumberOfLines: 2];
                break;
            }
        }
    }

    if(foundTableViewController != nil && [foundModules count] != 0)
        [self.navigationController popToViewController:foundTableViewController animated:YES];
    else
        [self.navigationController popToViewController:self animated:YES];
}

#pragma mark - EasyLinkFTCTableViewController delegate-

- (void)onConfigured:(NSMutableDictionary *)configData
{
    NSError *err;
    
    //alertView = [[UIAlertView alloc] initWithTitle:@"Please wait..." message:@"Updating Wi-Fi module configuration" delegate:Nil cancelButtonTitle:nil otherButtonTitles: nil];
    customAlertView = [[CustomIOS7AlertView alloc] init];
    
    UIView *alertContentView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 290, 140)];
    
    UILabel *title = [[UILabel alloc] initWithFrame:CGRectMake(alertContentView.frame.size.width/2-130, 20, 260, 25)];
    title.text = @"Please wait...";
    title.font= [UIFont boldSystemFontOfSize:19.0];
    title.textAlignment = NSTextAlignmentCenter;
    [alertContentView addSubview:title];
    
    UILabel *content = [[UILabel alloc] initWithFrame:CGRectMake(alertContentView.frame.size.width/2-130, 50, 260, 25)];
    content.text = @"Setting Wi-Fi module";
    content.font= [UIFont systemFontOfSize:16.0];
    content.textAlignment = NSTextAlignmentCenter;
    [alertContentView addSubview:content];
    
    CGRect frame = CGRectMake(0, 0, 50, 50);
    UIActivityIndicatorView* spinner = [[UIActivityIndicatorView alloc] initWithFrame:frame];
    [spinner startAnimating];
    spinner.activityIndicatorViewStyle = UIActivityIndicatorViewStyleWhiteLarge;
    [spinner sizeToFit];
    [spinner setColor: [UIColor colorWithRed:0 green:122.0/255 blue:1 alpha:1]];
    spinner.frame = CGRectMake(alertContentView.frame.size.width/2-17, 80, 50, 50);
    [alertContentView addSubview:spinner];
    [customAlertView setContainerView:alertContentView];
    

    [customAlertView setButtonTitles:[NSMutableArray arrayWithObjects:nil]];

    [customAlertView setUseMotionEffects:true];
    [customAlertView show];
    
    [easylink_config configFTCClient:[configData objectForKey:@"client"]
               withConfigurationData:[NSJSONSerialization dataWithJSONObject:[configData objectForKey:@"update"] options:0 error:&err]];
}

#pragma mark - EasyLinkOTATableViewController delegate-

- (void)onStartOTA:(NSString *)otaFilePath toFTCClient:(NSNumber *)client
{
    otaAlertView = [[CustomIOS7AlertView alloc] init];
    
    UIView *alertContentView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 290, 170)];
    
    UILabel *title = [[UILabel alloc] initWithFrame:CGRectMake(alertContentView.frame.size.width/2-130, 20, 260, 25)];
    title.text = @"Please wait...";
    title.font= [UIFont boldSystemFontOfSize:19.0];
    title.textAlignment = NSTextAlignmentCenter;
    [alertContentView addSubview:title];
    
    UILabel *content = [[UILabel alloc] initWithFrame:CGRectMake(alertContentView.frame.size.width/2-130, 65, 260, 25)];
    
    NSMutableParagraphStyle *paragraphStyle = [[NSMutableParagraphStyle alloc] init];
    paragraphStyle.lineBreakMode = NSLineBreakByCharWrapping;
    paragraphStyle.alignment = NSTextAlignmentCenter;
    paragraphStyle.lineSpacing = 5.0f;
    NSDictionary *attributes = [NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:paragraphStyle,
                                                                    nil]
                                                           forKeys:[NSArray arrayWithObjects:NSParagraphStyleAttributeName,
                                                                    nil]];
    NSAttributedString *contentText =  [[NSAttributedString alloc] initWithString:@"Sending OTA data to module..."
                                                                       attributes:attributes];
    
    content.attributedText = contentText;
    content.numberOfLines = 2;
    [content setTag:0x1001];
    [alertContentView addSubview:content];
    
    CGRect frame = CGRectMake(0, 0, 50, 50);
    UIActivityIndicatorView* spinner = [[UIActivityIndicatorView alloc] initWithFrame:frame];
    [spinner startAnimating];
    spinner.activityIndicatorViewStyle = UIActivityIndicatorViewStyleWhiteLarge;
    [spinner sizeToFit];
    [spinner setColor: [UIColor colorWithRed:0 green:122.0/255 blue:1 alpha:1]];
    spinner.frame = CGRectMake(alertContentView.frame.size.width/2-17, 110, 50, 50);
    [alertContentView addSubview:spinner];
    [otaAlertView setContainerView:alertContentView];
    
    [otaAlertView setButtonTitles:[NSMutableArray arrayWithObjects:@"Cancel",nil]];
    __weak EASYLINK *_easylink_config = easylink_config;
    __weak CustomIOS7AlertView *_otaAlertView = otaAlertView;
    [otaAlertView setOnButtonTouchUpInside:^(CustomIOS7AlertView *customIOS7AlertView, NSInteger buttonIndex) {
      //  self.requestsManager = nil;
    [_easylink_config closeFTCClient: client];
      //  [self.navigationController popToViewController:[self.navigationController.viewControllers objectAtIndex:2] animated:YES];
        NSLog(@"Block: Button at position %ld is clicked on alertView %ld.", (long)buttonIndex, (long)[customIOS7AlertView tag]);
        [_otaAlertView close];
    }];
    
    [otaAlertView setUseMotionEffects:true];
    [otaAlertView show];
    
    [easylink_config otaFTCClient:client withOTAData: [NSData dataWithContentsOfFile:otaFilePath]];
}
#pragma mark - Private Methods -

/* enableUIAccess
 * enable / disable the UI access like enable / disable the textfields 
 * and other component while transmitting the packets.
 * @param: vbool is to validate the controls.
 */
-(void) enableUIAccess:(BOOL) isEnable{
    ssidField.userInteractionEnabled = isEnable;
    passwordField.userInteractionEnabled = isEnable;
    userInfoField.userInteractionEnabled = isEnable;
    ipAddress.userInteractionEnabled = isEnable;
}

/* 
 Prepare a cell that is created with respect to the indexpath 
 @param cell is an object of UITableViewcell which is newly created 
 @param indexpath  is respective indexpath of the cell of the row. 
 */
-(UITableViewCell *) prepareCell:(UITableViewCell *)cell atIndexPath:(NSIndexPath *)indexPath
{
    if ( indexPath.row == SSID_ROW ){/// this is SSID row
        NSString *SSID = [EASYLINK ssidForConnectedNetwork];
        ssidData = [EASYLINK ssidDataForConnectedNetwork];
        if(SSID == nil) SSID = @"";
        
        ssidField = [[UITextField alloc] initWithFrame:CGRectMake(CELL_IPHONE_FIELD_X,
                                                                  CELL_iPHONE_FIELD_Y,
                                                                  CELL_iPHONE_FIELD_WIDTH,
                                                                  CELL_iPHONE_FIELD_HEIGHT)];
        [ssidField setDelegate:self];
        [ssidField setClearButtonMode:UITextFieldViewModeNever];
        [ssidField setPlaceholder:@"SSID"];
        [ssidField setBackgroundColor:[UIColor clearColor]];
        [ssidField setReturnKeyType:UIReturnKeyDone];
        [ssidField setText:SSID];
        
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
        NSString *password = [apInforRecord objectForKey:ssidField.text];
        if(password == nil) password = @"";
        [passwordField setText:password];

        
        cell.textLabel.font = [UIFont boldSystemFontOfSize:15.0];
        cell.textLabel.text = @"Password";
    }
    else if ( indexPath.row == USER_INFO_ROW){
        /// this is Gateway Address field
        userInfoField = [[UITextField alloc] initWithFrame:CGRectMake(CELL_IPHONE_FIELD_X,
                                                                       CELL_iPHONE_FIELD_Y,
                                                                       CELL_iPHONE_FIELD_WIDTH,
                                                                       CELL_iPHONE_FIELD_HEIGHT)];
        [userInfoField setDelegate:self];
        [userInfoField setClearButtonMode:UITextFieldViewModeNever];
        [userInfoField setPlaceholder:@"Authenticator(Optional)"];
        [userInfoField setReturnKeyType:UIReturnKeyDone];
        [userInfoField setBackgroundColor:[UIColor clearColor]];
        
        [cell addSubview:userInfoField];
        
        cell.textLabel.font = [UIFont boldSystemFontOfSize:15.0];
        cell.textLabel.text = @"Extra Data";
    }
    else if ( indexPath.row == IP_ADDRESS_ROW){
        /// this is Gateway Address field
        ipAddress = [[UITextField alloc] initWithFrame:CGRectMake(CELL_IPHONE_FIELD_X,
                                                                  CELL_iPHONE_FIELD_Y,
                                                                  CELL_iPHONE_FIELD_WIDTH,
                                                                  CELL_iPHONE_FIELD_HEIGHT)];
        [ipAddress setDelegate:self];
        [ipAddress setClearButtonMode:UITextFieldViewModeNever];
        [ipAddress setPlaceholder:@"Auto"];
        [ipAddress setReturnKeyType:UIReturnKeyDone];
        [ipAddress setBackgroundColor:[UIColor clearColor]];
        [ipAddress setUserInteractionEnabled:NO];

        if([[deviceIPConfig objectForKey:@"DHCP"] boolValue] == YES)
            [ipAddress setText:@"Automatic"];
        else
            [ipAddress setText:[deviceIPConfig objectForKey:@"IP"]];

        [cell addSubview:ipAddress];
        
        cell.textLabel.font = [UIFont boldSystemFontOfSize:15.0];
        cell.textLabel.text = @"IP Address";
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        cell.selectionStyle = UITableViewCellSelectionStyleBlue;
    }
    return cell;
}


/* 
 Notification method handler when app enter in forground
 @param the fired notification object
 */
- (void)appEnterInforground:(NSNotification*)notification{
    NSLog(@"%s", __func__);
    if( easylink_config == nil){
        easylink_config = [[EASYLINK alloc]init];
        [easylink_config startFTCServerWithDelegate:self];
    }
    if( self.foundModules == nil)
        self.foundModules = [[NSMutableArray alloc]initWithCapacity:10];

    NetworkStatus netStatus = [wifiReachability currentReachabilityStatus];
    
    if ( netStatus != NotReachable ){
        if ( [[EASYLINK ssidForConnectedNetwork] isEqualToString: targetSsid]){
            [(UIScrollView *)easyLinkUAPSendingView.containerView scrollRectToVisible:CGRectMake( 3 * 290, 0, 290, 300) animated:YES];
            [(UIButton *)[easyLinkUAPSendingView.dialogView viewWithTag: 3] setEnabled:NO];
        }
        if ( [[EASYLINK ssidForConnectedNetwork] hasPrefix:@"EasyLink_"]){
            [(UIScrollView *)easyLinkUAPSendingView.containerView scrollRectToVisible:CGRectMake( 2 * 290, 0, 290, 300) animated:YES];
            [(UIButton *)[easyLinkUAPSendingView.dialogView viewWithTag: 3] setEnabled:NO];
        }
    }
    
    if ( netStatus != NotReachable && ![[EASYLINK ssidForConnectedNetwork] hasPrefix:@"EasyLink_"]) {
        ssidField.text = [EASYLINK ssidForConnectedNetwork];
        ipAddress.text = @"Automatic";
        ssidField.userInteractionEnabled = NO;
        
        NSString *password = [apInforRecord objectForKey:ssidField.text];
        if(password == nil) password = @"";
        [passwordField setText: password];
        
        [deviceIPConfig setObject:@YES forKey:@"DHCP"];
        [deviceIPConfig setObject:[EASYLINK getIPAddress] forKey:@"IP"];
        [deviceIPConfig setObject:[EASYLINK getNetMask] forKey:@"NetMask"];
        [deviceIPConfig setObject:[EASYLINK getGatewayAddress] forKey:@"GateWay"];
        [deviceIPConfig setObject:[EASYLINK getGatewayAddress] forKey:@"DnsServer"];
    }


    
}

/*
 Notification method handler when app enter in background
 @param the fired notification object
 */
- (void)appEnterInBackground:(NSNotification*)notification{
    NSLog(@"%s", __func__);
    
    //[easylink_config stopTransmitting];
    //[easylink_config closeFTCServer];
    //easylink_config = nil;
    //self.foundModules = nil;
    
    //[easyLinkSendingView close];
    
    //[self.navigationController popToRootViewControllerAnimated:NO];
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
    
    if ( netStatus != NotReachable ){
        if ( [[EASYLINK ssidForConnectedNetwork] isEqualToString: targetSsid]){
            [(UIScrollView *)easyLinkUAPSendingView.containerView scrollRectToVisible:CGRectMake( 3 * 290, 0, 290, 300) animated:YES];
            [(UIButton *)[easyLinkUAPSendingView.dialogView viewWithTag: 3] setEnabled:NO];
        }
        if ( [[EASYLINK ssidForConnectedNetwork] hasPrefix:@"EasyLink_"]){
            [(UIScrollView *)easyLinkUAPSendingView.containerView scrollRectToVisible:CGRectMake( 2 * 290, 0, 290, 300) animated:YES];
            [(UIButton *)[easyLinkUAPSendingView.dialogView viewWithTag: 3] setEnabled:NO];
        }
    }
    
    if ( netStatus != NotReachable && ![[EASYLINK ssidForConnectedNetwork] hasPrefix:@"EasyLink_"]) {
        ssidField.text = [EASYLINK ssidForConnectedNetwork];
        ssidData = [EASYLINK ssidDataForConnectedNetwork];
        NSString *password = [apInforRecord objectForKey:ssidField.text];
        if(password == nil) password = @"";
        [passwordField setText:password];
        
        [deviceIPConfig setObject:@YES forKey:@"DHCP"];
        [deviceIPConfig setObject:[EASYLINK getIPAddress] forKey:@"IP"];
        [deviceIPConfig setObject:[EASYLINK getNetMask] forKey:@"NetMask"];
        [deviceIPConfig setObject:[EASYLINK getGatewayAddress] forKey:@"GateWay"];
        [deviceIPConfig setObject:[EASYLINK getGatewayAddress] forKey:@"DnsServer"];
    }
}


- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
    if ([[segue identifier] isEqualToString:@"IP config"]) {
        [[segue destinationViewController] setDeviceIPConfig: deviceIPConfig];
    }
    else if ([[segue identifier] isEqualToString:@"New Devices"]) {
        foundTableViewController = [segue destinationViewController];
        [foundTableViewController setFoundModules: self.foundModules];
        [foundTableViewController setDelegate:self];
        [foundTableViewController setEasylink_config:easylink_config];
    }
}


@end
