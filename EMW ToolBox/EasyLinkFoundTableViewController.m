//
//  EasyLinkFoundTableViewController.m
//  
//
//  Created by William Xu on 14/11/19.
//
//

#import "EasyLinkFoundTableViewController.h"
#import "EasyLinkFTCTableViewController.h"


@interface EasyLinkFoundTableViewController ()

@end

@implementation EasyLinkFoundTableViewController
@synthesize foundModules;
@synthesize easylink_config;


- (id)delegate
{
    return theDelegate;
}

- (void)setDelegate:(id)delegate
{
    theDelegate = delegate;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    // Uncomment the following line to preserve selection between presentations.
    // self.clearsSelectionOnViewWillAppear = NO;
    
    // Uncomment the following line to display an Edit button in the navigation bar for this view controller.
    // self.navigationItem.rightBarButtonItem = self.editButtonItem;
}

- (void)dealloc {
    NSLog(@"foundTableView dealloced");
}


- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    // Return the number of sections.
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    // Return the number of rows in the section.
    return [self.foundModules count];
}


- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    NSString *currentVerStr;
    
    UITableViewCell *cell = (UITableViewCell *)[tableView dequeueReusableCellWithIdentifier:@"New Module" forIndexPath:indexPath];
    [cell setBackgroundColor:[UIColor colorWithRed:0.100 green:0.478 blue:1.000 alpha:0.4]];
    [cell setBackgroundColor:[UIColor colorWithRed:1.0 green:1.0 blue:1.0 alpha:0.6]];
    cell.textLabel.text = [[self.foundModules objectAtIndex:indexPath.row] objectForKey:@"N"];
    currentVerStr = [[self.foundModules objectAtIndex:indexPath.row] objectForKey:@"FW"];
    cell.detailTextLabel.text = [NSString stringWithFormat:@"Firmware: %@",currentVerStr? currentVerStr:@"unkown"];
    return cell;
}

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath
{
    NSUInteger row = [indexPath row];
    NSMutableDictionary *deleteModule = nil;
    deleteModule = [foundModules objectAtIndex:row];
    if( [easylink_config respondsToSelector:@selector(closeFTCClient:)]  == true )
        [easylink_config performSelector:@selector(closeFTCClient:) withObject:[deleteModule objectForKey:@"client"]];
}

- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath
{
    // Return NO if you do not want the specified item to be editable.
    return YES;
}

- (NSString *)tableView:(UITableView *)tableView titleForDeleteConfirmationButtonForRowAtIndexPath:(NSIndexPath *)indexPath{
    return @"Ignore";
}


/*
// Override to support editing the table view.
- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath {
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
- (void)tableView:(UITableView *)tableView moveRowAtIndexPath:(NSIndexPath *)fromIndexPath toIndexPath:(NSIndexPath *)toIndexPath {
}
*/

/*
// Override to support conditional rearranging of the table view.
- (BOOL)tableView:(UITableView *)tableView canMoveRowAtIndexPath:(NSIndexPath *)indexPath {
    // Return NO if you do not want the item to be re-orderable.
    return YES;
}
*/


#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
    if ([[segue identifier] isEqualToString:@"First Time Configuration"]) {
        NSIndexPath *indexPath = [self.tableView indexPathForSelectedRow];
        [self.tableView deselectRowAtIndexPath:indexPath animated:YES];
        NSMutableDictionary *object = [self.foundModules objectAtIndex:indexPath.row];
        
        [[segue destinationViewController] setConfigData:object];
        [(EasyLinkFTCTableViewController *)[segue destinationViewController] setDelegate:self.delegate];
        
    }
}


@end
