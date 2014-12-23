//
//  newModuleTableViewCell.h
//  MICO
//
//  Created by William Xu on 14/12/10.
//  Copyright (c) 2014年 MXCHIP Co;Ltd. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface newModuleTableViewCell : UITableViewCell{
    IBOutlet UIButton *_confirmBtn;
    IBOutlet UIButton *_settingBtn;
    IBOutlet UIButton *_updateBtn;
    IBOutlet UIButton *_ignoreBtn;
    IBOutlet UIImageView *_deviceImg;
    IBOutlet UILabel *_deviceTitle;
    IBOutlet UILabel *_deviceDetail;
    id theDelegate;
    
}

@property (nonatomic, readwrite) NSUInteger moduleIndex;
@property (nonatomic, readwrite) NSMutableDictionary *moduleInfo;

- (IBAction)buttonPressed: (UIButton *)sender;

- (id)delegate;
- (void)setDelegate:(id)delegate;


@end
