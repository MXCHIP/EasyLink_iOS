//
//  wifiDeviceDetailTableViewController.swift
//  MICO
//
//  Created by William Xu on 2020/2/7.
//  Copyright © 2020 MXCHIP Co;Ltd. All rights reserved.
//

//import Foundation

enum detailCellIdentifier{
    
}


class wifiDeviceDetailViewController: UITableViewController {
    @IBOutlet weak var wifiDeviceDetailTable: UITableView!
    
    
    private var _majourInfo: [detail] = []
    private var _txtRecordArray: [detail] = []
    private var _detailSections: [[detail]] = []
    private var _detailCellIdentifiers: [String] = ["Major info", "Txt record"]
    
    override func awakeFromNib() {
        _detailSections = [_majourInfo, _txtRecordArray]
    }
    // MARK: - Table view data source
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        return _detailSections.count
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        // Return the number of rows in the section.
        return _detailSections[section].count
    }

    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let section = indexPath.section
        let row = indexPath.row
        let cell = tableView.dequeueReusableCell(withIdentifier: _detailCellIdentifiers[section], for: indexPath)
        
        let detail: [String : String] = _detailSections[section][row]
        cell.textLabel!.text = (_detailSections[section])[row].
        cell.detailTextLabel!.text =
        return cell
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
@interface bonjourDetailTableViewController : UITableViewController{
    IBOutlet UITableView *bonjourDetailTable;
@private
    NSDictionary *_txtRecord;
    NSString *_address;
    NSString *_hostName;
    NSString *_name;
    NSString *_port;
    NSMutableArray *_majourInfo;
    NSMutableArray *_txtRecordArray;
    AsyncSocket *configSocket;
    CustomIOSAlertView *customAlertView, *otaAlertView;
    CFHTTPMessageRef inComingMessage;
    NSMutableDictionary *configData;
    NSData *updateData;
    NSData *otaData;
    _ConfigState_t currentState;
 */
}

