//
//  MXQuadruplesSet.swift
//  MICO
//
//  Created by William Xu on 2020/6/4.
//  Copyright © 2020 MXCHIP Co;Ltd. All rights reserved.
//

import Foundation
import nRFMeshProvision

public struct MxQuadruplesSet: AcknowledgedMxMessage {
    public static let opCode: UInt32 = 0xC35D00
    public static let responseType: StaticMeshMessage.Type = MxQuadruplesStatus.self
    
    
    public var parameters: Data? {
        guard let productIdBytes = productId!.data(using: .ascii),
              let productKeyBytes = productKey!.data(using: .ascii),
              let productSecretBytes = productSecret!.data(using: .ascii),
              let deviceNameBytes = deviceName!.data(using: .ascii),
              let deviceSecretBytes = deviceSecret!.data(using: .ascii) else {
            return nil
        }
        
        var data = Data()
        let seperator = Data([0x20])
        data += productIdBytes
        data += seperator
        data += productKeyBytes
        data += seperator
        data += productSecretBytes
        data += seperator
        data += deviceNameBytes
        data += seperator
        data += deviceSecretBytes
        
        return data
    }
    
    /// Product key string.
    let productId: String!
    /// Product key string.
    let productKey: String?
    /// Product secrect string.
    let productSecret: String?
    /// Device name string.
    let deviceName: String?
    /// Device secrect string.
    let deviceSecret: String?
    
    /// Creates the MXCHIP quadruples Set message.
    public init(pid: String, pk: String, ps: String, dn: String, ds: String) {
        self.productId = pid
        self.productKey = pk
        self.productSecret = ps
        self.deviceName = dn
        self.deviceSecret = ds
    }
    
    public init?(parameters: Data) {
        let quadruples:[Data] = parameters.split(separator: 0x0)

        guard quadruples.count == 5 else {
            return nil
        }
        
        productId = String(data: quadruples[0], encoding: .ascii)
        productKey = String(data: quadruples[1], encoding: .ascii)
        productSecret = String(data: quadruples[2], encoding: .ascii)
        deviceName = String(data: quadruples[3], encoding: .ascii)
        deviceSecret = String(data: quadruples[4], encoding: .ascii)
    }
    
}
