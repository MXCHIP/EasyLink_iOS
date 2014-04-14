//
//  mxchipMasterViewController.m
//  EMW ToolBox
//
//  Created by William Xu on 13-7-26.
//  Copyright (c) 2013年 MXCHIP Co;Ltd. All rights reserved.
//

#import "browserViewController.h"
#import "mxchipDetailViewController.h"
#include "moduleBrowserCell.h"
#import <sys/socket.h> 
#import <netinet/in.h>
#include <arpa/inet.h>

#define searchingString @"Searching for MXCHIP Modules..."
#define kWebServiceType @"_easylink._tcp"
#define kInitialDomain  @"local"
#define repeatInterval  10.0



bool newModuleFound;
bool enumerating = NO;

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

@interface NSMutableDictionary (BrowserViewControllerAdditions)
- (NSComparisonResult) localizedCaseInsensitiveCompareByName:(NSMutableDictionary*)aService;
@end

@implementation NSMutableDictionary (BrowserViewControllerAdditions)
- (NSComparisonResult) localizedCaseInsensitiveCompareByName:(NSMutableDictionary*)aService {
	return [[self objectForKey:@"Name"] localizedCaseInsensitiveCompare:[aService objectForKey:@"Name"]];
}
@end


@interface browserViewController()
@property (nonatomic, retain, readwrite) NSNetServiceBrowser* netServiceBrowser;
@property (nonatomic, retain, readwrite) NSMutableArray* services;
@property (nonatomic, retain, readwrite) NSMutableArray* displayServices;
@property (nonatomic, retain, readwrite) NSTimer* timer;
@property (nonatomic, assign, readwrite) BOOL initialWaitOver;

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

@end

@implementation browserViewController
@synthesize netServiceBrowser = _netServiceBrowser;
@synthesize services = _services;
@synthesize displayServices = _displayServices;
@dynamic timer;
@synthesize initialWaitOver = _initialWaitOver;

- (void)awakeFromNib
{
    sleep(1);
    [super awakeFromNib];
}

- (void)viewDidLoad
{
    [super viewDidLoad];

	_services = [[NSMutableArray alloc] init];
    _displayServices = [[NSMutableArray alloc] init];
    selectedModule = [[NSMutableArray alloc] initWithCapacity:100];
    UIBarButtonItem *backItem = [[UIBarButtonItem alloc] initWithTitle:@"Modules" style:UIBarButtonItemStyleBordered target:nil action:nil];
    [self.navigationItem setBackBarButtonItem:backItem];
    [ledControllerSlider setUserInteractionEnabled: NO];
    
    NSNetServiceBrowser *aNetServiceBrowser = [[NSNetServiceBrowser alloc] init];
	if(!aNetServiceBrowser) {
        // The NSNetServiceBrowser couldn't be allocated and initialized.
		NSLog(@"Network service error!");
	}
	aNetServiceBrowser.delegate = self;
	self.netServiceBrowser = aNetServiceBrowser;
                
	// Make sure we have a chance to discover devices before showing the user that nothing was found (yet)
    //[self repeatSearching: self.timer];
    //self.timer = [NSTimer scheduledTimerWithTimeInterval:repeatInterval target:self selector:@selector(repeatSearching:) userInfo:nil repeats:NO];
    [browserTableView reloadData];
    browserTableView.allowsMultipleSelection = YES;
    [NSTimer scheduledTimerWithTimeInterval:1.0 target:self selector:@selector(initialWaitOver:) userInfo:nil repeats:NO];
    //[self.netServiceBrowser stop];
    [self.netServiceBrowser searchForServicesOfType:kWebServiceType inDomain:kInitialDomain];
    
    //// stoping the process in app backgroud state
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(appEnterInBackground:) name:UIApplicationDidEnterBackgroundNotification object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(appEnterInforground:) name:UIApplicationWillEnterForegroundNotification object:nil];

}

- (void)viewWillAppear:(BOOL)animated
{
}


- (void)initialWaitOver:(NSTimer*)timer {
	self.initialWaitOver= YES;
	if (![self.displayServices count])
		[browserTableView reloadData];
}


- (IBAction)refreshService:(UIBarButtonItem*)button
{
    [self searchForModules];
}

