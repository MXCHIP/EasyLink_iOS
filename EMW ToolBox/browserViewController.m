//
//  mxchipMasterViewController.m
//  EMW ToolBox
//
//  Created by William Xu on 13-7-26.
//  Copyright (c) 2013年 MXCHIP Co;Ltd. All rights reserved.
//

#import "browserViewController.h"
#import "mxchipDetailViewController.h"
#import <sys/socket.h> 
#import <netinet/in.h>
#include <arpa/inet.h>

#define searchingString @"Searching for MXCHIP Modules..."
#define kWebServiceType @"_http._tcp"
#define kInitialDomain  @"local"
#define repeatInterval  10.0

#define kProgressIndicatorSize 20.0

bool newModuleFound;

@interface NSMutableDictionary (BrowserViewControllerAdditions)
- (NSComparisonResult) localizedCaseInsensitiveCompareByName:(NSMutableDictionary*)aService;
@end

@implementation NSMutableDictionary (BrowserViewControllerAdditions)
- (NSComparisonResult) localizedCaseInsensitiveCompareByName:(NSMutableDictionary*)aService {
	return [[self objectForKey:@"Name"] localizedCaseInsensitiveCompare:[aService objectForKey:@"Name"]];
}
@end

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


@interface browserViewController()
@property (nonatomic, retain, readwrite) NSNetServiceBrowser* netServiceBrowser;
@property (nonatomic, retain, readwrite) NSMutableArray* services;
@property (nonatomic, retain, readwrite) NSTimer* timer;
@property (nonatomic, assign, readwrite) BOOL initialWaitOver;

- (void)repeatSearching:(NSTimer*)timer;

@end

@implementation browserViewController
@synthesize netServiceBrowser = _netServiceBrowser;
@synthesize services = _services;
@dynamic timer;
@synthesize initialWaitOver = _initialWaitOver;

- (void)awakeFromNib
{
    sleep(2);
    [super awakeFromNib];
}

- (void)viewDidLoad
{
    [super viewDidLoad];

	_services = [[NSMutableArray alloc] init];
    UIBarButtonItem *backItem = [[UIBarButtonItem alloc] initWithTitle:@"Modules" style:UIBarButtonItemStyleBordered target:nil action:nil];
    [self.navigationItem setBackBarButtonItem:backItem];
    
    NSNetServiceBrowser *aNetServiceBrowser = [[NSNetServiceBrowser alloc] init];
	if(!aNetServiceBrowser) {
        // The NSNetServiceBrowser couldn't be allocated and initialized.
		NSLog(@"Network service error!");
	}
	aNetServiceBrowser.delegate = self;
	self.netServiceBrowser = aNetServiceBrowser;
                
	// Make sure we have a chance to discover devices before showing the user that nothing was found (yet)
    [self repeatSearching: self.timer];
    self.timer = [NSTimer scheduledTimerWithTimeInterval:repeatInterval target:self selector:@selector(repeatSearching:) userInfo:nil repeats:YES];
    [NSTimer scheduledTimerWithTimeInterval:1.0 target:self selector:@selector(initialWaitOver:) userInfo:nil repeats:NO];

}

- (void)viewWillAppear:(BOOL)animated
{
    
}


- (void)initialWaitOver:(NSTimer*)timer {
	self.initialWaitOver= YES;
	if (![self.services count])
		[browserTableView reloadData];
}


- (IBAction)refreshService:(UIBarButtonItem*)button
{
    [self searchForModules];
}

- (void)searchForModules
{
	[self.netServiceBrowser stop];
	[self.services removeAllObjects];
    [browserTableView reloadData];
	[self repeatSearching: self.timer];
	
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
	[self.services sortUsingSelector:@selector(localizedCaseInsensitiveCompareByName:)];
	[browserTableView reloadData];
}

#pragma mark - NSNetServiceBrowserDelegate

- (void)netServiceBrowserDidStopSearch:(NSNetServiceBrowser *)netServiceBrowser
{
    NSLog(@"Service Search stoped");
}

- (void)netServiceBrowserWillSearch:(NSNetServiceBrowser *)netServiceBrowser
{
    NSLog(@"Service Search will start");
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
	
	
	// If moreComing is NO, it means that there are no more messages in the queue from the Bonjour daemon, so we should update the UI.
	// When moreComing is set, we don't update the UI so that it doesn't 'flash'.
	if (!moreComing) {
		[self sortAndUpdateUI];
	}
}


- (void)netServiceBrowser:(NSNetServiceBrowser*)netServiceBrowser didFindService:(NSNetService*)service moreComing:(BOOL)moreComing {
	// If a service came online, add it to the list and update the table view if no more events are queued.
    if([[service name] rangeOfString:@"EMW"].location == NSNotFound)
        return;
    NSMutableDictionary *moduleService = [[NSMutableDictionary alloc] initWithCapacity:15];
    service.delegate = self;
    [moduleService setObject:[service name] forKey:@"Name"];
    [moduleService setObject:service forKey:@"BonjourService"];
    [moduleService setObject:@YES forKey:@"resolving"];
    
    
    for (NSMutableDictionary *object in self.services)
    {
        if([[object objectForKey:@"Name"] isEqual:[service name]])
            return;
    }
    
        NSLog(@"service found %@",[service name]);
        newModuleFound = YES;
        [self.services addObject:moduleService];
        NSIndexPath* indexPath = [NSIndexPath indexPathForRow:[self.services indexOfObject:moduleService] inSection:0];
        if(indexPath.row==0&&self.initialWaitOver== YES) //update a searching row
            [browserTableView reloadRowsAtIndexPaths:[NSArray arrayWithObject:indexPath] withRowAnimation:UITableViewRowAnimationNone];
        else
            [browserTableView insertRowsAtIndexPaths:[NSArray arrayWithObject:indexPath] withRowAnimation:UITableViewRowAnimationNone];
        [service resolveWithTimeout:0.0];
}

