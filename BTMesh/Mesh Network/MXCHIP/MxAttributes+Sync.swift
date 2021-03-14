//
//  MxAttribute.swift
//  MICO
//
//  Created by William Xu on 2020/7/22.
//  Copyright © 2020 MXCHIP Co;Ltd. All rights reserved.
//

import Foundation
import nRFMeshProvision


extension MxAttribute {
    
    struct Sync: MxStaticAttribute {
        
        enum RangeOfSync: UInt8 {
            case mainAttribute = 0x01
            case allAttribute  = 0xFF
        }
        
        static var type: MxAttributeType = .syncType
        
        let delay: UInt16
        let range: RangeOfSync
        var length: Int = MxAttributeType.size + MemoryLayout<UInt8>.size + MemoryLayout<UInt16>.size
        
        var pdu: Data? {
            return Data() + Data(from: range.rawValue) + Data(from: delay)
        }
        
        init() {
            self.delay = 5
            self.range = .mainAttribute
        }
        
        init(_ delay: UInt16, _ range: RangeOfSync) {
            self.delay = delay
            self.range = range
        }
        
        init?(pdu: Data) {
            guard pdu.count >= 3,
                  let typeValue: UInt16 = pdu.read(), typeValue == Self.type.rawValue,
                  let delay: UInt16 = pdu.read(fromOffset: 2),
                  let range = RangeOfSync(rawValue: pdu[1]) else {
                return nil
            }
            
            self.init(delay, range)
        }
    }
    
}

