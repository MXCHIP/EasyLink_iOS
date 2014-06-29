//
//  addNewCommandViewController.m
//  MICO
//
//  Created by William Xu on 14-5-13.
//  Copyright (c) 2014年 MXCHIP Co;Ltd. All rights reserved.
//

#import "addNewCommandViewController.h"
#import "UIView+AnimationOptionsForCurve.h"
#import "commandsTableViewController.h"
#import "UIViewController+KNSemiModal.h"


#define INPUT_HEIGHT 46.0f


/* transform src string to hex mode
 * example: "aabbccddee" => 0xaabbccddee
 * each char in the string must 0~9 a~f A~F, otherwise return 0
 * return the real obuf length
 */
extern unsigned int str2hex(unsigned char *ibuf, unsigned char *obuf,
                            unsigned int olen);


@interface addNewCommandViewController ()

@end

@implementation addNewCommandViewController
@synthesize subject;
@synthesize detail;
@synthesize type;

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Custom initialization
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

- (void)viewDidLoad
{
    [super viewDidLoad];
    NSString *emptyCommand = @"Empty";
    if(self.subject==nil) self.subject = @"New Command";
    if(self.detail==nil) self.detail = [emptyCommand dataUsingEncoding:NSUTF8StringEncoding];
    if(self.type==nil) self.type = @"string";
    
    if([self.type isEqualToString:@"string"])
        typeButton.title = @"UTF-8";
    else
        typeButton.title = @"HEX";
    

    [[NSNotificationCenter defaultCenter] addObserver:self
											 selector:@selector(handleWillShowKeyboard:)
												 name:UIKeyboardWillShowNotification
                                               object:nil];
    
	[[NSNotificationCenter defaultCenter] addObserver:self
											 selector:@selector(handleWillHideKeyboard:)
												 name:UIKeyboardWillHideNotification
                                               object:nil];
    
    
    [editTableView scrollToRowAtIndexPath:[NSIndexPath indexPathForRow:0 inSection:0] atScrollPosition:   UITableViewScrollPositionTop animated:NO];

    // Do any additional setup after loading the view from its nib.
}

- (void)dealloc
{
    NSLog(@"Add Command dealloc");
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)setSubject: (NSString *)inSubject withDetail:(NSData *)inDetail  forType: (NSString *) inType
{
    self.subject = inSubject;
    self.detail = inDetail;
    self.type = inType;
    
    if([self.type isEqualToString:@"string"])
        typeButton.title = @"UTF-8";
    else
        typeButton.title = @"HEX";
}


#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return 2;
}


- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    UITableViewCell *cell;
    NSObject *object;
    uint8_t *cbytes;
    
    if(indexPath.row == 0){
        cell = [tableView dequeueReusableCellWithIdentifier:@"Subject" forIndexPath:indexPath];
        for(object in cell.contentView.subviews){
            if([object isKindOfClass:[UITextField class]])
               subjectTextFiled = (UITextField *)object;
        }
         subjectTextFiled.text =  self.subject;
    }
    else{
        cell = [tableView dequeueReusableCellWithIdentifier:@"Detail" forIndexPath:indexPath];
        for(object in cell.contentView.subviews){
            if([object isKindOfClass:[UITextView class]])
                detailTextView = (UITextView *)object;
        }
        
        if([self.type isEqualToString:@"string"]){
            detailTextView.text = [[NSString alloc] initWithData:self.detail encoding:NSUTF8StringEncoding];
        }
        else{
            cbytes = (uint8_t *)[self.detail bytes];
            
            NSString *displayString = [[NSString alloc]init];
            NSUInteger idx;
            for(idx = 0; idx< [self.detail length]; idx++){
                if(idx == [self.detail length] -1 ) //Last byte, remove last space
                    displayString = [displayString stringByAppendingFormat:@"%02x", cbytes[idx]];
                else
                    displayString = [displayString stringByAppendingFormat:@"%02x ", cbytes[idx]];
            }
            detailTextView.text = displayString;
        }
    }

    return cell;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
    return @"Command:";
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    if(indexPath.row == 0){
        return 44.0;
    }
    else{
        return 240.0;
    }
}

#pragma mark - UIBarButtonItem delegate -

