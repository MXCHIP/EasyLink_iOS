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
    
    /// MXCHIP format, version.
    var version: UInt8 {
        return withUnsafeBytes(of: uuid, { Data($0)[0] })
        
    }
    
    /// MXCHIP format, product id.
    var productID: UInt32 {
        let productID: UInt32 = withUnsafeBytes(of: uuid, { Data($0) }).read(fromOffset: 1)
        return UInt32(bigEndian: productID)
    }

    /// MXCHIP format, mac address.
    var macString: String {
        let mac = withUnsafeBytes(of: uuid, { Data($0)[5...10] })
        var macString = mac.map{ String(format: "%02X:", $0) }.joined()
        macString.removeLast()
        return macString
    }
    
}
