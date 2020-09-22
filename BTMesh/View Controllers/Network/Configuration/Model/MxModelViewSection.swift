//
//  MxModelViewSection.swift
//  MICO
//
//  Created by William Xu on 2020/8/4.
//  Copyright © 2020 MXCHIP Co;Ltd. All rights reserved.
//

import Foundation
import nRFMeshProvision

class MxModelViewSection: NSObject, ModelViewSectionProtocol {

    // MARK: - Properties
    var attributes: [MxAttribute] = []
    private weak var quadruplesCell: ModelViewCell?
    
    var model: Model!
    var tableView: UITableView!
    var delegate: ModelViewCellDelegate!

    // MARK: - Initializing
    init(model: Model, delegate: ModelViewCellDelegate, under tableView: UITableView) {
        self.model = model
        self.tableView = tableView
        self.delegate = delegate
        
        for section in 0..<IndexPath.numberOfSections {
            if let nibName = IndexPath.nibNames[section] {
                tableView.register(UINib(nibName: nibName, bundle: nil), forCellReuseIdentifier: IndexPath.identifiers[section])
            }
        }
    }
    
    // MARK: - UIView

    func viewDidAppear(_ animated: Bool) {
        _ = startRefreshing()
    }
    
    // MARK: - UITableViewDataSource

    func numberOfSections(in tableView: UITableView) -> Int {
        return IndexPath.numberOfSections
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        var numberOfRows: Int = 0
        if IndexPath.isATTSection(section) {
            numberOfRows = attributes.count
        }
        
        if IndexPath.isQuadruplesSection(section) {
            numberOfRows = 1
        }
        
        return numberOfRows
    }
        
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return IndexPath.titles[section]
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: indexPath.cellIdentifier, for: indexPath)
        
        if indexPath.isATTSection {
            cell.textLabel?.text = attributes[indexPath.row].type.hex
            cell.textLabel?.text = MxAttributeType(rawValue: attributes[indexPath.row].type)?.name
            cell.detailTextLabel?.text = "\(attributes[indexPath.row])"
        }
        
        if indexPath.isQuadruplesSection, let cell = cell as? ModelViewCell {
            cell.delegate  = delegate
            cell.model     = model
            quadruplesCell = cell
        }
  
        return cell
    }
    
    // MARK: - ModelViewSectionProtocol
    
    func startRefreshing() -> Bool {
        sendMxAttributesGetMessage(types: [])
        return false
    }
    

    func meshNetworkManager(_ manager: MeshNetworkManager,
                            didReceiveMessage message: MeshMessage,
                            sentFrom source: Address, to destination: Address) -> Bool {
        guard case let status as MxAttributesStatus = message else { return false }
        
        if case .quintuples = status.attributes[0] {
            return quadruplesCell?.meshNetworkManager(manager, didReceiveMessage: message,
                                                     sentFrom: source, to: destination) ?? false
        }
        self.attributes = status.attributes.sorted{ $0.type < $1.type }
        tableView.reloadSections(IndexSet([IndexPath.attSection]), with: .automatic)
        return false
        
    }
    

    func meshNetworkManager(_ manager: MeshNetworkManager, didSendMessage message: MeshMessage,
                            from localElement: Element, to destination: Address) -> Bool {
        guard case let status as MxAttributesStatus = message else { return false }
        
        if case .quintuples = status.attributes[0] {
            return quadruplesCell?.meshNetworkManager(manager, didSendMessage: message,
                                                      from: localElement, to: destination) ?? false
        }
        return false
    }
    
    
    func meshNetworkManager(_ manager: MeshNetworkManager, failedToSendMessage message: MeshMessage,
                            from localElement: Element, to destination: Address, error: Error) {
        
        guard case let status as MxAttributesStatus = message else { return }
        
        if case .quintuples = status.attributes[0] {
            quadruplesCell?.meshNetworkManager(manager, failedToSendMessage: message,
                                               from: localElement, to: destination, error: error)
        }
    }

}

private extension MxModelViewSection {
    
    func sendMxAttributesGetMessage(types: [MxAttributeType]) {
        let message = MxAttributesGet(tid: 0, types: types)
        delegate?.send(message, description: "Requesting all MXCHIP attributes...")
    }
    
}


private extension IndexPath {

    static let attSection = 0
    static let quadruplesSection = 1
    static let numberOfSections = 2
    
    static let identifiers = ["normal", "quadruple"]
    static let nibNames = [nil, "MxModel"]
    static let titles = ["MXCHIP Attributes", "飞燕五元组"]
    
    
    var cellIdentifier: String {
        return Self.identifiers[self.section]
    }
    
    var isATTSection: Bool {
        return section == IndexPath.attSection
    }
    
    static func isATTSection(_ section: Int) -> Bool {
        return section == IndexPath.attSection
    }
    
    var isQuadruplesSection: Bool {
        return section == IndexPath.quadruplesSection
    }
    
    static func isQuadruplesSection(_ section: Int) -> Bool {
        return section == IndexPath.quadruplesSection
    }
    
}

