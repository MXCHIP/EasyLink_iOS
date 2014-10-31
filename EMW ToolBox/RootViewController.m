//
//  RootViewController.m
//  MICO
//
//  Created by William Xu on 14-5-15.
//  Copyright (c) 2014年 MXCHIP Co;Ltd. All rights reserved.
//

#import "RootViewController.h"
#import "ConThingsViewController.h"
#import "browserViewController.h"

@interface RootViewController ()

@property (nonatomic, strong) UIScrollView *scrollView;

@end

@implementation RootViewController

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Custom initialization
    }
    return self;
}

- (void)awakeFromNib
{
    sleep(1);
    [super awakeFromNib];
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    // Segmented control with scrolling
    //sceneSegment = [[HMSegmentedControl alloc] initWithSectionTitles:@[@"Home", @"ConThings"]];
    sceneSegment = [[HMSegmentedControl alloc] initWithSectionTitles:@[@"Home"]];
    sceneSegment.autoresizingMask = UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleWidth;
    sceneSegment.frame = CGRectMake(0, 44 + 20, 320, 40);
    sceneSegment.segmentEdgeInset = UIEdgeInsetsMake(0, 10, 0, 10);
    sceneSegment.selectionIndicatorHeight = 2.0f;
    sceneSegment.backgroundColor = [UIColor colorWithRed:0.1 green:0.4 blue:0.8 alpha:1];
    sceneSegment.textColor = [UIColor whiteColor];
    sceneSegment.selectedTextColor = [UIColor whiteColor];
    sceneSegment.selectionIndicatorColor = [UIColor colorWithRed:0.5 green:0.8 blue:1 alpha:1];
    sceneSegment.selectionStyle = HMSegmentedControlSelectionStyleBox;
    sceneSegment.selectionIndicatorLocation = HMSegmentedControlSelectionIndicatorLocationUp;
    sceneSegment.scrollEnabled = YES;
    [sceneSegment addTarget:self action:@selector(segmentedControlChangedValue:) forControlEvents:UIControlEventValueChanged];
    [self.view addSubview:sceneSegment];
    
    self.scrollView = [[UIScrollView alloc] initWithFrame:CGRectMake(0, 104, 320, 464)]; //20+44+40 (status+nav+segcontrol)
    self.scrollView.backgroundColor = [UIColor colorWithRed:0.7 green:0.7 blue:0.7 alpha:1];
    self.scrollView.pagingEnabled = YES;
    self.scrollView.showsHorizontalScrollIndicator = NO;
    self.scrollView.contentSize = CGSizeMake(320, 464);
    self.scrollView.delegate = self;
    [self.scrollView scrollRectToVisible:CGRectMake(0, 0, 320, 464) animated:YES];
    [self.view addSubview:self.scrollView];

    //ConThingsViewController *ConThings = [self.storyboard instantiateViewControllerWithIdentifier:@"ConThings"];
    browserViewController *localDevice = [self.storyboard instantiateViewControllerWithIdentifier:@"Local Device"];
    
    /*Local devices list*/
    localDevice.view.frame = CGRectMake(0, -35, 320, 464 );
    [localDevice willMoveToParentViewController:self];
    [self.scrollView addSubview:localDevice.view];
    [self addChildViewController:localDevice];
    [localDevice didMoveToParentViewController:self];
    
    
//    /*Devices list on www.conthings.com*/
//    ConThings.view.frame = CGRectMake(320, 0, 320, 464);
//    
//    [ConThings willMoveToParentViewController:self];
//    [self.scrollView addSubview:ConThings.view];
//    [self addChildViewController:ConThings];
//    [ConThings didMoveToParentViewController:self];

}

- (void)segmentedControlChangedValue:(HMSegmentedControl *)segmentedControl {
	NSLog(@"Selected index %ld (via UIControlEventValueChanged)", (long)segmentedControl.selectedSegmentIndex);
    [self.scrollView scrollRectToVisible:CGRectMake(segmentedControl.selectedSegmentIndex*320, 0, 320, 500) animated:YES];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (IBAction) guideButtonPressed: (UIButton *) button
{
    NSString *textURL = @"http://www.mxchip.com/mico/begin/micoapis/";
    NSURL *cleanURL = [NSURL URLWithString:[NSString stringWithFormat:@"%@", textURL]];
    [[UIApplication sharedApplication] openURL:cleanURL];
}

#pragma mark - UIScrollViewDelegate

- (void)scrollViewDidEndDecelerating:(UIScrollView *)scrollView {
    CGFloat pageWidth = scrollView.frame.size.width;
    NSInteger page = scrollView.contentOffset.x / pageWidth;
    
    [sceneSegment setSelectedSegmentIndex:page animated:YES];
}

/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/

@end
