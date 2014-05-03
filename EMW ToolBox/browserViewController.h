//
//  mxchipMasterViewController.h
//  EMW ToolBox
//
//  Created by William Xu on 13-7-26.
//  Copyright (c) 2013年 MXCHIP Co;Ltd. All rights reserved.
//

#import <UIKit/UIKit.h>


@interface browserViewController : UIViewController <NSNetServiceBrowserDelegate, NSNetServiceDelegate>{
    NSMutableArray *_objects;
    IBOutlet UITableView *browserTableView;
    IBOutlet UISlider *ledControllerSlider;
@private    
    NSMutableArray* _services, *_displayServices;
    NSMutableArray* selectedModule;
    NSNetServiceBrowser* _netServiceBrowser;
    BOOL _needsActivityIndicator;
    BOOL _currentResolveSuccess;
    NSTimer* _timer;
}

- (void)searchForModules;
- (IBAction)refreshService:(UIBarButtonItem*)button;
- (IBAction)valueChanged:(UISlider*)slider;


@end