/*
@interface bonjourDetailTableViewController ()

-(void)showConnectingAlert;
-(void)sendUpdateData;
-(void)sendOtaData;


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
    
    currentState = eState_start;
    
    //// stoping the process in app backgroud state
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(appEnterInBackground:) name:UIApplicationDidEnterBackgroundNotification object:nil];
    
    // Uncomment the following line to preserve selection between presentations.
    // self.clearsSelectionOnViewWillAppear = NO;
    
    // Uncomment the following line to display an Edit button in the navigation bar for this view controller.
    // self.navigationItem.rightBarButt onItem = self.editButtonItem;
}

- (void)viewWillDisappear:(BOOL)animated{
    if([self.navigationController.viewControllers indexOfObject:self] == NSNotFound){
        if(configSocket){
            [configSocket disconnect];
            [configSocket setDelegate:nil];
            configSocket = nil;
        }
    }
}

- (void)viewDidUnload {
    [super viewDidUnload];
    // Release any retained subviews of the main view.
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    NSLog(@"%@ dealloced", [self class]);
    
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
        self.navigationItem.title = @"Details";
    
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

    configSocket = [[AsyncSocket alloc] initWithDelegate:self];
    
    [configSocket connectToHost:_address onPort:8000 withTimeout:4.0 error:&err];
    currentState = eState_ReadConfig;
    [self showConnectingAlert];
}


#pragma mark - AsyncSocket delegate

- (void)onSocket:(AsyncSocket *)sock didConnectToHost:(NSString *)host port:(UInt16)port
{
    NSLog(@"connected");
    if(customAlertView){
        [customAlertView close];
        customAlertView = nil;
    }
    
    inComingMessage = CFHTTPMessageCreateEmpty(kCFAllocatorDefault, TRUE);
    
    if(currentState == eState_ReadConfig){
        CFURLRef urlRef = CFURLCreateWithString(kCFAllocatorDefault, CFSTR("/config-read"), NULL);
        CFHTTPMessageRef httpRequestMessage = CFHTTPMessageCreateRequest (kCFAllocatorDefault,
                                                                          CFSTR("GET"),
                                                                          urlRef,
                                                                          kCFHTTPVersion1_1);
        CFHTTPMessageSetHeaderFieldValue(httpRequestMessage, CFSTR("Connection"), CFSTR("close"));
        CFDataRef httpData = CFHTTPMessageCopySerializedMessage ( httpRequestMessage );
        [sock writeData:(__bridge NSData*)httpData withTimeout:-1 tag:0];
        CFRelease(httpData);
        CFRelease(httpRequestMessage);
        CFRelease(urlRef);
        
        [sock readDataWithTimeout:-1 tag:0];
    }
    else if (currentState == eState_WriteConfig){
        [self sendUpdateData];
    }
    else if (currentState == eState_SendOTAData){
        [self sendOtaData];
    }
}

- (void)onSocket:(AsyncSocket *)sock didReadData:(NSData *)data withTag:(long)tag
{
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
    contentLength = [(__bridge NSString*)contentLengthRef intValue];
    
    currentLength = [body length];
    NSLog(@"%lu/%lu", (unsigned long)currentLength, (unsigned long)contentLength);
    
    if(currentLength < contentLength){
        [sock readDataToLength:(contentLength-currentLength) withTimeout:100 tag:(long)tag];
        return;
    }
    
#ifdef DEBUG
    CFURLRef urlRef = CFHTTPMessageCopyRequestURL(inComingMessage);
    CFStringRef urlPathRef= CFURLCopyPath (urlRef);
    NSString *urlPath= (__bridge NSString*)urlPathRef;
    NSLog(@"URL: %@", urlPath);
    CFRelease(urlRef);
    CFRelease(urlPathRef);
#endif
    
    if(currentState == eState_ReadConfig){
        configData = [NSJSONSerialization JSONObjectWithData:body
                                                      options:NSJSONReadingMutableContainers|NSJSONReadingMutableLeaves
                                                        error:&err];
        NSLog(@"Recv JSON data, length: %lu", (unsigned long)[body length]);
        
        if (err) {
#ifdef DEBUG
            NSString *temp = [[NSString alloc] initWithData:body encoding:NSASCIIStringEncoding];
            NSLog(@"Unpackage JSON data failed:%@, %@", [err localizedDescription], temp);
#endif
            alertView = [[UIAlertView alloc] initWithTitle:@"Get unrecognized data!" message:nil delegate:Nil cancelButtonTitle:@"OK" otherButtonTitles: nil];
            [alertView show];
            return;
        }
        
        [configData setValue:[NSNumber numberWithInteger:0] forKey:@"client"];
        updateSettings = [NSMutableDictionary dictionaryWithCapacity:10];
        [configData setValue:updateSettings forKey:@"update"];
        [self performSegueWithIdentifier:@"Configuration" sender:nil];
    }
    else if(currentState == eState_WriteConfig){
        if(customAlertView){
            [customAlertView close];
            customAlertView = nil;
        }
        if(CFHTTPMessageGetResponseStatusCode(inComingMessage) == 200){
            alertView = [[UIAlertView alloc] initWithTitle:@"Update module success!" message:nil delegate:Nil cancelButtonTitle:@"OK" otherButtonTitles: nil];
            [alertView show];
        }
        else{
            alertView = [[UIAlertView alloc] initWithTitle:@"Update module failed!" message:nil delegate:Nil cancelButtonTitle:@"OK" otherButtonTitles: nil];
            [alertView show];
        }
        [self.navigationController popToRootViewControllerAnimated:YES];
        [configSocket disconnect];
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
    NSLog(@"disconnected");
    if(inComingMessage) {
        CFRelease(inComingMessage);
        inComingMessage = NULL;
    }
    
    if(otaAlertView != nil){
        [otaAlertView close];
        otaAlertView = nil;
    }
    sock = nil;
    if(currentState == eState_SendOTAData){
        [self.navigationController popToRootViewControllerAnimated:YES];
    }
    
    currentState = eState_start;
    
}

-(void)showConnectingAlert
{
    customAlertView = [[CustomIOSAlertView alloc] init];
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
    [customAlertView setOnButtonTouchUpInside:^(CustomIOSAlertView *alertView, int buttonIndex) {
        [_tempsocket disconnect];
        NSLog(@"Block: Button at position %ld is clicked on alertView %ld.", (long)buttonIndex, (long)[alertView tag]);
        [alertView close];
        alertView = nil;
    }];
    
    [customAlertView setUseMotionEffects:true];
    [customAlertView show];
}

#pragma mark - EasyLinkFTCTableViewController delegate

- (void)onConfigured:(NSMutableDictionary *)data
{
    NSError *err;
    UIAlertView *alertView;
    
    updateData = [NSJSONSerialization dataWithJSONObject:[data objectForKey:@"update"]options:0 error:&err];
    if (err) {
        alertView = [[UIAlertView alloc] initWithTitle:@"Get unrecognized data!" message:nil delegate:Nil cancelButtonTitle:@"OK" otherButtonTitles: nil];
        [alertView show];
        return;
    }
    
    customAlertView = [[CustomIOSAlertView alloc] init];
    
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
    
    
    [customAlertView setButtonTitles:[NSMutableArray arrayWithCapacity:3]];
    
    [customAlertView setUseMotionEffects:true];
    [customAlertView show];
    
    currentState = eState_WriteConfig;
    if([configSocket isConnected] == true){
       [self sendUpdateData];
    }else{
        inComingMessage = CFHTTPMessageCreateEmpty(kCFAllocatorDefault, TRUE);
        configSocket = [[AsyncSocket alloc] initWithDelegate:self];
        [configSocket connectToHost:_address onPort:8000 withTimeout:4.0 error:&err];
    }
}

- (void)onStartOTA:(NSString *)otaFilePath toFTCClient:(NSNumber *)client
{
    NSError *err;
    otaAlertView = [[CustomIOSAlertView alloc] init];
    
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
    __weak AsyncSocket *_configSocket = configSocket;
    __weak CustomIOSAlertView *_otaAlertView = otaAlertView;
    [otaAlertView setOnButtonTouchUpInside:^(CustomIOSAlertView *customIOS7AlertView, int buttonIndex) {
        //  self.requestsManager = nil;
        [_configSocket disconnect];
        [_configSocket setDelegate:nil];
        //  [self.navigationController popToViewController:[self.navigationController.viewControllers objectAtIndex:2] animated:YES];
        NSLog(@"Block: Button at position %ld is clicked on alertView %ld.", (long)buttonIndex, (long)[customIOS7AlertView tag]);
        [_otaAlertView close];
    }];
    
    [otaAlertView setUseMotionEffects:true];
    [otaAlertView show];
    
    otaData = [NSData dataWithContentsOfFile:otaFilePath];

    currentState = eState_SendOTAData;
    if([configSocket isConnected] == true){
        [self sendOtaData];
    }else{
        inComingMessage = CFHTTPMessageCreateEmpty(kCFAllocatorDefault, TRUE);
        configSocket = [[AsyncSocket alloc] initWithDelegate:self];
        [configSocket connectToHost:_address onPort:8000 withTimeout:4.0 error:&err];
    }
}

-(void)sendOtaData
{
    NSLog(@"Sending OTA data");
    char contentLen[50];
    
    CFURLRef urlRef = CFURLCreateWithString(kCFAllocatorDefault, CFSTR("/OTA"), NULL);
    CFHTTPMessageRef  httpRequestMessage = CFHTTPMessageCreateRequest ( kCFAllocatorDefault,
                                                                       CFSTR("POST"), urlRef, kCFHTTPVersion1_1 );
    CFHTTPMessageSetHeaderFieldValue(httpRequestMessage, CFSTR("Content-Type"), CFSTR("application/ota-stream"));
    
    snprintf(contentLen, 50, "%lu", (unsigned long)[otaData length]);
    
    CFStringRef length = CFStringCreateWithCString(kCFAllocatorDefault, contentLen, kCFStringEncodingASCII);
    CFHTTPMessageSetHeaderFieldValue(httpRequestMessage, CFSTR("Connection"), CFSTR("close"));
    CFHTTPMessageSetHeaderFieldValue(httpRequestMessage, CFSTR("Content-Length"),length);
    CFHTTPMessageSetBody(httpRequestMessage, (__bridge CFDataRef)otaData);
    
    CFDataRef httpData = CFHTTPMessageCopySerializedMessage ( httpRequestMessage );
    [configSocket writeData:(__bridge NSData*)httpData withTimeout:-1 tag:0];
    CFRelease(httpData);
    CFRelease(httpRequestMessage);
    CFRelease(urlRef);
    CFRelease(length);
    
    /*Recv data that server can send FIN+ACK when client disconnect*/
    [configSocket readDataWithTimeout:-1 tag:0];
}


