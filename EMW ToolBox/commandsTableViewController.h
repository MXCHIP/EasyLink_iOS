//
//  commandsTableViewController.h
//  MICO
//
//  Created by William Xu on 14-5-8.
//  Copyright (c) 2014年 MXCHIP Co;Ltd. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "addNewCommandViewController.h"

@interface commandsTableViewController : UITableViewController<UIActionSheetDelegate>{
    addNewCommandViewController  *addCommandVC;
    UIView *bgv;
    NSUInteger indexNeedsChange;
    IBOutlet UITableView *commandTableView;
    IBOutlet UIBarButtonItem *editButton;
    IBOutlet UIBarButtonItem *autoButton;
    BOOL editing;
    BOOL autoSending;
    NSUInteger currentSendIndex;
    NSTimer *autoSendTimer;
    id commandSender;
}

@property (strong, nonatomic) NSString *protocol;

- (IBAction)reOrderCommand:(UIBarButtonItem *)sender;
- (IBAction)autoSendCommand:(UIBarButtonItem *)sender;


- (void)getNewCommand:(NSString *)subject content:(NSData *)content type: (NSString *)type;


@end
