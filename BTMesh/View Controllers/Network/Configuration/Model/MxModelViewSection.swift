//
//  MxModelViewSection.swift
//  MICO
//
//  Created by William Xu on 2020/8/4.
//  Copyright © 2020 MXCHIP Co;Ltd. All rights reserved.
//

import UIKit
import nRFMeshProvision

class MxModelViewSection: NSObject, ModelViewSectionProtocol {

    // MARK: - Properties
    var attributes: [MxGenericAttribute] = []
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
        
        attributes = MeshNetworkManager.statusManager.getMxAttributes(ofNode: (model.parentElement?.parentNode)!)
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
            numberOfRows = attributes.show.count
        }
        
        if IndexPath.isQuadruplesSection(section) {
            numberOfRows = 1
        }
        
        if IndexPath.isAdvanceSection(section) {
            numberOfRows = 1
        }
        
        return numberOfRows
    }
        
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return IndexPath.titles[section]
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        if indexPath.isATTSection {
            let attributes = self.attributes.show
            let cell = tableView.dequeueReusableCell(withIdentifier: attributes[indexPath.row].cellIdentifier, for: indexPath)
            
            switch attributes[indexPath.row] {
            case let attribute as MxRange:
                if let cell = cell as? MxRangeAttrubuteCell {
                    cell.attribute = attribute
                    cell.delegate = delegate
                }
            case let attribute as MxBoolValue:
                if let cell = cell as? MxBoolAttrubuteCell {
                    cell.attribute = attribute
                    cell.delegate = delegate
                }
            case let attribute as MxStringValue:
                cell.textLabel?.text = attribute.name
                cell.detailTextLabel?.text = attribute.value
            default:
                cell.textLabel?.text = "\(attributes[indexPath.row])"
            }
            
            return cell
        }
        
        let cell = tableView.dequeueReusableCell(withIdentifier: indexPath.cellIdentifier, for: indexPath)
        
        if indexPath.isAutoRow {
            cell.textLabel?.text = "本地自动化"
            cell.textLabel?.isEnabled = true
            return cell
        }
            
        if indexPath.isQuadruplesSection, let cell = cell as? MxQuadruplesCell {
            cell.delegate  = delegate
            cell.model     = model
            quadruplesCell = cell
            if let quintuples = attributes.first(where: {
                $0.typeValue == MxAttributeType.quintuplesType.rawValue
            }) as? MxAttribute.Quintuples {
                cell.quintuples = quintuples
            }
        }
  
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        if indexPath.isAutoRow {
            delegate.performSegue(withIdentifier: "auto", sender: indexPath)
        }
    }
    
    func tableView(_ tableView: UITableView, shouldHighlightRowAt indexPath: IndexPath) -> Bool {
        if indexPath.isAutoRow {
            return true
        }
        return false
    }
    
    func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        let navigationController = segue.destination as? UINavigationController
        
        switch segue.identifier {
        case .some("auto"):
            let viewController = navigationController?.topViewController as! MxAutomationViewController
            viewController.model = model
        default:
            break
        }
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
        
        if case _ as MxAttribute.Quintuples = status.attributes[0] {
            return quadruplesCell?.meshNetworkManager(manager, didReceiveMessage: message,
                                                     sentFrom: source, to: destination) ?? false
        }
        self.attributes.insert(status.attributes)
        tableView.reloadSections(IndexSet([IndexPath.attSection]), with: .automatic)
        return false
        
    }
    

    func meshNetworkManager(_ manager: MeshNetworkManager, didSendMessage message: MeshMessage,
                            from localElement: Element, to destination: Address) -> Bool {
        //guard case let status as MxAttributesSet = message else { return false }
        
//        if case _ as MxAttribute.Quintuples = status.attributes[0]  {
//            return quadruplesCell?.meshNetworkManager(manager, didSendMessage: message,
//                                                      from: localElement, to: destination) ?? false
//        }
        return true
    }
    
    
    func meshNetworkManager(_ manager: MeshNetworkManager, failedToSendMessage message: MeshMessage,
                            from localElement: Element, to destination: Address, error: Error) {
        
        quadruplesCell?.meshNetworkManager(manager, failedToSendMessage: message,
                                           from: localElement, to: destination, error: error)
        
//        guard case let status as MxAttributesStatus = message else { return }
//
//        if case _ as MxAttribute.Quintuples = status.attributes[0] {
//            quadruplesCell?.meshNetworkManager(manager, failedToSendMessage: message,
//                                               from: localElement, to: destination, error: error)
//        }
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
    static let advanceSection = 1
    static let quadruplesSection = 2
    static let numberOfSections = 3
    
    static let autoRow = 0
    
    static let identifiers = ["normal", "action", "quadruple"]
    static let nibNames = [nil, nil, "MxQuadruples"]
    static let titles = ["MXCHIP Attributes", "高级功能", "飞燕五元组" ]
    
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
    
    var isAdvanceSection: Bool {
        return section == IndexPath.advanceSection
    }
    
    var isAutoRow: Bool {
        return self.isAdvanceSection && row == IndexPath.autoRow
    }
    
    static func isAdvanceSection(_ section: Int) -> Bool {
        return section == IndexPath.advanceSection
    }
    
}
//self.typeValue is MxIntegerValue
private extension MxGenericAttribute {
    var cellIdentifier: String {
        switch self {
        case _ as MxBoolValue:
            return "bool attribute"
        case _ as MxRange:
            return "range attribute"
        default:
            return "normal"
        }
    }
}

private extension Array where Element == MxGenericAttribute {
    
    var show: [MxGenericAttribute] {
        return self.filter{
            $0.typeValue != MxAttributeType.quintuplesType.rawValue
        }
    }
    

}
