//
//  EMWUtility.h
//  EMW ToolBox
//
//  Created by William Xu on 13-7-28.
//  Copyright (c) 2013年 MXCHIP Co;Ltd. All rights reserved.
//


#import <UIKit/UIKit.h>

#import "APManager.h"
//#import "IOSDevice.h"
#import "EMWHeader.h"
#import <QuartzCore/QuartzCore.h>

#define SSID_TAG            100
#define PASSWORD_TAG    101
#define GATEWAY_TAG     102
#define KEY_TAG             103
#define DEVICE_NAME_TAG 104

@interface EMWUtility : NSObject{
    
}

/// methods

/*!!!
 Singleton instance 
 return: static allocated instance of self
 */
+ (EMWUtility*)sharedInstance;

/*!!!
  Destroy the static singleton instance
 */
+ (void)destroy;

/* 
 Prepare a cell that is created with respect to the indexpath 
 @param cell is an object of UITableViewcell which is newly created 
 @param indexpath  is respective indexpath of the cell of the row. 
 */
-(UITableViewCell *) prepareCell:(UITableViewCell *)cell atIndexPath:(NSIndexPath *)indexPath;

/* 
 Creates label with its defined properties and add it on the provider view.
 @param view is the provider view where label needs to be added. 
 @param text set text property
 @param alignment set alignment property
 @param color set color property
 @return label returns the created label for any custom property settings.
 */
-(UILabel *) createLabelWithFrame:(CGRect)rect 
                           onView:(UIView *)view 
                         withText:(NSString *)text 
                        alignment:(NSTextAlignment)textAlignment
                            color:(UIColor *)color;

/*
 Roatating the spinning wheel when app starts transmitting data
 @param: Spinner which suppose to rotate with CAAnimation
 @param: The start button on which it appears 
 @param: Bool value for start or stop the animation
 */
- (void)rotateSpinner:(UIImageView*)spinner onButton:(UIButton*)button isStart:(BOOL)start;

@end
