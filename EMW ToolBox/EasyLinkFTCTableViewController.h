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
- (void)onConfigured:(NSMutableDictionary *)configData;
@end

@interface EasyLinkFTCTableViewController : UITableViewController{
    IBOutlet UITableView *configTableView;
    id theDelegate;
}

@property (strong, nonatomic) NSMutableDictionary *configData;
@property (strong, nonatomic) NSArray *configMenu;

- (id)delegate;
- (void)setDelegate:(id)delegate;

- (IBAction)applyNewConfigData;



@end
//////////////////////
