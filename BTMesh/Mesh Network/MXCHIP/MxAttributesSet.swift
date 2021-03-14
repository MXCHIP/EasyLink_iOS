//
//  MxAttributesStatus.swift
//  MICO
//
//  Created by William Xu on 2020/7/22.
//  Copyright © 2020 MXCHIP Co;Ltd. All rights reserved.
//

import Foundation
import nRFMeshProvision


struct MxAttributesSet: MxMessage {
    static let opCode: UInt32 = 0xD12209
    
    public var isSegmented: Bool {
        return true
    }
    
    var attributes: [MxGenericAttribute]
    var tid: UInt8

    var parameters: Data? {
        var data = Data()
        
        attributes.forEach{
            if let pdu = $0.pdu {
                 data += pdu
            }
        }
        
        guard !data.isEmpty else {
            return nil
        }
        return Data([tid]) + data
    }
    
    init(tid: UInt8, attributes: [MxGenericAttribute]) {
        self.tid = tid
        self.attributes = attributes
    }
    
    init?(parameters: Data) {
        /// Should have tid and at least one attribute type
        guard parameters.count >= 3 else {
            return nil
        }
        var attributes: [MxGenericAttribute] = []
        var index = 1

        while index < parameters.count {
            guard let attribute = MxAttribute.decode(pdu: parameters[index...]) else {
                return nil
            }
            attributes.append(attribute)
            
            guard case let fixedLengthAttribute as MxFixedLengthAttribute = attribute else { break }
            index += fixedLengthAttribute.length
        }
        
        self.tid =  parameters[0]
        self.attributes = attributes
    }
    
}


