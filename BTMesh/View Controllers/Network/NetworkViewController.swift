/*
* Copyright (c) 2019, Nordic Semiconductor
* All rights reserved.
*
* Redistribution and use in source and binary forms, with or without modification,
* are permitted provided that the following conditions are met:
*
* 1. Redistributions of source code must retain the above copyright notice, this
*    list of conditions and the following disclaimer.
*
* 2. Redistributions in binary form must reproduce the above copyright notice, this
*    list of conditions and the following disclaimer in the documentation and/or
*    other materials provided with the distribution.
*
* 3. Neither the name of the copyright holder nor the names of its contributors may
*    be used to endorse or promote products derived from this software without
*    specific prior written permission.
*
* THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
* ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
* WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED.
* IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT,
* INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT
* NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR
* PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY,
* WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
* ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
* POSSIBILITY OF SUCH DAMAGE.
*/

import UIKit
import nRFMeshProvision

private enum SectionType {
    case notConfiguredNodes
    case configuredNodes
    case provisionersNodes
    case thisProvisioner
    
    var title: String? {
        switch self {
        case .notConfiguredNodes: return nil
        case .configuredNodes:    return "Configured Nodes"
        case .provisionersNodes:  return "Other Provisioners"
        case .thisProvisioner:    return "This Provisioner"
        }
    }
}

private class Section {
    let type: SectionType
    var cellInfos: [Any] = []
    var extractedNodes: [Node] = []
    
    init(type: SectionType, nodes: [Node]) {
        self.type = type
        
        for node in nodes {
            cellInfos.append(node)
        }
    }
    
    var title: String? {
        return type.title
    }
    
    func addExtractedNode(_ node: Node) {
        guard !isExtracted(node) else {
            return
        }
        extractedNodes.append(node)
    }
    
    func isExtracted(_ node: Node) -> Bool {
        if let _ = extractedNodes.firstIndex(of: node) {
            return true
        }
        return false
    }
        
    func removeExtractedNode(_ node: Node) {
        extractedNodes.removeAll(where: { $0 == node })
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        if cellInfos[indexPath.row] is Node {
            let cell = tableView.dequeueReusableCell(withIdentifier: "node", for: indexPath) as! NodeViewCell
            cell.node = cellInfos[indexPath.row] as? Node
            return cell
        } else {
            let cell = tableView.dequeueReusableCell(withIdentifier: "model", for: indexPath)
            let model = cellInfos[indexPath.row] as! Model
            
            if model.isBluetoothSIGAssigned {
                cell.textLabel?.text = model.name ?? "Unknown Model ID: \(model.modelIdentifier.asString())"
                cell.detailTextLabel?.text = "Bluetooth SIG"
            } else {
                cell.textLabel?.text = "Vendor Model ID: \(model.modelIdentifier.asString())"
                if let companyId = model.companyIdentifier {
                    if let companyName = CompanyIdentifier.name(for: companyId) {
                        cell.detailTextLabel?.text = companyName
                    } else {
                        cell.detailTextLabel?.text = "Unknown Company ID (\(companyId.asString()))"
                    }
                } else {
                    cell.detailTextLabel?.text = "Unknown Company ID"
                }
            }
            let address = model.parentElement!.unicastAddress
            cell.detailTextLabel?.text?.append(" | address: \(UInt16(address).asString())")
            return cell
        }
        
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) -> Model? {
        //let cell = tableView.dequeueReusableCell(withIdentifier: "node", for: indexPath) as! NodeViewCell

        if let model = cellInfos[indexPath.row] as? Model {
            return model
           }
           
        guard let node = cellInfos[indexPath.row] as? Node else {
            return nil
        }
        
        if isExtracted(node) {
            var indexPaths: [IndexPath] = []
            for index in 1...(indexPath.row + node.models.count) {
                indexPaths.append(IndexPath(item: indexPath.row + index, section: indexPath.section))
            }
            removeExtractedNode(node)
            cellInfos.removeSubrange( (indexPath.row + 1)...(indexPath.row + node.models.count) )
            tableView.deleteRows(at: indexPaths, with: .top)
        } else {
            let modles = node.models
            var indexPaths: [IndexPath] = []
            for index in 1...(indexPath.row + node.models.count) {
                indexPaths.append(IndexPath(item: indexPath.row + index, section: indexPath.section))
            }
            addExtractedNode(node)
            cellInfos.insert(contentsOf: modles, at: indexPath.row + 1)
            tableView.insertRows(at: indexPaths, with: .top)
        }
        return nil
    }
}

class NetworkViewController: UITableViewController {
    private var sections: [Section] = []
    
    // MARK: - Implementation
    
    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.setEmptyView(title: "No Nodes", message: "Click + to provision a new device.", messageImage: #imageLiteral(resourceName: "baseline-network"))
        reloadData()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        tableView.reloadData()
        
        MeshNetworkManager.instance.delegate = self
    }
    
