//
//  FTCSwitchCell.m
//  EasyLink
//
//  Created by William Xu on 14-3-26.
//  Copyright (c) 2014年 MXCHIP Co;Ltd. All rights reserved.
//

#import "FTCSwitchCell.h"

@implementation FTCSwitchCell
@synthesize ftcConfig = _ftcConfig;
@synthesize contentSwitch;
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

- (void)awakeFromNib
{
    // Initialization code
    [super awakeFromNib];
}

- (id)delegate
{
    return theDelegate;
}

- (void)setDelegate:(id)delegate
{
    theDelegate = delegate;
}


- (void)setSelected:(BOOL)selected animated:(BOOL)animated
{
    [super setSelected:selected animated:animated];

    // Configure the view for the selected state
}

- (void)setFtcConfig:(NSMutableDictionary *)newFtcConfig {
	_ftcConfig = newFtcConfig;
    self.textLabel.text = [self.ftcConfig objectForKey:@"N"];
    self.textLabel.backgroundColor = [UIColor clearColor];
    self.contentSwitch.on = [[self.ftcConfig valueForKey:@"C"] boolValue];

    if ([[self.ftcConfig objectForKey:@"P"] isEqualToString:@"RO"]) {
        [self.contentSwitch setUserInteractionEnabled:NO];
    }
}

//- (void) switchChanged: (bool)onoff AtIndexPath:(NSIndexPath *)indexPath
//{
//    NSLog(@"Value changed!");
//    NSUInteger sectionRow = [ indexPath indexAtPosition: 0 ];
//    NSUInteger contentRow = [ indexPath indexAtPosition: 1 ];
//    NSArray *array =[[self.configMenu objectAtIndex:sectionRow] objectForKey:@"C"];
//    NSMutableDictionary *content = [array objectAtIndex: contentRow];
//    NSMutableDictionary *updateSetting = [self.configData objectForKey:@"update"];
//    [updateSetting setObject:(onoff == YES)? @YES:@NO forKey:[content objectForKey:@"N"]];
//}

- (IBAction)switchChanged: (UISwitch *)switcher
{
    NSIndexPath *indexpath = [NSIndexPath indexPathForRow:contentRow inSection:sectionRow];
    NSNumber *onoff = [NSNumber numberWithBool:switcher.on];
    if( [theDelegate respondsToSelector:@selector(switchChanged:AtIndexPath:)]){
        [theDelegate performSelector:@selector(switchChanged:AtIndexPath:) withObject:onoff withObject:indexpath];
    }

}


@end
