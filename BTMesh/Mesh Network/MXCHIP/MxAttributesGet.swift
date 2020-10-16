//
//  MxAttributeGet.swift
//  MICO
//
//  Created by William Xu on 2020/7/22.
//  Copyright © 2020 MXCHIP Co;Ltd. All rights reserved.
//

import Foundation
import nRFMeshProvision

public struct MxAttributesGet: AcknowledgedMxMessage {
    public static let opCode: UInt32 = 0xD02209
    public static let responseType: StaticMeshMessage.Type = MxAttributesStatus.self
    
    let tid: UInt8
    let types: [MxAttributeType]
    
    public var parameters: Data? {
        var data = Data()
        data += tid
        types.forEach { data += $0.pdu }
        return data
    }
    
    public init(tid: UInt8, types: [MxAttributeType]) {
        self.types = types
        self.tid = tid
    }
    
    public init?(parameters: Data) {
        /// Should have tid and at least one attribute type
        guard parameters.count >= 3 else {
            return nil
        }
        
        /// Parse all types
        var types :[MxAttributeType] = []
        let typtesData = parameters[1...]
        
        for index in 0..<typtesData.count/2 {
            if let type = MxAttributeType(pdu: typtesData[(index * 2)...]) {
                types.append(type)
            }
        }
        
        guard types.count > 0 else {
            return nil
        }
        
        self.tid = parameters[0]
        self.types = types
        
    }
    
}
