//
//  MxAttributesStatus.swift
//  MICO
//
//  Created by William Xu on 2020/7/22.
//  Copyright © 2020 MXCHIP Co;Ltd. All rights reserved.
//

import Foundation
import nRFMeshProvision


public struct MxHeartbeat: MxAttributeStatusMessage {
    public static let opCode: UInt32 = 0xD42209
    public let attributes: [MxAttribute]
    let tid: UInt8

    public var parameters: Data? {
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

    
    public init(tid: UInt8, attributes: [MxAttribute]) {
        self.attributes = attributes
        self.tid = tid
    }
    
    public init?(parameters: Data) {
        /// Should have tid and at least one attribute type and value pair
        guard parameters.count >= 3 else {
            return nil
        }
        var attributes: [MxAttribute] = []
        var index = 1

        while index < parameters.count {
            guard let attribute = MxAttribute(pdu: parameters.subdata(in: index..<parameters.count)) else {
                return nil
            }
            attributes.append(attribute)
            index += attribute.length
        }
        
        self.tid =  parameters[0]
        self.attributes = attributes
    }
}


