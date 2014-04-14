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

}

- (void)prepareForReuse{
//    if(moved == YES){
//        CGPoint newCenter = CGPointMake(self.contentText.center.x+40, self.contentText.center.y);
//        self.contentText.center = newCenter;
//        moved = NO;
//    }
    

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
        self.contentText.text = contentString;
    }else{ //number
        contentNumber = [self.ftcConfig objectForKey:@"C"];
        self.contentText.text = [contentNumber stringValue];
    }
    
    /*Readonly cell*/
    if ([[self.ftcConfig objectForKey:@"P"] isEqualToString:@"RO"]) {
        [self.contentText setUserInteractionEnabled:NO];
        [self.contentText setTextColor:[UIColor grayColor]];
        return;
    }
    [contentText setDelegate:self];
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField
{
    [textField resignFirstResponder];
    return YES;
}

//- (BOOL)textField:(UITextField *)textField shouldChangeCharactersInRange:(NSRange)range replacementString:(NSString *)string {
//    //Replace the string manually in the textbox
//    textField.text = [textField.text stringByReplacingCharactersInRange:range withString:string];
//    //perform any logic here now that you are sure the textbox text has changed
//    //[self didChangeTextInTextField:textField];
//    NSLog(@"Value changed!");
//    return NO; //this make iOS not to perform any action
//}




@end