- (void)searchForModules
{
	self.initialWaitOver = NO;
    [self.netServiceBrowser stop];
	[self.services removeAllObjects];
    for(NSMutableDictionary *object in self.displayServices){
        if([object objectForKey:@"Socket"]!=nil){
            [[object objectForKey:@"Socket"] disconnect];
            [[object objectForKey:@"Socket"] setDelegate:nil];
            [object removeObjectForKey:@"Socket"];
        }
    }
    [self.displayServices removeAllObjects];
    [selectedModule removeAllObjects];
    [browserTableView reloadData];
    [ledControllerSlider setUserInteractionEnabled: NO];
    [self.netServiceBrowser searchForServicesOfType:kWebServiceType inDomain:kInitialDomain];
    [NSTimer scheduledTimerWithTimeInterval:1.0 target:self selector:@selector(initialWaitOver:) userInfo:nil repeats:NO];
	
    //UIColor
}

- (NSTimer *)timer {
	return _timer;
}

// When this is called, invalidate the existing timer before releasing it.
- (void)setTimer:(NSTimer *)newTimer {
	[_timer invalidate];
	_timer = newTimer;
}


- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


- (void)sortAndUpdateUI {
	// Sort the services by name.
    while(enumerating == YES);
	[self.services sortUsingSelector:@selector(localizedCaseInsensitiveCompareByName:)];
    [self.displayServices sortUsingSelector:@selector(localizedCaseInsensitiveCompareByName:)];
	[browserTableView reloadData];
}

#pragma mark - NSNetServiceBrowserDelegate

- (void)netServiceBrowserDidStopSearch:(NSNetServiceBrowser *)netServiceBrowser
{
    //NSLog(@"Service Search stoped");
}

- (void)netServiceBrowserWillSearch:(NSNetServiceBrowser *)netServiceBrowser
{
    //NSLog(@"Service Search will start");
}

- (void)netServiceBrowser:(NSNetServiceBrowser*)netServiceBrowser didRemoveService:(NSNetService*)service moreComing:(BOOL)moreComing {
	// If a service went away, stop resolving it if it's currently being resolved,
	// remove it from the list and update the table view if no more events are queued.

    for (NSMutableDictionary *object in self.services)
    {
        if([[object objectForKey:@"Name"] isEqual:[service name]]){
            [[object objectForKey:@"BonjourService"] stop];
            [self.services removeObject:object];
            break;
        }
    }
    
    for (NSMutableDictionary *object in self.displayServices)
    {
        if([[object objectForKey:@"Name"] isEqual:[service name]]){
            [self.displayServices removeObject:object];
            break;
        }
    }
	
	// If moreComing is NO, it means that there are no more messages in the queue from the Bonjour daemon, so we should update the UI.
	// When moreComing is set, we don't update the UI so that it doesn't 'flash'.
	if (!moreComing) {
		[self sortAndUpdateUI];
	}
}


- (void)netServiceBrowser:(NSNetServiceBrowser*)netServiceBrowser didFindService:(NSNetService*)service moreComing:(BOOL)moreComing {
	// If a service came online, add it to the list and update the table view if no more events are queued.
    NSMutableDictionary *moduleService = [[NSMutableDictionary alloc] initWithCapacity:15];
    service.delegate = self;
    [moduleService setObject:[service name] forKey:@"Name"];
    [moduleService setObject:service forKey:@"BonjourService"];
    [moduleService setObject:@YES forKey:@"resolving"];
    [service startMonitoring];
    
    
    enumerating = YES;
    for (NSMutableDictionary *object in self.services)
    {
        if([[object objectForKey:@"Name"] isEqual:[service name]]){
            enumerating = NO;
            return;
        }
    }
    enumerating = NO;
    
    NSLog(@"service found %@",[service name]);
    newModuleFound = YES;
    [self.services addObject:moduleService];
    [service resolveWithTimeout:0.0];
}

- (void)repeatSearching:(NSTimer*)timer {
	if (timer == self.timer) {
        NSLog(@"Start searching");
        [self.netServiceBrowser stop];
        [self.netServiceBrowser searchForServicesOfType:kWebServiceType inDomain:kInitialDomain];
	}
}


#pragma mark - NSNetServiceDelegate
// This should never be called, since we resolve with a timeout of 0.0, which means indefinite
- (void)netService:(NSNetService *)sender didNotResolve:(NSDictionary *)errorDict {
	[browserTableView reloadData];
}


