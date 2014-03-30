//
//  FTCStringCell.m
//  EasyLink
//
//  Created by William Xu on 14-3-25.
//  Copyright (c) 2014年 MXCHIP Co;Ltd. All rights reserved.
//

#import "FTCStringCell.h"


@implementation FTCStringCell
@synthesize ftcConfig = _ftcConfig;
@synthesize contentText;


- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier
{
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
        // Initialization code
        
    }
    return self;
}

- (void)awakeFromNib
{
    // Initialization code
    self.contentText.delegate = self;
}

- (void)setSelected:(BOOL)selected animated:(BOOL)animated
{
    [super setSelected:selected animated:animated];

    // Configure the view for the selected state
}

- (void)setFtcConfig:(NSMutableDictionary *)newFtcConfig {
	_ftcConfig = newFtcConfig;
    NSString *content = [self.ftcConfig objectForKey:@"C"];
    self.textLabel.text = [self.ftcConfig objectForKey:@"N"];
    if([self.textLabel.text isEqualToString:@"Device Name"]){
        NSRange range = [content rangeOfCharacterFromSet:[NSCharacterSet characterSetWithCharactersInString:@"#"]
                                                 options:NSBackwardsSearch];
        if(range.location == NSNotFound){
            nameSuffix = nil;
            range.length = [content length];
        }else{
            range.length = [content length] - range.location;
            nameSuffix = [content substringWithRange:range];
            range.length = range.location;
        }
        range.location = 0;
        self.contentText.text = [content substringWithRange:range];
    }else{
        self.contentText.text = content;
    }
    
    if ([[self.ftcConfig objectForKey:@"P"] isEqualToString:@"RO"]) {
        [self.contentText setUserInteractionEnabled:NO];
        [self.contentText setTextColor:[UIColor grayColor]];
    }
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField
{
    if([self.textLabel.text isEqualToString:@"Device Name"]){
        [self.ftcConfig setObject:[textField.text stringByAppendingString: nameSuffix]
                           forKey:self.textLabel.text];
    }else{
        [self.ftcConfig setObject:textField.text forKey:self.textLabel.text];
    }
    
    [textField resignFirstResponder];
    return YES;
}




@end
