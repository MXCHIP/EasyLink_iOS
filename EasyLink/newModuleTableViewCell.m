//
//  newModuleTableViewCell.m
//  MICO
//
//  Created by William Xu on 14/12/10.
//  Copyright (c) 2014年 MXCHIP Co;Ltd. All rights reserved.
//

#import "newModuleTableViewCell.h"
#import "EasyLinkFTCTableViewController.h"

@implementation newModuleTableViewCell

@synthesize moduleIndex = _moduleIndex;
@synthesize moduleInfo = _moduleInfo;

- (void)awakeFromNib {
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

- (void)setSelected:(BOOL)selected animated:(BOOL)animated {
    [super setSelected:selected animated:animated];

    // Configure the view for the selected state
}

- (void)setModuleIndex:(NSUInteger) newModuleIndex
{
    _moduleIndex = newModuleIndex;
    _confirmBtn.tag = newModuleIndex;
}

-(void)viewDidAppear:(BOOL)animated{
    
    //[super viewDidAppear:animated];
    dispatch_async(dispatch_get_main_queue(), ^{
        _confirmBtn.frame = CGRectMake(120, 120, 120, 120);
    });
}


- (void)setModuleInfo:(NSMutableDictionary *)newModuleInfo
{
    _moduleInfo = newModuleInfo;
    
    
    NSString *module = [[[_moduleInfo objectForKey:@"N"] componentsSeparatedByString:@"("] objectAtIndex:0];
    _deviceImg.image = [UIImage imageNamed:[NSString stringWithFormat:@"%@.png", module]];
    if(_deviceImg.image==nil)
        _deviceImg.image = [UIImage imageNamed:@"known_logo.png"];
    
    _deviceTitle.text = [_moduleInfo objectForKey:@"N"];
    _deviceDetail.text = [[NSString alloc] initWithFormat:@"Protocol: %@\r\nFirmware: %@\r\nHardware: %@\r\nRF version:%@", [_moduleInfo objectForKey:@"PO"], [_moduleInfo objectForKey:@"FW"], [_moduleInfo objectForKey:@"HD"], [_moduleInfo objectForKey:@"RF"]];
    self.tag = [[_moduleInfo objectForKey:@"tag"] longValue];
    _confirmBtn.tag = self.tag;
    _settingBtn.tag = self.tag;
    _updateBtn.tag = self.tag;
    _ignoreBtn.tag = self.tag;
    
}
- (IBAction)buttonPressed: (UIButton *)sender
{
    if(sender == _confirmBtn){
        NSLog(@"Confirm pressed");
        if( [[_moduleInfo objectForKey:@"FTC"] boolValue] == YES ){
            if([theDelegate respondsToSelector:@selector(onConfigured:)])
                [theDelegate performSelector:@selector(onConfigured:) withObject:_moduleInfo];
        }
        else{
            if([theDelegate respondsToSelector:@selector(onIgnored:)])
                [theDelegate performSelector:@selector(onIgnored:) withObject:_moduleInfo];
        }
    }else if(sender == _settingBtn){
        NSLog(@"Setting pressed, tag = %ld", (long)self.tag );
    }else if(sender == _updateBtn){
        NSLog(@"Update pressed");
    }else if(sender == _ignoreBtn){
        NSLog(@"Ignore pressed");
        if([theDelegate respondsToSelector:@selector(onIgnored:)])
            [theDelegate performSelector:@selector(onIgnored:) withObject:_moduleInfo];
    }
}

//- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
//{
//    if ([[segue identifier] isEqualToString:@"First Time Configuration"]) {
//        //NSIndexPath *indexPath = [foundModuleTableView indexPathForSelectedRow];
//        //[foundModuleTableView deselectRowAtIndexPath:indexPath animated:YES];
////        NSMutableDictionary *object = [self.foundModules objectAtIndex:indexPath.row];
////        
////        //[easylink_config stopTransmitting];
////        //easylink_config = nil;
////        if ( EasylinkV2Button.selected )
////            [self easyLinkV2ButtonAction:EasylinkV2Button]; /// Simply revert the state
//        
//        [[segue destinationViewController] setConfigData:_moduleInfo];
//        [(EasyLinkFTCTableViewController *)[segue destinationViewController] setDelegate:theDelegate];
//        
//    }
//}

@end




