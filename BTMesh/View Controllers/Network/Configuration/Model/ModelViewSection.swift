//
//  ModelViewSection.swift
//  MICO
//
//  Created by William Xu on 2020/8/4.
//  Copyright © 2020 MXCHIP Co;Ltd. All rights reserved.
//

import Foundation
import nRFMeshProvision

protocol ModelViewSectionProtocol: class, UITableViewDelegate, UITableViewDataSource  {

    var delegate: ModelViewCellDelegate! { get set }
    
    // MARK: - Required UIView API
    func viewDidAppear(_ animated: Bool)
    
    func numberOfSections(in tableView: UITableView) -> Int
    
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String?
            
    // MARK: - API
    
    /// Initializes reading of all fields in the Model View. This should
    /// send the first request, after which the cell should wait for a response,
    /// call another request, wait, etc.
    ///
    /// - returns: `True`, if any request has been made, `false` if the cell does not
    ///            provide any refreshing mechanism.
    func startRefreshing() -> Bool
    
    /// A callback called whenever a Mesh Message has been received
    /// from the mesh network.
    ///
    /// - parameters:
    ///   - manager:     The manager which has received the message.
    ///   - message:     The received message.
    ///   - source:      The Unicast Address of the Element from which
    ///                  the message was sent.
    ///   - destination: The address to which the message was sent.
    /// - returns: `True`, when another request has been made, `false` if
    ///            the request has complete.
    func meshNetworkManager(_ manager: MeshNetworkManager,
                            didReceiveMessage message: MeshMessage,
                            sentFrom source: Address, to destination: Address) -> Bool
    
    /// A callback called when an unsegmented message was sent to the
    /// `transmitter`, or when all segments of a segmented message targeting
    /// a Unicast Address were acknowledged by the target Node.
    ///
    /// - parameters:
    ///   - manager:      The manager used to send the message.
    ///   - message:      The message that has been sent.
    ///   - localElement: The local Element used as a source of this message.
    ///   - destination:  The address to which the message was sent.
    /// - returns: `True`, when another request has been made or an Acknowledgement
    ///            is expected, `false` if the request has complete.
    func meshNetworkManager(_ manager: MeshNetworkManager,
                            didSendMessage message: MeshMessage,
                            from localElement: Element, to destination: Address) -> Bool
    
    
    func meshNetworkManager(_ manager: MeshNetworkManager,
                            failedToSendMessage message: MeshMessage,
                            from localElement: Element, to destination: Address,
                            error: Error)

}

// MARK: - Reversed API Implemention

extension ModelViewSectionProtocol {
    
    func viewDidAppear(_ animated: Bool) {
        /// Reversed
    }
    
    func meshNetworkManager(_ manager: MeshNetworkManager, didSendMessage message: MeshMessage, from localElement: Element, to destination: Address) -> Bool {
        /// Reversed
        return false
    }
    
    func meshNetworkManager(_ manager: MeshNetworkManager,
                            failedToSendMessage message: MeshMessage,
                            from localElement: Element, to destination: Address,
                            error: Error) {
        /// Reversed
    }
    
}



