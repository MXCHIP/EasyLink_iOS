//
//  mxchipDetailViewController.m
//  EMW ToolBox
//
//  Created by William Xu on 13-7-26.
//  Copyright (c) 2013年 MXCHIP Co;Ltd. All rights reserved.
//

#import "mxchipDetailViewController.h"

@interface mxchipDetailViewController ()
- (void)configureView;
@end

@implementation mxchipDetailViewController

#pragma mark - Managing the detail item

- (void)setDetailItem:(id)newDetailItem
{
    if (_detailItem != newDetailItem) {
        _detailItem = newDetailItem;
        
        // Update the view.
        [self configureView];
    }
}

- (void)configureView
{
    // Update the user interface for the detail item.

    if (self.detailItem) {
        self.detailDescriptionLabel.text = [self.detailItem description];
    }
}

- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view, typically from a nib.
    [self configureView];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end
