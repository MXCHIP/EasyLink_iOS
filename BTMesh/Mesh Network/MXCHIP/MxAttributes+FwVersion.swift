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
    
    struct FwVersion: MxStringValue, MxFixedLengthAttribute {
        
        static var type: MxAttributeType = .fwVersionType
        static var valueSize: Int = 3 * MemoryLayout<UInt8>.size
        
        var major: UInt8, minor: UInt8, minus: UInt8
        var value: String {
            get {
                return "\(major).\(minor).\(minus)"
            }
            set(newVersion){
                let versions = newVersion.split(separator: ".")
                major = UInt8(versions[0]) ?? 255
                minor = UInt8(versions[1]) ?? 255
                minus = UInt8(versions[2]) ?? 255
            }
        }
        var rw: Bool = false

        var pdu: Data? {
            return Data(from: major) + Data(from: minor) + Data(from: minus)
        }
        
        init() {
            self.major = 0
            self.minor = 0
            self.minus = 0
        }
        
        init(_ major: UInt8, _ minor: UInt8, _ minus: UInt8) {
            self.major = major
            self.minor = minor
            self.minus = minus
        }
        
        init?(pdu: Data) {
            guard let typeValue: UInt16 = pdu.read(), typeValue == Self.type.rawValue,
                  let major: UInt8 = pdu.read(fromOffset: 2),
                  let minor: UInt8 = pdu.read(fromOffset: 3),
                  let minus: UInt8 = pdu.read(fromOffset: 4) else {
                return nil
            }
            
            self.init(major, minor, minus)
        }
    }
    
}

