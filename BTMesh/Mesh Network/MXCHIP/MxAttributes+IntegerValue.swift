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
    
    struct Brightness: MxUInt16IntegerValue, MxRange {
        
        static var type: MxAttributeType = .brightnessType
        static var valueSize: Int = MemoryLayout<UInt16>.size
        
        var unit: String?
        
        var value: Int = 50
        var min: Int = 0
        var max: Int = 100
        var rw: Bool = true
        
        init() { }

    }
    
    struct ColorTemp: MxUInt16IntegerValue, MxRange {
                
        static var type: MxAttributeType = .colorTempType
        static var valueSize: Int = MemoryLayout<UInt16>.size
        
        var value: Int = 4000
        var min: Int = 2700
        var max: Int = 6500
        var unit: String? = "Kelvins"
        var rw: Bool = true
        
        init() { }
        
    }
    
    struct ColorTempPercent: MxUInt8IntegerValue, MxRange {
                
        static var type: MxAttributeType = .colorTempPercentType
        static var valueSize: Int = MemoryLayout<UInt8>.size
        
        var value: Int = 50
        var min: Int = 0
        var max: Int = 100
        var unit: String? = "%"
        var rw: Bool = true
        
        init() { }
        
    }
    
    struct ButtonID: MxUInt8IntegerValue {
        
        static var type: MxAttributeType = .buttonIDType
        static var valueSize: Int = MemoryLayout<UInt8>.size
        
        var unit: String?
        
        var value: Int = 0
        var rw: Bool = false
        
        init() { }

    }
    
}