-(void) replaceDisaplyObjectAtIndex:(NSUInteger)idx withObject:(id)object
{
    AsyncSocket *socket;
    NSError *err;
    NSData *ipAddress = nil;
    
    NSNetService *service = [object objectForKey:@"BonjourService"];
    if([[service addresses] count])
        ipAddress = [[service addresses] objectAtIndex:0];
    
    NSMutableDictionary *displayService = nil;
    displayService = [self.displayServices objectAtIndex:idx];
    socket = [displayService objectForKey:@"Socket"];
    [socket disconnect];
    [socket setDelegate:nil];
    [displayService removeObjectForKey:@"Socket"];

    [object setObject:@YES forKey:@"Connecting"];
    socket = [[AsyncSocket alloc] initWithDelegate:self];
    [socket connectToHost:[ipAddress host] onPort:service.port error:&err];
    [object setObject:socket forKey:@"Socket"];
    
    
    [self.displayServices replaceObjectAtIndex:idx withObject:object];
}

-(void) addDisaplyObject:(id)object
{
    AsyncSocket *socket;
    NSError *err;
    NSData *ipAddress = nil;
    
    NSNetService *service = [object objectForKey:@"BonjourService"];
    if([[service addresses] count])
        ipAddress = [[service addresses] objectAtIndex:0];
    
    [object setObject:@YES forKey:@"Connecting"];
    socket = [[AsyncSocket alloc] initWithDelegate:self];
    [socket connectToHost:[ipAddress host] onPort:service.port error:&err];
    [object setObject:socket forKey:@"Socket"];
    
    
    [self.displayServices addObject:object];
}



- (void)netServiceDidResolveAddress:(NSNetService *)service
{
    NSDictionary *oldTxtData, *newTxtData;
    NSIndexPath* indexPath;
    NSData *oldMac, *newMac;
    char oldSeed_Char[10];
    char newSeed_Char[10];
    int oldSeed, newSeed;
    NSMutableDictionary *replaceService = nil;;
    
    newTxtData = [NSNetService dictionaryFromTXTRecordData: [service TXTRecordData]];
    newMac = [newTxtData objectForKey:@"MAC"];
    [[newTxtData objectForKey:@"Seed"] getBytes: newSeed_Char length:10];
    newSeed = atoi(newSeed_Char);
    
    NSLog(@"==============service info:%@=======================",[service name]);

    while (enumerating == YES);
    
    enumerating = YES;
    
    for (NSMutableDictionary *object in self.services)
    {
        if([object objectForKey:@"BonjourService"] == service){
            [object setObject:@NO forKey:@"resolving"];
            for (NSMutableDictionary *displayObject in self.displayServices) {
                if([displayObject objectForKey:@"BonjourService"] == service){
                    NSLog(@"Found an old service, %@, same service name, ignore...",
                          [[displayObject objectForKey:@"BonjourService"] name]);
                    goto exit;
                }
                oldTxtData = [NSNetService dictionaryFromTXTRecordData: [[displayObject objectForKey:@"BonjourService"] TXTRecordData]];
                oldMac = [oldTxtData objectForKey:@"MAC"];

                if([oldMac isEqualToData:newMac]== YES){
                    [[oldTxtData objectForKey:@"Seed"] getBytes: oldSeed_Char length:10];
                    oldSeed = atoi(oldSeed_Char);
                    NSLog(@"New seed: %d, old seed: %d", newSeed, oldSeed);
                    if(newSeed>=oldSeed){
                        NSLog(@"Found an old service, %@, same MAC address, seed updated, replace...",
                              [[displayObject objectForKey:@"BonjourService"] name]);
                        indexPath = [NSIndexPath indexPathForRow:[self.displayServices indexOfObject:displayObject] inSection:0];
                        NSLog(@"Replace index %lu...",(unsigned long)[self.displayServices indexOfObject:displayObject]);
                        replaceService = object;
                    }else{
                        NSLog(@"Found an old service, %@, same MAC address, old seed, ignore...",
                              [[displayObject objectForKey:@"BonjourService"] name]);
                        goto exit;
                    }
                }
            }
            
            if(replaceService!=nil){
                //AsyncSocket *socket
                NSLog(@"Replace index %ld...",(long)indexPath.row);
                [self replaceDisaplyObjectAtIndex:indexPath.row withObject:replaceService];
            }
            else{
                [self addDisaplyObject:object];
            }
            
            [self.displayServices sortUsingSelector:@selector(localizedCaseInsensitiveCompareByName:)];
            indexPath = [NSIndexPath indexPathForRow:[self.displayServices indexOfObject:object] inSection:0];
            //
            NSLog(@"resolve success! service found at %ld,service info:%@",
                  (long)indexPath.row,[service name]);
            if((self.initialWaitOver== YES&&[self.displayServices count]==1)||replaceService!=nil){ //update a searching row
                NSLog(@"!!!!!");
                [browserTableView reloadRowsAtIndexPaths:[NSArray arrayWithObject:indexPath] withRowAnimation:UITableViewRowAnimationNone];
            }
            else
                [browserTableView insertRowsAtIndexPaths:[NSArray arrayWithObject:indexPath] withRowAnimation:UITableViewRowAnimationNone];
            
            
            break;
        }
    }
exit:
    NSLog(@"=============================================================");
    enumerating = NO;
}

