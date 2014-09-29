//
//  guideViewController.h
//  MICO
//
//  Created by William Xu on 14-5-16.
//  Copyright (c) 2014年 MXCHIP Co;Ltd. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface guideViewController : UIViewController{
    IBOutlet UIWebView *webView;
}

- (IBAction) dismiss: (UIBarButtonItem *)button;
@end
