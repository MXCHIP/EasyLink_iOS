//
//  EasyLinkOTATableViewController.h
//  MICO
//
//  Created by William Xu on 14-4-15.
//  Copyright (c) 2014年 MXCHIP Co;Ltd. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "GRRequestsManager.h"
#import "CustomIOS7AlertView.h"

@protocol EasyLinkOTADelegate
@optional
/**
 *
 **/
- (void)onStartOTA:(NSString *)otaFilePath toFTCClient: (NSNumber *)client;

@end


@interface EasyLinkOTATableViewController : UITableViewController<GRRequestsManagerDelegate>{
    NSString *protocol;
    NSString *hardwareVersion;
    NSString *firmwareVersion;
    NSString *rfVersion;
    NSArray *firmwareListArray;
    NSMutableArray  *firmwareListCurrentState;
    
    GRRequestsManager *requestsManager;
    NSNumber *client;
    IBOutlet UITableView *firmwareListTable;
    id theDelegate;
@private
    CustomIOS7AlertView *customAlertView;
    NSInteger currentSelectedIndex;
    NSString *localOTAFilePath;
}

- (id)delegate;
- (void)setDelegate:(id)delegate;

@property (strong, nonatomic) NSString *protocol;
@property (strong, nonatomic) NSString *hardwareVersion;
@property (strong, nonatomic) NSString *firmwareVersion;
@property (strong, nonatomic) NSString *rfVersion;
@property (strong, nonatomic) NSArray  *firmwareListArray;
@property (strong, nonatomic) NSMutableArray  *firmwareListCurrentState;
@property (strong, nonatomic) NSNumber *client;
@property (nonatomic, strong) GRRequestsManager *requestsManager;


@end