- (void)netService:(NSNetService *)service didUpdateTXTRecordData:(NSData *)data
{
    NSDictionary *oldTxtData, *newTxtData;
    NSData *oldSeed, *newSeed;
    
    newTxtData = [NSNetService dictionaryFromTXTRecordData:data];
    newSeed = [newTxtData objectForKey:@"Seed"];
    
    enumerating = YES;
    for (NSMutableDictionary *object in self.displayServices)
    {
        if([object objectForKey:@"BonjourService"] == service){
            oldTxtData = [NSNetService dictionaryFromTXTRecordData:[service TXTRecordData]];
            oldSeed = [oldTxtData objectForKey:@"Seed"];
            if(oldSeed==nil)
                return;
            
            if([oldSeed isEqualToData:newSeed]== NO)
               newModuleFound = YES;
            break;
        }
    }
    enumerating = NO;
}

#pragma mark - Table View

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
	NSUInteger count = [self.displayServices count];
	if (count == 0 && self.initialWaitOver)
		return 1;
    
	return count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {

    NSUInteger count = [self.displayServices count];

	if (count == 0) {
        static NSString *tableCellIdentifier = @"Searching";
        UITableViewCell *cell = (UITableViewCell *)[tableView dequeueReusableCellWithIdentifier:tableCellIdentifier];
        if (cell == nil) {
            cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:tableCellIdentifier];
        }
        // If there are no services and searchingForServicesString is set, show one row explaining that to the user.
       // cell.
        cell.textLabel.text = searchingString;
		cell.textLabel.textColor = [UIColor colorWithWhite:0.5 alpha:0.5];
		cell.accessoryType = UITableViewCellAccessoryNone;
		// Make sure to get rid of the activity indicator that may be showing if we were resolving cell zero but
		// then got didRemoveService callbacks for all services (e.g. the network connection went down).
		if (cell.accessoryView)
			cell.accessoryView = nil;
		return cell;
	}
    
    static NSString *tableCellIdentifier2 = @"ModuleCell";

	moduleBrowserCell *cell = (moduleBrowserCell *)[tableView dequeueReusableCellWithIdentifier:tableCellIdentifier2];
	if (cell == nil) {
		cell = [[moduleBrowserCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:tableCellIdentifier2];
	}
    
    cell.moduleService = [self.displayServices objectAtIndex:indexPath.row];
	return cell;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
        return 80;
}


- (NSIndexPath *)tableView:(UITableView *)tableView willSelectRowAtIndexPath:(NSIndexPath *)indexPath {
	// Ignore the selection if there are no services as the searchingForServicesString cell
	// may be visible and tapping it would do nothing
	if ([self.displayServices count] == 0)
		return nil;
	
	return indexPath;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    //moduleBrowserCell *cell;
    NSLog(@"tableview selected");
    moduleBrowserCell *cell = (moduleBrowserCell *)[browserTableView cellForRowAtIndexPath:indexPath];
    if (![[cell.moduleService objectForKey:@"Socket"] isConnected] ){
        [tableView deselectRowAtIndexPath:indexPath animated:YES];
        return;
    }
    else{
        [selectedModule addObject:cell.moduleService];
    }
    [ledControllerSlider setUserInteractionEnabled: YES];
}

- (void)tableView:(UITableView *)tableView didDeselectRowAtIndexPath:(NSIndexPath *)indexPath
{
    NSLog(@"tableview unselected");
     moduleBrowserCell *cell = (moduleBrowserCell *)[browserTableView cellForRowAtIndexPath:indexPath];
    [selectedModule removeObject:cell.moduleService];
    if ([selectedModule count]==0) {
        [ledControllerSlider setUserInteractionEnabled: NO];
    }
}


- (IBAction)valueChanged:(UISlider*)slider
{
    char value = slider.value;
    for(NSMutableDictionary *object in selectedModule){
        [[object objectForKey:@"Socket"] writeData: [NSData dataWithBytes:&value length:1]
                                       withTimeout:5 tag:0];
    }
}

- (IBAction)senddata:(UIButton*)button
{
    for(NSMutableDictionary *object in selectedModule){
        [[object objectForKey:@"Socket"] writeData: [@"Hello" dataUsingEncoding:NSUTF8StringEncoding]
                                       withTimeout:5 tag:0];
    }
}

