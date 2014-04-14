//
//  FTCStringSelectCell.h
//  MICO
//
//  Created by William Xu on 14-4-8.
//  Copyright (c) 2014年 MXCHIP Co;Ltd. All rights reserved.
//

#import <UIKit/UIKit.h>


@interface FTCStringSelectCell : UITableViewCell<UITextFieldDelegate>{
    NSMutableDictionary *_ftcConfig;
@private
    IBOutlet UITextField *contentText;
    NSString *nameSuffix;
    bool moved;
    
}

@property (nonatomic, retain, readwrite) NSMutableDictionary *ftcConfig;
@property (nonatomic, retain, readwrite) UITextField  *contentText;




@end
