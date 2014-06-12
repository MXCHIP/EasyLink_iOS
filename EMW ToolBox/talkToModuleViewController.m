//
//  talkToModuleViewController.m
//  MICO
//
//  Created by William Xu on 14-5-8.
//  Copyright (c) 2014年 MXCHIP Co;Ltd. All rights reserved.
//

#import "talkToModuleViewController.h"
#import "messageViewController.h"
#import "Protocols.h"


@interface talkToModuleViewController ()

-(void)showConnectingAlert;

@end

@implementation talkToModuleViewController
@synthesize socket = _socket;

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Custom initialization
    }
    return self;
}

- (void)awakeFromNib {
    [super awakeFromNib];
    
    self.useNavigationBarButtonItemsOfCurrentViewController = YES;
    self.useToolbarItemsOfCurrentViewController = YES;
    
    NSMutableArray *initialViewController = [NSMutableArray array];
    message = [self.storyboard instantiateViewControllerWithIdentifier:@"message view"];
    commandVC = [self.storyboard instantiateViewControllerWithIdentifier:@"command view"];
    
    [initialViewController addObject:message];
    [initialViewController addObject:commandVC];

    self.viewController = initialViewController;
}

- (void)dealloc{
    self.viewController = nil;
    [message releaseDelegate];
    NSLog(@"dealloc <== talk to module");
}

- (void) viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
    [customAlertView close];
    socket.delegate = nil;
    [socket disconnect];
}

- (void)setService:(NSNetService *)newService
{
    if (_service != newService) {
        _service = newService;
        
        _address = [[[newService addresses] objectAtIndex: 0] host];
        _port = [newService port];
        NSDictionary *txtRecordDict = [NSNetService dictionaryFromTXTRecordData: [newService TXTRecordData]];
        
        _protocol = [[NSString alloc] initWithData:[txtRecordDict objectForKey:@"Protocol"]
                                          encoding:NSUTF8StringEncoding];
        _module = [[NSString alloc] initWithData: [txtRecordDict objectForKey:@"Model"]
                                         encoding:NSASCIIStringEncoding];
        
        message.inComingAvatarImage = [UIImage imageNamed:[NSString stringWithFormat:@"%@.png", _module]];
        if(message.inComingAvatarImage==nil)
            message.inComingAvatarImage = [UIImage imageNamed:@"known_logo.png"];
        
        message.outGoingAvatarImage = [UIImage imageNamed:@"demo-avatar-ai.png"];

        _name = [newService name];
        
        [commandVC setProtocol:_protocol];
        
        message.messageRecordFileName = [[NSString alloc] initWithData:[txtRecordDict objectForKey:@"MAC"]
                                                               encoding:NSUTF8StringEncoding];
        
        
    }
}

- (void)viewDidLoad
{
    NSError *err;
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    socket = [[AsyncSocket alloc] initWithDelegate:self];
    [socket connectToHost:_address onPort:_port error:&err];
    
    [self showConnectingAlert];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(appEnterInBackground:) name:UIApplicationDidEnterBackgroundNotification object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(appEnterInforground:) name:UIApplicationWillEnterForegroundNotification object:nil];
    
    isInforground = YES;

}

-(void)showConnectingAlert
{
    customAlertView = [[CustomIOS7AlertView alloc] init];
    NSString *alertContent = [NSString stringWithFormat:@"Connecting to %@ on port %ld ...", _address, (long)_port];
    
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
    __weak UINavigationController *_nav = self.navigationController;
    __weak AsyncSocket *_tempsocket = self.socket;
    [customAlertView setOnButtonTouchUpInside:^(CustomIOS7AlertView *alertView, NSInteger buttonIndex) {
        [_tempsocket disconnect];
        [_nav popToRootViewControllerAnimated:YES];
        NSLog(@"Block: Button at position %ld is clicked on alertView %ld.", (long)buttonIndex, (long)[alertView tag]);
        [alertView close];
    }];
    
    [customAlertView setUseMotionEffects:true];
    [customAlertView show];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - AsyncSocket delegate

- (void)onSocket:(AsyncSocket *)sock didConnectToHost:(NSString *)host port:(UInt16)port
{
    NSLog(@"connected");
    [customAlertView close];
    [sock readDataWithTimeout:-1 tag:0];
}

- (void)onSocket:(AsyncSocket *)sock didReadData:(NSData *)data withTag:(long)tag
{
    //CGFloat hue,saturation,brightness,alpha;
    NSArray *inDaraArray;
    NSLog(@"read data success");
    inDaraArray = [NSData dataDecodeFromData:data usingProrocol: _protocol];
    for(NSData *data in inDaraArray){
        [message recvInComingData: data];
    }

    [sock readDataWithTimeout:-1 tag:0];

}

- (void)sendData: (NSData *)data from: (UIView *)sender
{
    NSData *outData = [NSData  dataEncodeWithData:data usingProrocol:_protocol];
    
    if([sender isKindOfClass: [commandsTableViewController class]]){
        [message recvOutputData:data];
    }

    NSLog(@"Send data.....");
    if([socket isConnected])
        [socket writeData:outData withTimeout:5 tag:0];
}

- (void)onSocketDidDisconnect:(AsyncSocket *)sock
{
    NSError *err;
    NSLog(@"disconnected");
    if(isInforground == YES)
        [socket connectToHost:_address onPort:_port error:&err];
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

/*
 Notification method handler when app enter in forground
 @param the fired notification object
 */
- (void)appEnterInforground:(NSNotification*)notification{
    NSError *err;
    isInforground = YES;
    [self showConnectingAlert];
    [socket connectToHost:_address onPort:_port error:&err];
    
}

/*
 Notification method handler when app enter in background
 @param the fired notification object
 */
- (void)appEnterInBackground:(NSNotification*)notification{
    isInforground = NO;
    [socket disconnect];
}

@end
