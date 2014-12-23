//
//  EasyLinkFTCTableViewController.h
//  EasyLink
//
//  Created by William Xu on 14-3-24.
//  Copyright (c) 2014年 MXCHIP Co;Ltd. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "GRRequestsManager.h"

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
    bool hasOTA;
    NSString *currentVersion;
}

@property (strong, nonatomic) NSMutableDictionary *configData;
@property (strong, nonatomic) NSArray *configMenu;
@property (strong, nonatomic) NSString *otaPath;
@property (nonatomic, strong) GRRequestsManager *requestsManager;

- (id)delegate;
- (void)setDelegate:(id)delegate;

- (IBAction)applyNewConfigData;

@end
