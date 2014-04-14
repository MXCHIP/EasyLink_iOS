//
//  FTCStringSelectCell.m
//  MICO
//
//  Created by William Xu on 14-4-8.
//  Copyright (c) 2014年 MXCHIP Co;Ltd. All rights reserved.
//

#import "FTCStringSelectCell.h"

@implementation FTCStringSelectCell
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
}

- (void)setSelected:(BOOL)selected animated:(BOOL)animated
{
    [super setSelected:selected animated:animated];

    // Configure the view for the selected state
}

- (void)setFtcConfig:(NSMutableDictionary *)newFtcConfig {
	_ftcConfig = newFtcConfig;
    NSString *contentString;
    NSNumber *contentNumber;
    
    self.textLabel.text = [self.ftcConfig objectForKey:@"N"];
    if([[self.ftcConfig objectForKey:@"T"] isEqualToString:@"string"]){ //string
        contentString = [self.ftcConfig objectForKey:@"C"];
        if([self.textLabel.text isEqualToString:@"Device Name"]){
            NSRange range = [contentString rangeOfCharacterFromSet:[NSCharacterSet characterSetWithCharactersInString:@"#"]
                                                           options:NSBackwardsSearch];
            if(range.location == NSNotFound){
                nameSuffix = nil;
                range.length = [contentString length];
            }else{
                range.length = [contentString length] - range.location;
                nameSuffix = [contentString substringWithRange:range];
                range.length = range.location;
            }
            range.location = 0;
            self.contentText.text = [contentString substringWithRange:range];
        }else{
            self.contentText.text = contentString;
        }
    }else{ //number
        contentNumber = [self.ftcConfig objectForKey:@"C"];
        self.contentText.text = [contentNumber stringValue];
    }

    [self.contentText setUserInteractionEnabled:NO];
    [self.contentText setTextColor:[UIColor grayColor]];
    return;
}

- (BOOL)textField:(UITextField *)textField shouldChangeCharactersInRange:(NSRange)range replacementString:(NSString *)string {
    //Replace the string manually in the textbox
    textField.text = [textField.text stringByReplacingCharactersInRange:range withString:string];
    //perform any logic here now that you are sure the textbox text has changed
    //[self didChangeTextInTextField:textField];
    NSLog(@"Value changed!");
    return NO; //this make iOS not to perform any action
}

@end
