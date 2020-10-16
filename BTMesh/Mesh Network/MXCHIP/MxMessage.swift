//
//  MXMessage.swift
//  MICO
//
//  Created by William Xu on 2020/6/4.
//  Copyright © 2020 MXCHIP Co;Ltd. All rights reserved.
//

import Foundation
import nRFMeshProvision

public protocol MxAttributeStatusMessage: MxMessage {
    var attributes: [MxAttribute] { get }
}

public protocol MxMessage: StaticMeshMessage {
    // No additional fields.
}

public protocol AcknowledgedMxMessage: MxMessage, StaticAcknowledgedMeshMessage {
    // No additional fields.
}

public protocol MxStatusMessage: StatusMessage {
    // No additional fields.
}

public extension Array where Element == MxMessage.Type {
    
    /// A helper method that can create a map of message types required
    /// by the `ModelDelegate` from a list of `MXMessage`s.
    ///
    /// - returns: A map of message types.
    func toMap() -> [UInt32 : MeshMessage.Type] {
        return (self as [StaticMeshMessage.Type]).toMap()
    }
    
}
