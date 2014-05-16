//
//  Protocols.h
//  MICO
//
//  Created by William Xu on 14-5-10.
//  Copyright (c) 2014年 MXCHIP Co;Ltd. All rights reserved.
//

#import <Foundation/Foundation.h>

//@interface Protocols : NSObject
//
//- 
//
//+ (NSData *)dataWithData: (NSData *)data usingProrocol: (NSString *)protocol;

@interface NSData (Additions)
+ (NSData *)dataEncodeWithData: (NSData *)data usingProrocol: (NSString *)protocol;

+ (NSArray*)dataDecodeFromData: (NSData *)data usingProrocol: (NSString *)protocol;

@end