    override func shouldPerformSegue(withIdentifier identifier: String, sender: Any?) -> Bool {
        if identifier == "provision" {
            let network = MeshNetworkManager.instance.meshNetwork
            let hasProvisioner = network?.localProvisioner != nil
            // If the Provisioner has not been set before,
            // display the error message.
            // When the OK button is clicked the Add Provisioner popup will present.
            // When done, the Provisioning will resume.
            if !hasProvisioner {
                presentAlert(title: "Provisioner not set", message: "Create a Provisioner before provisioning a new device.") { _ in
                    let storyboard = UIStoryboard(name: "Settings", bundle: .main)
                    let popup = storyboard.instantiateViewController(withIdentifier: "newProvisioner")
                    if let popup = popup as? UINavigationController,
                        let editProvisionerViewController = popup.topViewController as? EditProvisionerViewController {
                        editProvisionerViewController.delegate = self
                    }
                    self.present(popup, animated: true)
                }
            }
            return hasProvisioner
        }
        return true
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        switch segue.identifier! {
        case "provision":
            let destination = segue.destination as! UINavigationController
            let scannerViewController = destination.topViewController! as! ScannerTableViewController
            scannerViewController.delegate = self
        case "configure":
            let destination = segue.destination as! ConfigurationViewController
            destination.node = sender as? Node
        case "open":
            let cell = sender as! NodeViewCell
            let destination = segue.destination as! ConfigurationViewController
            destination.node = cell.node
        case  "showModelFromNetwork":
            let model = sender as! Model
            let destination = segue.destination as! ModelViewController
            destination.model = model
        default:
            break
        }
    }

    // MARK: - Table view data source

    override func numberOfSections(in tableView: UITableView) -> Int {
        return sections.count
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return sections[section].cellInfos.count
    }
    
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return sections[section].title
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        return sections[indexPath.section].tableView(tableView, cellForRowAt: indexPath)
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if let model = sections[indexPath.section].tableView(tableView, didSelectRowAt: indexPath) {
            performSegue(withIdentifier: "showModelFromNetwork", sender: model)
        }
        tableView.deselectRow(at: indexPath, animated: true)
    }
}

private extension NetworkViewController {
    
    func reloadData() {
        sections.removeAll()
        if let network = MeshNetworkManager.instance.meshNetwork {
            let notConfiguredNodes = network.nodes.filter({ !$0.isConfigComplete && !$0.isProvisioner })
            let configuredNodes    = network.nodes.filter({ $0.isConfigComplete && !$0.isProvisioner })
            let provisionersNodes  = network.nodes.filter({ $0.isProvisioner && !$0.isLocalProvisioner })
            
            if !notConfiguredNodes.isEmpty {
                sections.append(Section(type: .notConfiguredNodes, nodes: notConfiguredNodes ))
            }
            if !configuredNodes.isEmpty {
                sections.append(Section(type: .configuredNodes, nodes: configuredNodes))
            }
            if !provisionersNodes.isEmpty {
                sections.append(Section(type: .provisionersNodes, nodes: provisionersNodes))
            }
            if let thisProvisionerNode = network.localProvisioner?.node {
                sections.append(Section(type: .thisProvisioner, nodes: [thisProvisionerNode]))
            }
        }
        tableView.reloadData()
        
        if sections.isEmpty {
            tableView.showEmptyView()
        } else {
            tableView.hideEmptyView()
        }
    }
    
}

private extension Model {
    var isConfigurationServer: Bool {
        return isBluetoothSIGAssigned && modelIdentifier == 0x0000
    }

    var isConfigurationClient: Bool {
        return isBluetoothSIGAssigned && modelIdentifier == 0x0001
    }
    
    var isHealthServer: Bool {
        return isBluetoothSIGAssigned && modelIdentifier == 0x0002
    }

    var isHealthClient: Bool {
        return isBluetoothSIGAssigned && modelIdentifier == 0x0003
    }
}

private extension Node {
    
    var models: [Model] {
        var models: [Model] = []

        for element in elements {
            models.append(contentsOf: element.models.filter{
                !$0.isConfigurationServer && !$0.isConfigurationClient && !$0.isHealthServer && !$0.isHealthClient && !($0.name ?? "").contains("Client") }
            )
        }
        return models
    }
}

extension NetworkViewController: ProvisioningViewDelegate {
    
    func provisionerDidProvisionNewDevice(_ node: Node) {
        performSegue(withIdentifier: "configure", sender: node)
    }
    
}

extension NetworkViewController: EditProvisionerDelegate {
    
    func provisionerWasAdded(_ provisioner: Provisioner) {
        // A new Provisioner was added. Continue wit provisioning.
        performSegue(withIdentifier: "provision", sender: nil)
    }
    
    func provisionerWasModified(_ provisioner: Provisioner) {
        // Not used.
    }
    
}

extension NetworkViewController: MeshNetworkDelegate {
    
    func meshNetworkManager(_ manager: MeshNetworkManager,
                            didReceiveMessage message: MeshMessage,
                            sentFrom source: Address, to destination: Address) {
        switch message {
            
        case is ConfigNodeReset:
            // The node has been reset remotely.
            (UIApplication.shared.delegate as! AppDelegate).meshNetworkDidChange()
            reloadData()
            presentAlert(title: "Reset", message: "The mesh network was reset remotely.")
            
        default:
            break
        }
    }
    
}
