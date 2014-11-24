//
//  EasyLinkFoundTableViewController.h
//  
//
//  Created by William Xu on 14/11/19.
//
//

#import <UIKit/UIKit.h>
#import "EASYLINK.h"

@interface EasyLinkFoundTableViewController : UITableViewController{
    id theDelegate;
}

@property (strong, nonatomic) NSMutableArray *foundModules;
@property (strong, nonatomic) EASYLINK *easylink_config;

- (id)delegate;
- (void)setDelegate:(id)delegate;

@end
