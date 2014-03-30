//
//  FTCStringCell.h
//  EasyLink
//
//  Created by William Xu on 14-3-25.
//  Copyright (c) 2014年 MXCHIP Co;Ltd. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface FTCStringCell : UITableViewCell<UITextFieldDelegate>{
    NSMutableDictionary *_ftcConfig;
@private
    IBOutlet UITextField *contentText;
    NSString *nameSuffix;
    
}

@property (nonatomic, retain, readwrite) NSMutableDictionary *ftcConfig;
@property (nonatomic, retain, readwrite) UITextField  *contentText;




@end
