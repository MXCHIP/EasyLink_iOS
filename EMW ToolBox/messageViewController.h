//
//  talkToModuleViewController.h
//  MICO
//
//  Created by William Xu on 14-5-6.
//  Copyright (c) 2014年 MXCHIP Co;Ltd. All rights reserved.
//

#import "JSMessagesViewController.h"

@interface messageViewController : JSMessagesViewController{
}
@property (strong, nonatomic) NSString *messageRecordFileName;

- (void)recvInComingData: (NSData *)data;
- (void)recvOutputData: (NSData *)data;

- (void)releaseDelegate;


@end
