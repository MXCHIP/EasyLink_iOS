//
//  easylinkModeConfigTableViewController.m
//  MICO
//
//  Created by William Xu on 2017/11/12.
//  Copyright © 2017年 MXCHIP Co;Ltd. All rights reserved.
//

#import "easylinkModeConfigTableViewController.h"

NSString * const easylinkModeText[] = { @"EasyLink V1", @"EasyLink V2", @"EasyLink Plus", @"EasyLink Combo", @"EasyLink AWS", @"EasyLink Soft AP"};

@interface easylinkModeConfigTableViewController ()

@end

@implementation easylinkModeConfigTableViewController
@synthesize mode;

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

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 2;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    // Return the number of rows in the section.
    if(section == 1)
        return 1;
    else
        return EASYLINK_MODE_MAX;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    NSUInteger sectionRow = [ indexPath indexAtPosition: 0 ];
    UITableViewCell *cell = nil;
    
    if(sectionRow == 0){
        static NSString *tableCellIdentifier = @"EasyLink Cell";
        cell = (UITableViewCell *)[tableView dequeueReusableCellWithIdentifier:tableCellIdentifier];
        if (cell == nil) {
            cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:tableCellIdentifier];
        }
        cell.textLabel.text = easylinkModeText[indexPath.row];
        
        if( *mode == (EasyLinkMode)indexPath.row) {
            cell.accessoryType = UITableViewCellAccessoryCheckmark;
        } else {
            cell.accessoryType = UITableViewCellAccessoryNone;
        }
    }else{
        cell = (UITableViewCell *)[tableView dequeueReusableCellWithIdentifier:@"OK"];
    }
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    //moduleBrowserCell *cell;
    UITableViewCell *cell;
    NSUInteger sectionRow = [ indexPath indexAtPosition: 0 ];
    
    if ( sectionRow == 0 ){
        cell = [selectTable cellForRowAtIndexPath:[NSIndexPath indexPathForRow:*mode inSection:0]];
        cell.accessoryType = UITableViewCellAccessoryNone;
        
        /*Set the current check mark and change the config data*/
        *mode = (EasyLinkMode)indexPath.row;
        cell = [selectTable cellForRowAtIndexPath:indexPath];
        cell.accessoryType = UITableViewCellAccessoryCheckmark;
        [tableView deselectRowAtIndexPath:indexPath animated:NO];
    }
    else if ( sectionRow == 1 ) {
        [self.navigationController popViewControllerAnimated:YES];
    }
}

/*
// Override to support conditional editing of the table view.
- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
    // Return NO if you do not want the specified item to be editable.
    return YES;
}
*/

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

/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/

@end
