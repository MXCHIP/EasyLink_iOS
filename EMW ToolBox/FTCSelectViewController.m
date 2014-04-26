//
//  FTCSelectViewController.m
//  MICO
//
//  Created by William Xu on 14-4-8.
//  Copyright (c) 2014年 MXCHIP Co;Ltd. All rights reserved.
//

#import "FTCSelectViewController.h"

@interface FTCSelectViewController ()

@end

@implementation FTCSelectViewController
@synthesize configData = _configData;

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
        self.selectMenu = [newConfigData objectForKey:@"S"];
        [selectTable reloadData];
    }
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    // Return the number of sections.
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    // Return the number of rows in the section.
    return [self.selectMenu count];
}


- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"Secection" forIndexPath:indexPath];
    
    if([[self.configData objectForKey:@"T"] isEqualToString:@"number"]){
        cell.textLabel.text = [[self.selectMenu objectAtIndex:indexPath.row] stringValue];
        if([[self.selectMenu objectAtIndex:indexPath.row] isEqual:[self.configData objectForKey:@"C"]]){
            cell.accessoryType = UITableViewCellAccessoryCheckmark;
        }else{
            cell.accessoryType = UITableViewCellAccessoryNone;
        }
    }else{
        cell.textLabel.text = [self.selectMenu objectAtIndex:indexPath.row];
        if([cell.textLabel.text isEqualToString:[self.configData objectForKey:@"C"]]){
            cell.accessoryType = UITableViewCellAccessoryCheckmark;
        }else{
            cell.accessoryType = UITableViewCellAccessoryNone;
        }
    }
    
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    //moduleBrowserCell *cell;
    UITableViewCell *cell;
    NSUInteger idx;
    
    /*Clear the previous check mark*/
    for(NSMutableDictionary *object in self.selectMenu){
        if([object isEqual:[self.configData objectForKey:@"C"]]){
            idx = [self.selectMenu indexOfObject:object];
            break;
        }
    }
    cell = [selectTable cellForRowAtIndexPath:[NSIndexPath indexPathForRow:idx inSection:0]];
    cell.accessoryType = UITableViewCellAccessoryNone;
    
    /*Set the current check mark and change the config data*/
    [self.configData setObject:[self.selectMenu objectAtIndex:indexPath.row] forKey:@"C"];
    cell = [selectTable cellForRowAtIndexPath:indexPath];
    cell.accessoryType = UITableViewCellAccessoryCheckmark;
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
