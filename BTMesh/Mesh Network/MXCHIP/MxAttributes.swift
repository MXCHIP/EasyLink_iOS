//
//  MxAttribute.swift
//  MICO
//
//  Created by William Xu on 2020/7/22.
//  Copyright © 2020 MXCHIP Co;Ltd. All rights reserved.
//

import Foundation
import nRFMeshProvision


// MARK: - MxAttributeType
enum MxAttributeType: UInt16 {
    case syncType               = 0x0001
    case quintuplesType         = 0x0003
    case automationType         = 0x0004
    case fwVersionType          = 0x0005
    case buttonIDType           = 0x0007
    case onType                 = 0x0100
    case brightnessType         = 0x0121
    case colorTempType          = 0x0122
    case colorTempPercentType   = 0x01F1

    enum ByteOrder {
        case littleEndian
        case bigEndian
    }
    
    static let size = 2

    init?(pdu: Data) {
        self.init(pdu: pdu, endian: .littleEndian)
    }
    
    init?(pdu: Data, endian: ByteOrder) {
        guard pdu.count >= 2,
              let value: UInt16 = pdu.read() else {
            return nil
        }
        
        switch endian {
        case .bigEndian: self.init(rawValue: value.bigEndian)
        case .littleEndian: self.init(rawValue: value)
        }
    }

    public var pdu: Data {
        return self.rawValue.data
    }
    
    static var attribute: [UInt16 : MxStaticAttribute.Type] {
        let types: [MxStaticAttribute.Type] = [
            MxAttribute.On.self,
            MxAttribute.Quintuples.self,
            MxAttribute.Sync.self,
            MxAttribute.Brightness.self,
            MxAttribute.ColorTemp.self,
            MxAttribute.ColorTempPercent.self,
            MxAttribute.FwVersion.self,
            MxAttribute.ButtonID.self,
            MxAttribute.Automation.self
        ]
        
        var map: [UInt16 : MxStaticAttribute.Type] = [:]
        types.forEach {
            map[$0.type.rawValue] = $0
        }
        return map
    }

}

extension MxAttributeType: CustomDebugStringConvertible {
    
    var debugDescription: String {
        switch self {
        case .syncType:                 return "Sync"
        case .fwVersionType:            return "FW Version"
        case .buttonIDType:             return "Button ID"
        case .quintuplesType:           return "Quintuples"
        case .onType:                   return "On"
        case .brightnessType:           return "Brightness"
        case .colorTempType:            return "Color Temperature"
        case .colorTempPercentType:     return "Color Temperature"
        case .automationType:           return "Automatic Rules"
        }
    }
    
}

// MARK: - MxGenericAttribute
protocol MxGenericAttribute {
    var typeValue: UInt16 { get }
    var pdu: Data? { get }
    var length: Int { get }
    init()
    init?(pdu: Data)
}

protocol UnknownAttribute: MxGenericAttribute {
    var value: Data { get set }
}

protocol MxStaticAttribute: MxGenericAttribute {
    static var type: MxAttributeType { get }
    var name: String { get }
}

protocol MxFixedLengthAttribute: MxStaticAttribute {
    static var valueSize: Int { get }
}

extension MxFixedLengthAttribute {
    var length: Int {
        return MxAttributeType.size + Self.valueSize
    }
}

// MARK: - MxStringValue
protocol MxStringValue: MxStaticAttribute {
        
    var value: String { get set }
    var rw: Bool { get }
}

// MARK: - MxBoolValue
protocol MxBoolValue: MxFixedLengthAttribute {
        
    var value: Bool { get set }
    var rw: Bool { get }
}

extension MxBoolValue {
    
    var unit: String? {
        return nil
    }
    
    init?(pdu: Data) {
        guard pdu.count >= 3,
              let typeValue: UInt16 = pdu.read(), typeValue == Self.type.rawValue  else {
            return nil
        }
        self.init()
        self.value = pdu[2] == 0 ? false : true
    }

