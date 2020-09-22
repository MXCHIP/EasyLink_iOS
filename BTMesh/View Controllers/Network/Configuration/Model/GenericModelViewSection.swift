//
//  GenericModelViewSection.swift
//  MICO
//
//  Created by William Xu on 2020/8/4.
//  Copyright © 2020 MXCHIP Co;Ltd. All rights reserved.
//

import Foundation
import nRFMeshProvision

class GenericModelViewSection: NSObject, ModelViewSectionProtocol {
    
    // MARK: - Properties
    
    private weak var modelViewCell: ModelViewCell?

    var model: Model!
    var tableView: UITableView!
    var delegate: ModelViewCellDelegate!
    
    
    // MARK: - Initializing
    
    init(model: Model, delegate: ModelViewCellDelegate, under tableView: UITableView) {
        self.model = model
        self.tableView = tableView
        self.delegate = delegate
        
        tableView.register(UINib(nibName: "ConfigurationServer", bundle: nil), forCellReuseIdentifier: "0000")
        tableView.register(UINib(nibName: "GenericOnOff", bundle: nil), forCellReuseIdentifier: "1000")
        tableView.register(UINib(nibName: "GenericLevel", bundle: nil), forCellReuseIdentifier: "1002")
        tableView.register(UINib(nibName: "VendorModel", bundle: nil), forCellReuseIdentifier: "vendor")
    }
    
    // MARK: - UITableViewDataSource
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return model.hasCustomUI ? 1:0
    }

    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return 1
    }
    
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        if model.isConfigurationServer {
            return "Relay Count & Interval"
        } else {
            return "Controls"
        }
    }

    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        var identifier: String = model.modelIdentifier.hex
        if let companyIdentifier = model.companyIdentifier {
            identifier = model.isMXCHIPAssigned ? "\(companyIdentifier.hex)\(model.modelIdentifier.hex)" : "vendor"
        }
        
        let cell = tableView.dequeueReusableCell(withIdentifier: identifier, for: indexPath) as! ModelViewCell
        cell.delegate = delegate
        cell.model    = model
        modelViewCell = cell
        return cell
    }
    
    
    // MARK: - ModelViewSectionProtocol
    
    func startRefreshing() -> Bool {
        return modelViewCell?.startRefreshing() ?? false
    }
    
    func meshNetworkManager(_ manager: MeshNetworkManager,
                            didReceiveMessage message: MeshMessage,
                            sentFrom source: Address, to destination: Address) -> Bool {
        return modelViewCell?.meshNetworkManager(manager, didReceiveMessage: message,
                                                 sentFrom: source, to: destination) ?? false
    }
    
    func meshNetworkManager(_ manager: MeshNetworkManager,
                            didSendMessage message: MeshMessage,
                            from localElement: Element, to destination: Address) -> Bool {
        return modelViewCell?.meshNetworkManager(manager, didSendMessage: message,
                                                 from: localElement, to: destination) ?? false
    }
    
    func meshNetworkManager(_ manager: MeshNetworkManager,
                            failedToSendMessage message: MeshMessage,
                            from localElement: Element, to destination: Address,
                            error: Error) {
        modelViewCell?.meshNetworkManager(manager, failedToSendMessage: message,
                                          from: localElement, to: destination,
                                          error: error)
    }

}


private extension Model {
    
    var isConfigurationServer: Bool {
        return isBluetoothSIGAssigned && modelIdentifier == 0x0000
    }
    
    var hasCustomUI: Bool {
        return (!isBluetoothSIGAssigned && !isMXCHIPAssigned)   // Vendor Models.
            || (isBluetoothSIGAssigned && modelIdentifier == 0x0000) // Generic Configuration Server
            || (isBluetoothSIGAssigned && modelIdentifier == 0x1000) // Generic On Off Server.
            || (isBluetoothSIGAssigned && modelIdentifier == 0x1002) // Generic Level Server.
            || (isMXCHIPAssigned && modelIdentifier == 0x0000) // MXCHIP Vender Server.
    }
    

}
