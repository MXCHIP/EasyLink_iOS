//
//  MxAutomationViewController.swift
//  MICO
//
//  Created by William Xu on 2020/11/25.
//  Copyright © 2020 MXCHIP Co;Ltd. All rights reserved.
//

import UIKit
import nRFMeshProvision

class MxAutomationViewController: ProgressViewController {
    
    // MARK: - Properties
    
    var model: Model!
    var debugCell: UITableViewCell?
    
    // MARK: - View Controller
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        MeshNetworkManager.delegateCenter.messageDelegate = self
        
        let message = MxAttributesGet(tid: 0, types: [.automationType])
        send(message, description: "Requesting local automation rules...", delegate: nil)
    }
    
    
    // MARK: - Table View Controller
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return 1
    }
    
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return "Debug"
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        let cell = tableView.dequeueReusableCell(withIdentifier: "debug", for: indexPath)
        cell.textLabel?.text = "dfaha"
        cell.detailTextLabel?.text = "dfahadfahadfahadfahadfahadfahadfahadfahadfahadfahadfahadfahadfahadfahadfahadfahadfahadfahadfahadfahadfahadfahadfahadfahadfahadfahadfahadfahadfahadfahadfahadfahadfahadfahadfahadfahadfahadfahadfahadfahadfahadfahadfahadfahadfahadfahadfahadfahadfahadfahadfahadfahadfahadfahadfahadfahadfahadfahadfahadfahadfahadfahadfahadfahadfahadfahadfahadfahadfahadfahadfahadfahadfahadfahadfahadfahadfahadfahadfahadfahadfahadfahadfahadfahadfahadfahadfahadfahadfahadfahadfahadfahadfahadfahadfahadfahadfahadfahadfahadfahadfahadfahadfahadfahadfahadfahadfahadfahadfahadfahadfahadfahadfahadfahadfahadfahadfahadfahadfahadfahadfahadfahadfahadfahadfahadfahadfahadfahadfahadfahadfahadfahadfahadfahadfahadfahadfahadfahadfahadfahadfahadfahadfahadfahadfahadfahadfahadfahadfahadfahadfahadfahadfahadfahadfahadfahadfahadfahadfahadfahadfahadfahadfahadfahadfahadfahadfahadfahadfahadfahadfahadfahadfahadfahadfahadfahadfahadfahadfahadfahadfahadfahadfahadfahadfahadfahadfahadfahadfahadfahadfahadfahadfahadfahadfahadfahadfahadfahadfahadfahadfahadfahadfahadfahadfahadfahadfahadfahadfahadfahadfahadfahadfahadfahadfahadfahadfahadfahadfahadfahadfahadfahadfahadfahadfahadfahadfahadfahadfahadfahadfahadfahadfahadfahadfahadfahadfahadfahadfahadfahadfahadfahadfahadfaha"
        self.debugCell = cell
        return cell

    }
    
    // MARK: - Table view data source

    

    
}


extension MxAutomationViewController: MeshNetworkDelegate {
    
    func meshNetworkManager(_ manager: MeshNetworkManager,
                            didReceiveMessage message: MeshMessage,
                            sentFrom source: Address, to destination: Address) {
        
        guard case let status as MxAttributesStatus = message,
              case let automation as MxAttribute.Automation = status.attributes[0] else { return }
        
        debugCell?.detailTextLabel?.text = "\(automation)"
        done()
    }
}

private extension MxAutomationViewController {
    
    func send(_ message: MeshMessage, description: String, delegate: ProgressViewDelegate?) {
        
        guard !model.boundApplicationKeys.isEmpty else {
            presentAlert(
                title: "Bound key required",
                message: "Bind at least one Application Key before sending the message.")
            delegate?.alertWillCancelled()
            return
        }
        
        start(description, delegate: delegate) {
            return try MeshNetworkManager.instance.send(message, to: self.model)
        }
    }
    
}




