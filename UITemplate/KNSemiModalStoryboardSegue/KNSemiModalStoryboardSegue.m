//
//  CustomUIStoryboard.m
//  MICO
//
//  Created by William Xu on 14-5-13.
//  Copyright (c) 2014年 MXCHIP Co;Ltd. All rights reserved.
//

#import "KNSemiModalStoryboardSegue.h"
#import "UIViewController+KNSemiModal.h"

@implementation KNSemiModalStoryboardSegue

- (void)perform

{
    
    UIViewController *current = self.sourceViewController;
    
    UIViewController *next = self.destinationViewController;
    
    //[current.navigationController pushViewController:next animated:YES];
    
    [current presentSemiViewController:next withOptions:@{
                                                       KNSemiModalOptionKeys.pushParentBack    : @(YES),
                                                       KNSemiModalOptionKeys.animationDuration : @(0.5),
                                                       }];
    
}

@end