- (void)dealloc {
	// Cleanup any running resolve and free memory
	self.services = nil;
    self.displayServices = nil;
	[self.netServiceBrowser stop];
	self.netServiceBrowser = nil;
}

#pragma mark - AsyncSocket delegate

- (void)onSocket:(AsyncSocket *)sock didConnectToHost:(NSString *)host port:(UInt16)port
{
    NSUInteger index;
    moduleBrowserCell *cell;
    
    for (NSMutableDictionary *object in self.displayServices){
        if([object objectForKey:@"Socket"] == sock ){
            index = [self.displayServices indexOfObject:object];
            break;
        }
    }
    
    cell = (moduleBrowserCell *)[browserTableView cellForRowAtIndexPath:[NSIndexPath indexPathForRow:index inSection:0]];
    cell.accessoryView = nil;
    cell.accessoryType = UITableViewCellAccessoryCheckmark;
    
    [cell.moduleService setObject:@NO forKey:@"Connecting"];
    [sock readDataToLength:1 withTimeout:5 tag:1];
}

- (void)onSocket:(AsyncSocket *)sock didReadData:(NSData *)data withTag:(long)tag
{
    CGFloat hue,saturation,brightness,alpha;
    NSUInteger index;
    char inData;
    moduleBrowserCell *cell;
    
    [data getBytes:&inData length:1];
    
    for (NSMutableDictionary *object in self.displayServices){
        if([object objectForKey:@"Socket"] == sock ){
            index = [self.displayServices indexOfObject:object];
            break;
        }
    }
    
    cell = (moduleBrowserCell *)[browserTableView cellForRowAtIndexPath:[NSIndexPath indexPathForRow:index inSection:0]];
    [cell.lightStrengthView.backgroundColor getHue:&hue saturation:&saturation brightness:&brightness alpha:&alpha];
    brightness = inData/100;
    
    cell.lightStrengthView.backgroundColor = [UIColor colorWithHue:hue saturation:saturation brightness:brightness alpha:alpha];
    
    [sock readDataToLength:1 withTimeout:5 tag:1];
}

- (void)onSocketDidDisconnect:(AsyncSocket *)sock
{
    NSUInteger index;
    moduleBrowserCell *cell;
    AsyncSocket *socket;
    NSError *err;
    NSData *ipAddress = nil;
    
    NSLog(@"disconnected");
    
    for (NSMutableDictionary *object in self.displayServices){
        if([object objectForKey:@"Socket"] == sock ){
            index = [self.displayServices indexOfObject:object];
            [selectedModule removeObject:object];
            [browserTableView  deselectRowAtIndexPath:[NSIndexPath indexPathForRow:index inSection:0] animated:YES];
             break;
        }
    }
    
    if ([selectedModule count]==0) {
        [ledControllerSlider setUserInteractionEnabled: NO];
    }
    
    [sock setDelegate:nil];
    
    
    cell = (moduleBrowserCell *)[browserTableView cellForRowAtIndexPath:[NSIndexPath indexPathForRow:index inSection:0]];
    
    if(cell){
        [cell startActivityIndicator:YES];
        if([[cell.moduleService objectForKey:@"Connecting"]  isEqual: @NO]){
            [cell.moduleService removeObjectForKey:@"Socket"];
            
            NSNetService *service = [cell.moduleService objectForKey:@"BonjourService"];
            if([[service addresses] count])
                ipAddress = [[service addresses] objectAtIndex:0];
            
            socket = [[AsyncSocket alloc] initWithDelegate:self];
            [socket connectToHost:[ipAddress host] onPort:service.port error:&err];
            [cell.moduleService setObject:socket forKey:@"Socket"];
            [cell.moduleService setObject:@YES forKey:@"Connecting"];
            
        }
    }
}


- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
    if ([[segue identifier] isEqualToString:@"showDetail"]) {
        NSIndexPath *indexPath = [browserTableView indexPathForSelectedRow];
        [browserTableView deselectRowAtIndexPath:indexPath animated:YES];
        NSMutableDictionary *object = [self.displayServices objectAtIndex:indexPath.row];
        [[segue destinationViewController] setDetailItem:object];
    }
}

/*
 Notification method handler when app enter in forground
 @param the fired notification object
 */
- (void)appEnterInforground:(NSNotification*)notification{
    
    [self searchForModules];
}

/*
 Notification method handler when app enter in background
 @param the fired notification object
 */
- (void)appEnterInBackground:(NSNotification*)notification{
    NSLog(@"%s", __func__);
}



@end
