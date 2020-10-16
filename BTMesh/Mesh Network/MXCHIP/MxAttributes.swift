//
//  MxAttribute.swift
//  MICO
//
//  Created by William Xu on 2020/7/22.
//  Copyright © 2020 MXCHIP Co;Ltd. All rights reserved.
//

import Foundation
import nRFMeshProvision

public enum MxAttributeType: UInt16 {
    case syncType           = 0x0001
    case fwVersionType      = 0x0005
    case quintuplesType     = 0x0003
    case onType             = 0x0100
    case brightnessType     = 0x0121
    case colorTempType      = 0x0122

    static let length = 2

    init?(pdu: Data) {
        guard pdu.count >= 2, let value: UInt16 = pdu.read() else {
            return nil
        }

        self.init(rawValue: value)
    }

    public var pdu: Data {
        return self.rawValue.data
    }

    public var name: String {
        switch self {
            case .syncType:         return "Sync"
            case .fwVersionType:    return "FW Version"
            case .quintuplesType:   return "Quintuples"
            case .onType:           return "On"
            case .brightnessType:   return "Brightness"
            case .colorTempType:    return "Color Temperature"
        }
    }
}

public enum RangeOfSync: UInt8 {
    case mainAttribute = 0x01
    case allAttribute  = 0xFF
}

public enum MxAttribute {
    case fwVersion(_ major: UInt8, _ minor: UInt8, _ minus: UInt8)
    case quintuples(pk: String, ps: String, dn: String, ds: String, pid: String, length: Int = 0 )
    case on(_ on: Bool)
    case brightness(_ level: UInt16, _ min: UInt16 = 0, _ max: UInt16 = 100)
    case colorTemp(_ level: UInt16, _ min: UInt16 = 0, _ max: UInt16 = 100)
    case sync(_ range: RangeOfSync, _ delay: UInt16)
    case unknown(_ type: UInt16, _ pdu: Data)
    
    public var type: UInt16 {
        switch self {
        case .fwVersion:                return MxAttributeType.fwVersionType.rawValue
        case .sync:                     return MxAttributeType.syncType.rawValue
        case .quintuples:               return MxAttributeType.quintuplesType.rawValue
        case .on:                       return MxAttributeType.onType.rawValue
        case .brightness:               return MxAttributeType.brightnessType.rawValue
        case .colorTemp:                return MxAttributeType.colorTempType.rawValue
        case .unknown(let type, _):     return type
        }
    }
    
     public var length: Int {
        switch self {
        case .fwVersion:
            return MxAttributeType.length + 3 * MemoryLayout<UInt8>.size
        case .sync:
            return MxAttributeType.length + MemoryLayout<UInt8>.size + MemoryLayout<UInt16>.size
        case .quintuples(_, _, _, _, _, let messageLength):
            return MxAttributeType.length + messageLength
        case .on:
            return MxAttributeType.length + MemoryLayout<UInt8>.size
        case .brightness: fallthrough
        case .colorTemp:
            return MxAttributeType.length + MemoryLayout<UInt16>.size
        case .unknown(_, let pdu):
            return MxAttributeType.length + pdu.count
        }
    }
    
    init?(pdu: Data) {
        let pdu = pdu
        
        guard pdu.count > 2 else {
            return nil
        }
        
        let valueData = pdu.subdata(in: 2..<pdu.count)
        
        guard let type = MxAttributeType(pdu: pdu) else {
            let type: UInt16! = pdu.read()
            self = .unknown(type, valueData)
            return
        }
        
        switch type {
        case .fwVersionType:
            guard valueData.count >= 3 else { return nil }
            let major = valueData[0], minor = valueData[1], minus = valueData[2]
            self = .fwVersion(major, minor, minus)
        case .syncType:
            guard let delay: UInt16 = valueData.read(fromOffset: 1),
                  let range = RangeOfSync(rawValue: valueData[0]) else {
                return nil
            }
            self = .sync(range, delay)
        case .quintuplesType:
            let quintuples:[Data] = valueData.split(separator: 0x20)

            guard quintuples.count >= 5 else {
                return nil
            }

            guard let pk = String(data: quintuples[0], encoding: .ascii), let ps = String(data: quintuples[1], encoding: .ascii),
                  let dn = String(data: quintuples[2], encoding: .ascii), let ds = String(data: quintuples[3], encoding: .ascii),
                  let pid = String(data: quintuples[4], encoding: .ascii) else {
                return nil
            }
            
            // 0x20 after every data, 5
            let length = (quintuples[0] + quintuples[1] + quintuples[2] + quintuples[3] + quintuples[4]).count + 5
            
            self = .quintuples(pk: pk, ps: ps, dn: dn, ds: ds, pid: pid, length: length)
        case .onType:
            self = .on(valueData[0] == 0 ? false:true)
        case .brightnessType:
            guard let brightness: UInt16 = valueData.read() else {
                return nil
            }
            self = .brightness(brightness)
        case .colorTempType:
            guard let colorTemperature: UInt16 = valueData.read() else {
                return nil
            }
            self = .colorTemp(colorTemperature)
        }
        
    }

    public var pdu: Data? {
        var pdu = Data()
        
        switch self {
        case let .fwVersion(major, minor, minus):
            pdu += major
            pdu += minor
            pdu += minus
        case let .sync(range, delay):
            pdu += range.rawValue
            pdu += delay
        case let .quintuples(pk, ps, dn, ds, pid, _):
            guard let productKeyBytes = pk.data(using: .ascii), let productSecretBytes = ps.data(using: .ascii),
                  let deviceNameBytes = dn.data(using: .ascii), let deviceSecretBytes = ds.data(using: .ascii),
                  let productIdBytes = pid.data(using: .ascii) else {
                return nil
            }
            pdu += (productKeyBytes + UInt8(0x20)) + (productSecretBytes + UInt8(0x20)) + (deviceNameBytes + UInt8(0x20)) + (deviceSecretBytes + UInt8(0x20)) + productIdBytes
        case let .on(on):
            pdu += on ? UInt8(0x1) : UInt8(0x0)
        case let .colorTemp(level, _, _): fallthrough
        case let .brightness(level, _, _):
            pdu += level.data
        case let .unknown(_, value):
            pdu += value
        }
        
        return self.type.littleEndian.data + pdu
    }
    
    public var value: Data? {
        guard let pdu = self.pdu else {
            return nil
        }
        return pdu.subdata(in: 2..<pdu.count)
    }
}

extension Array where Element == MxAttribute {
    
    mutating func insert(_ newAttribute: MxAttribute) {
        if let index = firstIndex(where: { $0.type == newAttribute.type }) {
                self[index] = newAttribute
            } else {
                self.append(newAttribute)
            }
    }
    
    mutating func insert(_ newAttributes: [MxAttribute]) {
        newAttributes.forEach {
            insert($0)
        }
    }
    
}
