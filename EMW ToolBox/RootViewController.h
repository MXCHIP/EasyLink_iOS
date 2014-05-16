//
//  RootViewController.h
//  MICO
//
//  Created by William Xu on 14-5-15.
//  Copyright (c) 2014年 MXCHIP Co;Ltd. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "HMSegmentedControl.h"


@interface RootViewController : UIViewController  <UIScrollViewDelegate>
{
    HMSegmentedControl *sceneSegment;
}

@end
