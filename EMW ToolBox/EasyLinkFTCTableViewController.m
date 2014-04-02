//
//  EasyLinkFTCTableViewController.m
//  EasyLink
//
//  Created by William Xu on 14-3-24.
//  Copyright (c) 2014年 MXCHIP Co;Ltd. All rights reserved.
//

#import "EasyLinkFTCTableViewController.h"
#import "FTCStringCell.h"

@interface EasyLinkFTCTableViewController ()

@end

@implementation EasyLinkFTCTableViewController
@synthesize configData = _configData;


- (id)initWithStyle:(UITableViewStyle)style
{
    self = [super initWithStyle:style];
    if (self) {
        // Custom initialization
    }
    return self;
}

- (id)delegate
{
	return theDelegate;
}

- (void)setDelegate:(id)delegate
{
    theDelegate = delegate;
}

- (void)dealloc{
    theDelegate = nil;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    // Uncomment the following line to preserve selection between presentations.
    // self.clearsSelectionOnViewWillAppear = NO;
    
    // Uncomment the following line to display an Edit button in the navigation bar for this view controller.
    // self.navigationItem.rightBarButtonItem = self.editButtonItem;
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)setConfigData:(NSMutableDictionary *)newConfigData
{
    if (_configData != newConfigData) {
        _configData = newConfigData;
        
        // Update the view.
        self.configMenu = [newConfigData objectForKey:@"C"];
        [configTableView reloadData];
    }
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    // Return the number of sections.
    return [self.configMenu count];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    // Return the number of rows in the section.
    return [[[self.configMenu objectAtIndex:section] objectForKey:@"C"] count];
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
    return [[self.configMenu objectAtIndex:section] objectForKey:@"N"];
}


- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    FTCStringCell *cell;
    NSString *tableCellIdentifier;
    NSUInteger sectionRow = [ indexPath indexAtPosition: 0 ];
    NSUInteger contentRow = [ indexPath indexAtPosition: 1 ];
    NSArray *array =[[self.configMenu objectAtIndex:sectionRow] objectForKey:@"C"];
    NSMutableDictionary *content = [array objectAtIndex: contentRow];
    
    if([[content objectForKey:@"T"] isEqualToString:@"string"]){
        tableCellIdentifier= @"ConfigCell";
    }else if([[content objectForKey:@"T"] isEqualToString:@"switch"]){
        tableCellIdentifier = @"SwitchCell";
    }
    cell = [tableView dequeueReusableCellWithIdentifier:tableCellIdentifier];
    cell.ftcConfig  = content;

    return cell;
}

- (IBAction)applyNewConfigData
{
    if([theDelegate respondsToSelector:@selector(onConfigured:)])
        [theDelegate onConfigured:self.configData];
    
    //[self.navigationController popToViewController:theDelegate animated:YES];
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
