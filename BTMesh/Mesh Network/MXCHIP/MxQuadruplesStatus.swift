//
//  MXQuadruplesStatus.swift
//  MICO
//
//  Created by William Xu on 2020/6/4.
//  Copyright © 2020 MXCHIP Co;Ltd. All rights reserved.
//

import Foundation
import nRFMeshProvision


public struct MxQuadruplesStatus: MxMessage {
    public static let opCode: UInt32 = 0xC15D00
    
    public var parameters: Data? {
        guard let productIdBytes = productId!.data(using: .ascii),
              let productKeyBytes = productKey!.data(using: .ascii),
              let productSecretBytes = productSecret!.data(using: .ascii),
              let deviceNameBytes = deviceName!.data(using: .ascii),
              let deviceSecretBytes = deviceSecret!.data(using: .ascii),
              isQuadruplesKnown == true else {
            return nil
        }
        
        var data = Data()
        let seperator = Data([0x20])
        
        data += productKeyBytes
        data += seperator
        data += productSecretBytes
        data += seperator
        data += deviceNameBytes
        data += seperator
        data += deviceSecretBytes
        data += seperator
        data += productIdBytes
        
        return data
        
    }
    
    /// Product key string.
    public let productId: String?
    /// Product key string.
    public let productKey: String?
    /// Product secrect string.
    public let productSecret: String?
    /// Device name string.
    public let deviceName: String?
    /// Device secrect string.
    public let deviceSecret: String?
    
    
    /// Whether the quadruples is known.
    public var isQuadruplesKnown: Bool {
        guard let _ = productKey, let _ = productSecret, let _ = deviceName, let _ = deviceSecret else {
            return false
        }
        return true
    }
    
    public init() {
        self.productId = String()
        self.productKey = String()
        /// Product secrect string.
        self.productSecret = String()
        /// Device name string.
        self.deviceName = String()
        /// Device secrect string.
        self.deviceSecret = String()
    }
    
    public init?(parameters: Data) {
        let quadruples:[Data] = parameters.split(separator: 0x20)

        guard quadruples.count == 5 else {
            return nil
        }

        
        productKey = String(data: quadruples[0], encoding: .ascii)
        productSecret = String(data: quadruples[1], encoding: .ascii)
        deviceName = String(data: quadruples[2], encoding: .ascii)
        deviceSecret = String(data: quadruples[3], encoding: .ascii)
        productId = String(data: quadruples[4], encoding: .ascii)
    }
    
}

