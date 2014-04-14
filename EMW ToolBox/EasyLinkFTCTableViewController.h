//
//  EasyLinkFTCTableViewController.h
//  EasyLink
//
//  Created by William Xu on 14-3-24.
//  Copyright (c) 2014年 MXCHIP Co;Ltd. All rights reserved.
//

#import <UIKit/UIKit.h>

@protocol EasyLinkFTCDataDelegate
@optional
/**
 *
 **/
- (void)onConfigured:(NSMutableDictionary *)updateSettings;
@end

@interface EasyLinkFTCTableViewController : UITableViewController{
    IBOutlet UITableView *configTableView;
    id theDelegate;
@private
    NSIndexPath *selectCellIndexPath;
}

@property (strong, nonatomic) NSMutableDictionary *configData;
@property (strong, nonatomic) NSArray *configMenu;

- (id)delegate;
- (void)setDelegate:(id)delegate;

- (IBAction)applyNewConfigData;

- (IBAction)switchChanged: (UISwitch *)switcher;
- (IBAction)editingChanged: (UITextField *)textField;

@end
