//
//  Protocols.m
//  MICO
//
//  Created by William Xu on 14-5-10.
//  Copyright (c) 2014年 MXCHIP Co;Ltd. All rights reserved.
//

#import "Protocols.h"

typedef struct _mxchip_cmd_head {
    uint16_t flag; // Allways BB 00
    uint16_t cmd; // commands, return cmd=cmd|0x8000
    uint16_t cmd_status; //return result
    uint16_t datalen;
    uint8_t  data[1];
}mxchip_cmd_head_t;

#define  HA_CMD_HEAD_SIZE 8

uint16_t _calc_sum_ha(void *inData, uint32_t inLen)
{
    uint32_t cksum=0;
    uint16_t *p=inData;
    
    while (inLen > 1)
    {
        cksum += *p++;
        inLen -=2;
    }
    if (inLen)
    {
        cksum += *(uint8_t *)p;
    }
    cksum = (cksum >> 16) + (cksum & 0xffff);
    cksum += (cksum >>16);
    
    return ~cksum;
}

OSStatus check_sum_ha(void *inData, uint32_t inLen)
{
    uint16_t *sum;
    uint8_t *p = (uint8_t *)inData;
    
    return 0;
    // TODO: real cksum
    p += inLen - 2;
    
    sum = (uint16_t *)p;
    
    if (_calc_sum_ha(inData, inLen - 2) != *sum) {  // check sum error
        return -1;
    }
    return 0;
}



@implementation NSData (Additions)
+ (NSData *)dataEncodeWithData: (NSData *)data usingProrocol: (NSString *)protocol
{

    if([protocol isEqualToString:@"com.mxchip.ha"]){
        NSData *outData;
        NSUInteger dataLength = [data length];
        NSUInteger cmdLength = HA_CMD_HEAD_SIZE + dataLength + 2;
        mxchip_cmd_head_t *outCData = malloc(cmdLength);
        outCData->flag = 0x00BB;
        outCData->cmd = 0x0006;
        outCData->cmd_status = 0x0000;
        outCData->datalen = dataLength;
        memcpy(&outCData->data, [data bytes], dataLength);
        uint16_t *check = (uint16_t *)(&outCData->data + dataLength);
        *check = _calc_sum_ha((void *)[data bytes], dataLength);
        outData = [NSData dataWithBytes:outCData length:cmdLength];
        free(outCData);
        return outData;
    }else if([protocol isEqualToString:@"com.mxchip.spp"]){
        return data;
    }else
        return nil;
}

+ (NSArray*)dataDecodeFromData: (NSData *)data usingProrocol: (NSString *)protocol
{
    NSMutableArray *outArray = [NSMutableArray arrayWithCapacity:5];
    if([protocol isEqualToString:@"com.mxchip.ha"]){
        NSUInteger dataLength = [data length];
        mxchip_cmd_head_t *inCData = malloc(dataLength);
        mxchip_cmd_head_t *pCData = inCData;
        memcpy(inCData, [data bytes], dataLength);
        
        
        while(1){
            if(pCData->flag != 0x00BB) break;
            if(pCData->cmd  != (0x0007|0x8000)) break;
            if(check_sum_ha(inCData->data, inCData->datalen + 2) != 0) break;
            NSData *tempData = [NSData dataWithBytes:pCData->data length:pCData->datalen];
            [outArray addObject:tempData];
            pCData = (mxchip_cmd_head_t *)((uint8_t *)pCData + HA_CMD_HEAD_SIZE + inCData->datalen + 2);
            if(pCData > inCData+dataLength) break;
        }
        
        return outArray;
    }else if([protocol isEqualToString:@"com.mxchip.spp"]){
        [outArray addObject:data];
        return outArray;
    }else
        return nil;
}


@end