-(void)sendUpdateData
{
    NSLog(@"Send config data.");
    char contentLen[50];
    
    CFURLRef urlRef = CFURLCreateWithString(kCFAllocatorDefault, CFSTR("/config-write"), NULL);
    CFHTTPMessageRef httpRequestMessage = CFHTTPMessageCreateRequest (kCFAllocatorDefault,
                                                                      CFSTR("POST"),
                                                                      urlRef,
                                                                      kCFHTTPVersion1_1);
    CFHTTPMessageSetHeaderFieldValue(httpRequestMessage, CFSTR("Content-Type"), CFSTR("application/json"));
    snprintf(contentLen, 50, "%lu", (unsigned long)[updateData length]);
    CFStringRef length = CFStringCreateWithCString(kCFAllocatorDefault, contentLen, kCFStringEncodingASCII);
    CFHTTPMessageSetHeaderFieldValue(httpRequestMessage, CFSTR("Connection"), CFSTR("close"));
    CFHTTPMessageSetHeaderFieldValue(httpRequestMessage, CFSTR("Content-Length"),length);
    CFHTTPMessageSetBody(httpRequestMessage, (__bridge CFDataRef)updateData);
    
    CFDataRef httpData = CFHTTPMessageCopySerializedMessage ( httpRequestMessage );
    [configSocket writeData:(__bridge NSData*)httpData withTimeout:-1 tag:0];
    CFRelease(httpData);
    CFRelease(httpRequestMessage);
    CFRelease(urlRef);
    CFRelease(length);
    
    [configSocket readDataWithTimeout:-1 tag:0];
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
 Notification method handler when app enter in background
 @param the fired notification object
 */
- (void)appEnterInBackground:(NSNotification*)notification{
    NSLog(@"%s", __func__);
    
    [configSocket disconnect];
    [configSocket setDelegate:nil];
    configSocket = nil;
    [self.navigationController popToRootViewControllerAnimated:NO];
}


#pragma mark - Navigation

 - (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
 {
     if ([[segue identifier] isEqualToString:@"Configuration"]) {
        [[segue destinationViewController] setConfigData:configData];
        [(EasyLinkFTCTableViewController *)[segue destinationViewController] setDelegate:self];
     }
 }

@end
*/
