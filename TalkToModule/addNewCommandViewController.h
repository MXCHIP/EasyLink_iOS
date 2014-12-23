//
//  addNewCommandViewController.h
//  MICO
//
//  Created by William Xu on 14-5-13.
//  Copyright (c) 2014年 MXCHIP Co;Ltd. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface addNewCommandViewController : UIViewController<UITextFieldDelegate, UITextViewDelegate, UITableViewDataSource, UITableViewDelegate>{
    NSUInteger commandIndex;
    IBOutlet UITableView *editTableView;
    UITextField *subjectTextFiled;
    UITextView *detailTextView;
    id theDelegate;
    IBOutlet UIBarButtonItem *typeButton;
}

@property (strong, nonatomic) NSString *subject;
@property (strong, nonatomic) NSData *detail;
@property (strong, nonatomic) NSString *type;


- (id)delegate;
- (void)setDelegate:(id)delegate;

- (IBAction)finishEditing: (UIBarButtonItem *)button;
- (IBAction)cancel: (UIBarButtonItem *)button;
- (IBAction)typeChanged: (UIBarButtonItem *)button;

- (void)setSubject: (NSString *)inSubject withDetail:(NSData *)inDetail  forType: (NSString *) inType;


@end