- (void)repeatSearching:(NSTimer*)timer {
	if (timer == self.timer) {
        [self.netServiceBrowser stop];
        [self.netServiceBrowser searchForServicesOfType:kWebServiceType inDomain:kInitialDomain];
	}
}


#pragma mark - NSNetServiceDelegate
// This should never be called, since we resolve with a timeout of 0.0, which means indefinite
- (void)netService:(NSNetService *)sender didNotResolve:(NSDictionary *)errorDict {
	[browserTableView reloadData];
}


- (void)netServiceDidResolveAddress:(NSNetService *)service
{
    
    for (NSMutableDictionary *object in self.services)
    {
        if([object objectForKey:@"BonjourService"] == service){
            [object setObject:@NO forKey:@"resolving"];
            NSIndexPath* indexPath = [NSIndexPath indexPathForRow:[self.services indexOfObject:object] inSection:0];
            NSLog(@"resolve success! service found at %d,service info:%@,%@,%d,%d",
                  indexPath.row,[service name],[service hostName],[[service addresses] count], [service port]);
            [browserTableView reloadRowsAtIndexPaths:[NSArray arrayWithObject:indexPath] withRowAnimation:UITableViewRowAnimationNone];
            break;
        }
    }
}

#pragma mark - Table View

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
	NSUInteger count = [self.services count];
	if (count == 0 && self.initialWaitOver)
		return 1;
    
	return count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
	NSData *ipAddress = nil;
    NSUInteger count = [self.services count];

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
    NSString *serviceName;
    NSNetService *service;
    BOOL resolving;
	UITableViewCell *cell = (UITableViewCell *)[tableView dequeueReusableCellWithIdentifier:tableCellIdentifier2];
	if (cell == nil) {
		cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:tableCellIdentifier2];
	}
    
    // Set up the text for the cell
	NSMutableDictionary *moduleService = [self.services objectAtIndex:indexPath.row];
    serviceName = [moduleService objectForKey:@"Name"];
    service = [moduleService objectForKey:@"BonjourService"];
    resolving = [[moduleService objectForKey:@"resolving"] boolValue];
    
    if([serviceName rangeOfString:@"EMW_3161"].location != NSNotFound)
        cell.imageView.image = [UIImage imageNamed:@"EMW3161_logo.png"];
    else if([serviceName rangeOfString:@"EMW_3280"].location != NSNotFound)
        cell.imageView.image = [UIImage imageNamed:@"EMW3280_logo.png"];
    else if([serviceName rangeOfString:@"EMW_3162"].location != NSNotFound)
        cell.imageView.image = [UIImage imageNamed:@"EMW3162_logo.png"];
    else
        cell.imageView.image = [UIImage imageNamed:@"known_logo.png"];
    
    cell.textLabel.text = serviceName;
    cell.textLabel.textColor = [UIColor blackColor];
    if([[[moduleService objectForKey:@"BonjourService"] addresses] count])
        ipAddress = [[service addresses] objectAtIndex:0];
        
    NSString *detailString = [[NSString alloc] initWithFormat:
                              @"%@\nIP address:%@",
                              [[moduleService objectForKey:@"BonjourService"] hostName],
                              (ipAddress!=nil)? [ipAddress host]:@"Unknow"];
    
    cell.detailTextLabel.text = detailString;

    
	if (resolving == NO){

        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        if (cell.accessoryView) {
            cell.accessoryView = nil;
        }
    }
	
	// Note that the underlying array could have changed, and we want to show the activity indicator on the correct cell
	else{
		if (!cell.accessoryView) {
			CGRect frame = CGRectMake(0.0, 0.0, kProgressIndicatorSize, kProgressIndicatorSize);
			UIActivityIndicatorView* spinner = [[UIActivityIndicatorView alloc] initWithFrame:frame];
			[spinner startAnimating];
			spinner.activityIndicatorViewStyle = UIActivityIndicatorViewStyleGray;
			[spinner sizeToFit];
			spinner.autoresizingMask = (UIViewAutoresizingFlexibleLeftMargin |
										UIViewAutoresizingFlexibleRightMargin |
										UIViewAutoresizingFlexibleTopMargin |
										UIViewAutoresizingFlexibleBottomMargin);
			cell.accessoryView = spinner;
		}
	}
	
	return cell;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
        return 80;
}


- (NSIndexPath *)tableView:(UITableView *)tableView willSelectRowAtIndexPath:(NSIndexPath *)indexPath {
	// Ignore the selection if there are no services as the searchingForServicesString cell
	// may be visible and tapping it would do nothing
	if ([self.services count] == 0)
		return nil;
	
	return indexPath;
}

- (void)dealloc {
	// Cleanup any running resolve and free memory
	self.services = nil;
	[self.netServiceBrowser stop];
	self.netServiceBrowser = nil;
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
    if ([[segue identifier] isEqualToString:@"showDetail"]) {
        NSIndexPath *indexPath = [browserTableView indexPathForSelectedRow];
        [browserTableView deselectRowAtIndexPath:indexPath animated:YES];
        NSMutableDictionary *object = [self.services objectAtIndex:indexPath.row];
        [[segue destinationViewController] setDetailItem:object];
    }
}

/*
 Notification method handler when app enter in forground
 @param the fired notification object
 */
- (void)appEnterInforground:(NSNotification*)notification{
    NSLog(@"%s", __func__);
    [self searchForModules];
}



@end