- (IBAction)finishEditing: (UIBarButtonItem *)button
{
    char* hexInASCII = nil, * hexInASCIIWithSpace = nil;
    char* hexData = nil;
    NSUInteger idx1, idx2;
    
    
    NSLog(@"Subject = %@", subjectTextFiled.text);
    NSLog(@"Detail = %@", detailTextView.text);
    self.subject = subjectTextFiled.text;
    NSString *detailString = detailTextView.text;
    
    if([self.type isEqualToString:@"string"])
        self.detail = [detailString dataUsingEncoding:NSUTF8StringEncoding];
    else{
        /*"12 34 56 78 90 AB CD" to 0x12 0x34 0x45 0x78 0x90 0xAB 0xCD*/
        NSData *inputHexString = [detailTextView.text dataUsingEncoding:NSUTF8StringEncoding];
        if(inputHexString == nil) goto exit;
        hexInASCIIWithSpace = (char *)[inputHexString bytes];
        hexInASCII = malloc([inputHexString length]);
        hexData = malloc([inputHexString length]);
        for(idx1 = 0, idx2 = 0; idx1 < [inputHexString length]; ){
            if(hexInASCIIWithSpace[idx1]!=0x20){
                if((idx1+1)%3==0){
                    goto exit;
                }
                hexInASCII[idx2++]=hexInASCIIWithSpace[idx1++];
            }
            else{
                if((idx1+1)%3==0)
                    idx1++;
                else
                    goto exit;
            }
        }
        hexInASCII[idx2] = 0x0;
        
        NSUInteger len = str2hex((uint8_t *)hexInASCII, (uint8_t *)hexData,(unsigned int)[inputHexString length]);
        if(len==0) goto exit;
        
        self.detail = [NSData dataWithBytes:hexData length:len];
    exit:
        if(hexData) free(hexData);
        if(hexInASCII) free(hexInASCII);

    }
    
    [theDelegate getNewCommand:self.subject content:self.detail type:self.type];
    
    UIViewController * parent = [self.view containingViewController];
    if([parent isKindOfClass:[UINavigationController class]])
        parent = [(UINavigationController *)parent  topViewController];
    if ([parent respondsToSelector:@selector(dismissSemiModalView)]) {
        [parent dismissSemiModalView];
    }

}

- (IBAction)typeChanged: (UIBarButtonItem *)button
{
    if([button.title isEqualToString:@"UTF-8"]){
        self.type = @"hex";
        typeButton.title = @"HEX";
    }
    else{
        self.type = @"string";
        typeButton.title = @"UTF-8";
    }
    [editTableView reloadData];
}


#pragma mark - UITextfiled delegate -

- (BOOL)textFieldShouldReturn:(UITextField *)textField
{
    [textField resignFirstResponder];
    return YES;
}


#pragma mark - Keyboard notifications
- (void)handleWillShowKeyboard:(NSNotification *)notification
{
    [self keyboardWillShowHide:notification];
}

- (void)handleWillHideKeyboard:(NSNotification *)notification
{
    [self keyboardWillShowHide:notification];
}

- (void)keyboardWillShowHide:(NSNotification *)notification
{
    CGRect keyboardRect = [[notification.userInfo objectForKey:UIKeyboardFrameEndUserInfoKey] CGRectValue];
	UIViewAnimationCurve curve = [[notification.userInfo objectForKey:UIKeyboardAnimationCurveUserInfoKey] integerValue];
	double duration = [[notification.userInfo objectForKey:UIKeyboardAnimationDurationUserInfoKey] doubleValue];
    
    [UIView animateWithDuration:duration
                          delay:0.1f
                        options:[UIView animationOptionsForCurve:curve]
                     animations:^{
                         
                         CGRect inputViewFrame = self.view.frame;
                         CGFloat inputViewFrameY = keyboardRect.origin.y - inputViewFrame.size.height;
                         
                         self.view.frame = CGRectMake(inputViewFrame.origin.x,
                                                                  inputViewFrameY,
                                                                  inputViewFrame.size.width,
                                                                  inputViewFrame.size.height);
                
                     }
                     completion:^(BOOL finished) {
                     }];
}

@end
