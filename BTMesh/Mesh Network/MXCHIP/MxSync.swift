//
//  MxAttributesStatus.swift
//  MICO
//
//  Created by William Xu on 2020/7/22.
//  Copyright © 2020 MXCHIP Co;Ltd. All rights reserved.
//

import Foundation
import nRFMeshProvision

public struct MxSync: MxMessage {
    public static let opCode: UInt32 = 0xD52209
    let tid: UInt8
    let sync: MxAttribute

    public var parameters: Data? {
        guard let data = sync.pdu, !(data.isEmpty) else {
            return nil
        }
        return Data([tid]) + data
    }

    
    public init(tid: UInt8, range: RangeOfSync, maxDelay seconds: UInt16) {
        self.tid = tid
        self.sync = .sync(range, seconds)
    }
    
    public init?(parameters: Data) {
        /// Should have tid and aync attribute
        guard let attribute = MxAttribute(pdu: parameters.subdata(in: 1..<parameters.count)),
              case .sync = attribute else {
            return nil
        }
        
        self.tid =  parameters[0]
        self.sync = attribute
    }
}


