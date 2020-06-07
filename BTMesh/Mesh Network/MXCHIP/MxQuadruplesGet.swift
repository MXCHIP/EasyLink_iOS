//
//  MXQuadruplesGet.swift
//  MICO
//
//  Created by William Xu on 2020/6/4.
//  Copyright © 2020 MXCHIP Co;Ltd. All rights reserved.
//

import Foundation
import nRFMeshProvision

public struct MxQuadruplesGet: AcknowledgedMxMessage {
    public static let opCode: UInt32 = 0xC05D00
    public static let responseType: StaticMeshMessage.Type = MxQuadruplesStatus.self
    
    public var parameters: Data? {
        return nil
    }
    
    public init() {
        // Empty
    }
    
    public init?(parameters: Data) {
        guard parameters.isEmpty else {
            return nil
        }
    }
    
}