    var pdu: Data? {
        var pdu = Data()
        pdu += Self.type.pdu
        pdu += value ? UInt8(0x1) : UInt8(0x0)
        return pdu
    }
    
}

// MARK: - MxIntegerValue

protocol MxIntegerValue: MxFixedLengthAttribute {
    var value: Int { get set }
    var rw: Bool { get }
    var unit: String? { get }
    init()
}

protocol MxRange: MxIntegerValue {
    var min: Int { get }
    var max: Int { get }
}


protocol MxUInt16IntegerValue: MxIntegerValue {
    
}

extension MxUInt16IntegerValue {
    
    init?(pdu: Data) {
        guard pdu.count >= MxAttributeType.size + Self.valueSize,
              let value: UInt16 = pdu.subdata(in: 2 ..< 2 + Self.valueSize).read(),
              let typeValue: UInt16 = pdu.read(), typeValue == Self.type.rawValue else {
            return nil
        }
        self.init()
        self.value = Int(value)
    }
    
    var pdu: Data? {
        var pdu = Data()
        pdu += Self.type.pdu
        pdu += Data(from: UInt16(self.value))
        return pdu
    }

}

protocol MxUInt8IntegerValue: MxIntegerValue {
    
}

extension MxUInt8IntegerValue {
    
    init?(pdu: Data) {
        guard pdu.count >= MxAttributeType.size + Self.valueSize,
              let value: UInt8 = pdu.subdata(in: 2 ..< 2 + Self.valueSize).read(),
              let typeValue: UInt16 = pdu.read(), typeValue == Self.type.rawValue else {
            return nil
        }
        self.init()
        self.value = Int(value)
    }
    
    var pdu: Data? {
        var pdu = Data()
        pdu += Self.type.pdu
        pdu += Data(from: UInt8(self.value))
        return pdu
    }

}




// MARK: - MxAttribute
struct MxAttribute {
    
    static func decode(pdu: Data) -> MxGenericAttribute?  {
        
        guard let type: UInt16 = pdu.read() else { return nil }
        
        // 确认已知的属性能够按照格式解码成功
        if let attributeType = MxAttributeType.attribute[type] {
            return attributeType.init(pdu: pdu)
        } else {
            return MxAttribute.Unknown(type, pdu.subdata(in: 2..<pdu.count))
        }
    }
    
    struct Unknown: UnknownAttribute {
        
        var value: Data
        var typeValue: UInt16
                
        var length: Int {
            return MxAttributeType.size + value.count
        }
        
        init() {
            self.typeValue = 0
            self.value = Data()
        }
        
        init(_ typeValue: UInt16, _ value: Data) {
            self.typeValue = typeValue
            self.value = value
        }
        
        init?(pdu: Data) {
            guard pdu.count > 2, let type: UInt16 = pdu.read() else { return nil }
            self.typeValue = type
            self.value = pdu.subdata(in: 2..<pdu.count)
        }

        var pdu: Data? {
            var pdu = Data()
            pdu += Data(from: typeValue)
            pdu += value
            return pdu
        }
        
    }
    
}

// MARK: - Default values

extension MxStaticAttribute {
    var typeValue: UInt16 {
        return Self.type.rawValue
    }
    
    var name: String {
        let type: MxAttributeType = MxAttributeType(rawValue: self.typeValue)!
        return "\(type.debugDescription)"
    }
}

// MARK: - Array Extension

extension Array where Element == MxGenericAttribute {
    
    mutating func insert(_ newAttribute: MxGenericAttribute) {
        if let index = firstIndex(where: { $0.typeValue == newAttribute.typeValue }) {
            self[index] = newAttribute
            } else {
                self.append(newAttribute )
            }
    }
    
    mutating func insert(_ newAttributes: [MxGenericAttribute]) {
        newAttributes.forEach {
            insert($0)
        }
    }
    
}


