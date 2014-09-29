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
    id theDelegate;
    IBOutlet UITextField *contentText;
    NSString *nameSuffix;
    bool moved;
    
}

@property (nonatomic, readwrite) NSUInteger sectionRow;
@property (nonatomic, readwrite) NSUInteger contentRow;
@property (nonatomic, retain, readwrite) NSMutableDictionary *ftcConfig;
@property (nonatomic, retain, readwrite) UITextField  *contentText;

- (id)delegate;
- (void)setDelegate:(id)delegate;

- (IBAction)editingChanged:  (UITextField *)textField;


@end
