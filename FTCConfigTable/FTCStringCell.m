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
@synthesize sectionRow;
@synthesize contentRow;


- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier
{
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
        // Initialization code
        
    }
    return self;
}

- (id)delegate
{
    return theDelegate;
}

- (void)setDelegate:(id)delegate
{
    theDelegate = delegate;
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
    if([[self.ftcConfig objectForKey:@"C"] isKindOfClass:[NSString class]]){ //string
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

//- (IBAction)editingChanged: (UITextField *)textField
//{
//    FTCStringCell *cell;
//    NSIndexPath *indexPath;
//    NSLog(@"Value changed!");
//    cell = (FTCStringCell *)textField.superview.superview;
//    indexPath = [configTableView indexPathForCell:cell];
//    NSUInteger sectionRow = [ indexPath indexAtPosition: 0 ]-hasOTA;
//    NSUInteger contentRow = [ indexPath indexAtPosition: 1 ];
//    NSArray *array =[[self.configMenu objectAtIndex:sectionRow] objectForKey:@"C"];
//    NSMutableDictionary *content = [array objectAtIndex: contentRow];
//    NSMutableDictionary *updateSetting = [self.configData objectForKey:@"update"];
//    if([[content objectForKey:@"C"] isKindOfClass:[NSString class]])
//        [updateSetting setObject:textField.text forKey:[content objectForKey:@"N"]];
//    else{
//        NSInteger value = [textField.text intValue];
//        [updateSetting setObject:[NSNumber numberWithLong:value] forKey:[content objectForKey:@"N"]];
//    }
//}

//- (BOOL)textField:(UITextField *)textField shouldChangeCharactersInRange:(NSRange)range replacementString:(NSString *)string {
//    //Replace the string manually in the textbox
//    textField.text = [textField.text stringByReplacingCharactersInRange:range withString:string];
//    //perform any logic here now that you are sure the textbox text has changed
//    //[self didChangeTextInTextField:textField];
//    NSLog(@"Value changed!");
//    return NO; //this make iOS not to perform any action
//}

- (IBAction)editingChanged:  (UITextField *)textField
{
    NSIndexPath *indexpath = [NSIndexPath indexPathForRow:contentRow inSection:sectionRow];
    if( [theDelegate respondsToSelector:@selector(editingChanged:AtIndexPath:)]){
        [theDelegate performSelector:@selector(editingChanged:AtIndexPath:) withObject:textField.text withObject:indexpath];
    }
    
}




@end
