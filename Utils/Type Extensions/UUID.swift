//
//  UUID.swift
//  MICO
//
//  Created by William Xu on 2020/6/4.
//  Copyright © 2020 MXCHIP Co;Ltd. All rights reserved.
//


import Foundation

extension UUID {
    
    /// Creates the UUID from a 32-character hexadecimal string.
    init?(hex: String) {
        guard hex.count == 32 else {
            return nil
        }
        
        var uuidString = ""
        
        for (offset, character) in hex.enumerated() {
            if offset == 8 || offset == 12 || offset == 16 || offset == 20 {
                uuidString.append("-")
            }
            uuidString.append(character)
        }
        guard let uuid = UUID(uuidString: uuidString) else {
            return nil
        }
        self.init(uuid: uuid.uuid)
    }
    
    /// Returns the uuidString without dashes.
    var hex: String {
        return uuidString.replacingOccurrences(of: "-", with: "")
    }
    
    /// The UUID as Data.
    var data: Data {
        return withUnsafeBytes(of: uuid, { Data($0) })
    }
    
    
    /// MXCHIP format,
    var companyIdentifier: UInt16 {
        return data.read()!
    }
    
    var productID: UInt32 {
        let productID: UInt32! = withUnsafeBytes(of: uuid, { Data($0) }).read(fromOffset: 3)
        return productID
    }

    var macString: String {
        let macData = withUnsafeBytes(of: uuid, { Data($0).subdata(in: 7..<13)})
        return String(format: "%02X:%02X:%02X:%02X:%02X:%02X", macData[5], macData[4],macData[3],macData[2],macData[1],macData[0])
    }
    
    var version: UInt8 {
        let features: UInt8! = withUnsafeBytes(of: uuid, { Data($0) }).read(fromOffset: 13)
        return features >> 1
    }
    
    var advType: AdvType {
        let features: UInt8! = withUnsafeBytes(of: uuid, { Data($0) }).read(fromOffset: 13)
        return AdvType(rawValue: features & 0x1 )!
    }
    
    var isMXCHIPFormat: Bool {
        return companyIdentifier == 0x01A8 || companyIdentifier == 0x0922
    }
    
}

enum AdvType: UInt8 {
    case unprovisionedBeacon = 0x0
    case sclienceBeacon      = 0x1
}
