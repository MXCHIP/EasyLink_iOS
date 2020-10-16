//
//  MxClientDelegate.swift
//  MICO
//
//  Created by William Xu on 2020/6/4.
//  Copyright © 2020 MXCHIP Co;Ltd. All rights reserved.
//

import Foundation
import nRFMeshProvision

class MxClientDelegate: ModelDelegate {
    let messageTypes: [UInt32 : MeshMessage.Type]
    let isSubscriptionSupported: Bool = false
    
    init() {
        let types: [MxMessage.Type] = [
            MxAttributesStatus.self,
            MxHeartbeat.self
        ]
        messageTypes = types.toMap()
    }
    
    // MARK: - Message handlers
    
    func model(_ model: Model, didReceiveAcknowledgedMessage request: AcknowledgedMeshMessage,
               from source: Address, sentTo destination: MeshAddress) -> MeshMessage {
        fatalError("Not possible")
    }
    
    func model(_ model: Model, didReceiveUnacknowledgedMessage message: MeshMessage,
               from source: Address, sentTo destination: MeshAddress) {
        // The status message may be received here if the Generic OnOff Server model
        // has been configured to publish. Ignore this message.
    }
    
    func model(_ model: Model, didReceiveResponse response: MeshMessage,
               toAcknowledgedMessage request: AcknowledgedMeshMessage,
               from source: Address) {
        // Ignore.
    }
    
}
