//
//  mxchipDetailViewController.h
//  EMW ToolBox
//
//  Created by William Xu on 13-7-26.
//  Copyright (c) 2013年 MXCHIP Co;Ltd. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface mxchipDetailViewController : UIViewController

@property (strong, nonatomic) id detailItem;

@property (weak, nonatomic) IBOutlet UILabel *detailDescriptionLabel;
@end
