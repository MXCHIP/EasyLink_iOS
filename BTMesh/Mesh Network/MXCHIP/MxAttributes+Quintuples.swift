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

    struct Quintuples: MxStaticAttribute {
        
        static var type: MxAttributeType = .quintuplesType
        
        var pk: String, ps: String, dn: String, ds: String, pid: String
        
        init() {
            self.pk = ""
            self.ps = ""
            self.dn = ""
            self.ds = ""
            self.pid = ""
        }
        
        init(_ pk: String, _ ps: String, _ dn: String, _ ds: String, _ pid: String) {
            self.pk = pk
            self.ps = ps
            self.dn = dn
            self.ds = ds
            self.pid = pid
        }
         
        init?(pdu: Data) {
            guard let typeValue: UInt16 = pdu.read(), typeValue == Self.type.rawValue else {
                return nil
            }
            
            let valueData = pdu.subdata(in: 2..<pdu.count)
            let quintuples:[Data] = valueData.split(separator: 0x20)

            guard quintuples.count >= 5,
                  let pk = String(data: quintuples[0], encoding: .ascii),
                  let ps = String(data: quintuples[1], encoding: .ascii),
                  let dn = String(data: quintuples[2], encoding: .ascii),
                  let ds = String(data: quintuples[3], encoding: .ascii),
                  let pid = String(data: quintuples[4], encoding: .ascii) else {
                return nil
            }
            
            self.init(pk, ps, dn, ds, pid)
        }
        
        var pdu: Data? {
            guard let productKeyBytes = pk.data(using: .ascii),
                  let productSecretBytes = ps.data(using: .ascii),
                  let deviceNameBytes = dn.data(using: .ascii),
                  let deviceSecretBytes = ds.data(using: .ascii),
                  let productIdBytes = pid.data(using: .ascii) else {
                return nil
            }
            let seperater = UInt8(0x20).data
            let valueData = productKeyBytes + seperater + productSecretBytes + seperater + deviceNameBytes + seperater + deviceSecretBytes + seperater + productIdBytes
            
            return typeValue.littleEndian.data + valueData
        }
        
        var length: Int {
            return (pk+ps+dn+ds+pid).count + 4
        }
    }
    
}

