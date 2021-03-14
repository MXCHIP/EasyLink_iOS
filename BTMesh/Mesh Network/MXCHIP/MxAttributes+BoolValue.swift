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

    struct On: MxBoolValue {
        
        static var type: MxAttributeType = .onType
        static var valueSize = MemoryLayout<UInt8>.size
        var value: Bool
        var rw: Bool = true
        
        init() {
            value = false
        }
        
    }

}

