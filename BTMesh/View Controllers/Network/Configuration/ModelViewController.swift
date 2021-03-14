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

class ModelViewController: ProgressViewController {

    // MARK: - Properties
    
    var model: Model!
    
    // Calculate acknowledged message loop time
    private var sendTimestamp: Date?
    private var responseOpCode: UInt32?
    
    private var customSection: ModelViewSectionProtocol!
    
    // MARK: - View Controller
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        title = model.name ?? "Model"
        if !model.isConfigurationServer && !model.isConfigurationClient {
            navigationItem.rightBarButtonItem = editButtonItem
        }
        
        if model.isMXCHIPAssigned {
            customSection = MxModelViewSection(model: model, delegate: self, under: self.tableView)
        } else {
            customSection = GenericModelViewSection(model: model, delegate: self, under: self.tableView)
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        // Check if the local Provisioner has configuration capabilities.
        let localProvisioner = MeshNetworkManager.instance.meshNetwork?.localProvisioner
        guard localProvisioner?.hasConfigurationCapabilities ?? false else {
            // The Provisioner cannot sent or receive messages.
            refreshControl = nil
            editButtonItem.isEnabled = false
            return
        }
        
        if !model.isConfigurationClient {
            refreshControl = UIRefreshControl()
            refreshControl!.tintColor = UIColor.white
            refreshControl!.addTarget(self, action: #selector(reload(_:)), for: .valueChanged)
        }
        editButtonItem.isEnabled = true
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        MeshNetworkManager.delegateCenter.messageDelegate = self
        customSection.viewDidAppear(animated)
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        let navigationController = segue.destination as? UINavigationController
        navigationController?.presentationController?.delegate = self
        
        switch segue.identifier {
        case .some("bind"):
            let viewController = navigationController?.topViewController as! ModelBindAppKeyViewController
            viewController.model = model
            viewController.delegate = self
        case .some("publish"):
            let viewController = navigationController?.topViewController as! SetPublicationViewController
            viewController.model = model
            viewController.delegate = self
        case .some("subscribe"):
            let viewController = navigationController?.topViewController as! SubscribeViewController
            viewController.model = model
            viewController.delegate = self
        default:
            customSection.prepare(for: segue, sender: sender)
            break
        }
    }
    
    // MARK: - Table View Controller
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        let numberOfStanadrdSections = (model.isConfigurationServer || model.isConfigurationClient) ? 1:4
        return numberOfStanadrdSections + customSection.numberOfSections(in: tableView)
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch section {
        case detailsSection:
            return ModelViewController.detailsTitles.count
        case bindingsSection:
            return model.boundApplicationKeys.count + 1 // Add Action.
        case publishSection:
            return 1 // Set Publication Action or the Publication.
        case subscribeSection:
            return model.subscriptions.count + 1 // Add Action.
        default:
            // If we went that far, there may be has custom sections for the Model.
            return customSection.tableView(self.tableView, numberOfRowsInSection: section)
        }
    }
    
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        switch section {
        case bindingsSection:
            return "Bound Application Keys"
        case publishSection:
            return "Publication"
        case subscribeSection:
            return "Subscriptions"
        case detailsSection:
            return "Company"
        default:
            return customSection.tableView(self.tableView, titleForHeaderInSection: section)
        }
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let localProvisioner = MeshNetworkManager.instance.meshNetwork?.localProvisioner
        
        if isDetailsSection(at: indexPath) {
            let cell = tableView.dequeueReusableCell(withIdentifier: "normal", for: indexPath)
            cell.textLabel?.text = detailSectionTitle(indexPath)
            if isModelIdRow(at: indexPath) {
                cell.detailTextLabel?.text = model.modelIdentifier.asString()
            }
            if isCompanyRow(at: indexPath) {
                if model.isBluetoothSIGAssigned {
                    cell.detailTextLabel?.text = "Bluetooth SIG"
                } else {
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
            }
            return cell
        }
        if isBindingsSection(at: indexPath) && !model.isConfigurationServer {
            guard indexPath.row < model.boundApplicationKeys.count else {
                let cell = tableView.dequeueReusableCell(withIdentifier: "action", for: indexPath)
                cell.textLabel?.text = "Bind Application Key"
                cell.textLabel?.isEnabled = localProvisioner?.hasConfigurationCapabilities ?? false
                return cell
            }
            let applicationKey = model.boundApplicationKeys[indexPath.row]
            
            let cell = tableView.dequeueReusableCell(withIdentifier: "key", for: indexPath)
            cell.textLabel?.text = applicationKey.name
            cell.detailTextLabel?.text = "Bound to \(applicationKey.boundNetworkKey.name)"
            return cell
        }
        if isPublishSection(at: indexPath) {
            guard let publish = model.publish else {
                let cell = tableView.dequeueReusableCell(withIdentifier: "action", for: indexPath)
                cell.textLabel?.text = "Set Publication"
                cell.textLabel?.isEnabled = localProvisioner?.hasConfigurationCapabilities ?? false
                return cell
            }
            let cell = tableView.dequeueReusableCell(withIdentifier: "destination", for: indexPath) as! PublicationCell
            cell.publish = publish
            return cell
        }
        if isSubscribeSection(at: indexPath) {
            guard indexPath.row < model.subscriptions.count else {
                let cell = tableView.dequeueReusableCell(withIdentifier: "action", for: indexPath)
                cell.textLabel?.text = "Subscribe"
                cell.textLabel?.isEnabled = localProvisioner?.hasConfigurationCapabilities ?? false
                return cell
            }
            let cell = tableView.dequeueReusableCell(withIdentifier: "group", for: indexPath)
            let group = model.subscriptions[indexPath.row]
            cell.textLabel?.text = group.name
            cell.detailTextLabel?.text = nil
            return cell
        }
        
        let cell = customSection.tableView(self.tableView, cellForRowAt: indexPath)
        return cell
    }
    
    override func tableView(_ tableView: UITableView, shouldHighlightRowAt indexPath: IndexPath) -> Bool {
        let localProvisioner = MeshNetworkManager.instance.meshNetwork?.localProvisioner
        guard localProvisioner?.hasConfigurationCapabilities ?? false else {
            return false
        }
        
        if isBindingsSection(at: indexPath) && !model.isConfigurationServer {
            return indexPath.row == model.boundApplicationKeys.count
        }
        if isPublishSection(at: indexPath) {
            return true
        }
        if isSubscribeSection(at: indexPath) {
            return indexPath.row == model.subscriptions.count
        }
        
        return customSection.tableView(self.tableView, shouldHighlightRowAt: indexPath)
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        
        if isBindingsSection(at: indexPath) {
            // Only the "Bind" row is selectable.
            performSegue(withIdentifier: "bind", sender: indexPath)
        }
        if isPublishSection(at: indexPath) {
            guard !model.boundApplicationKeys.isEmpty else {
                presentAlert(title: "Application Key required", message: "Bind at least one Application Key before setting the publication.")
                return
            }
            performSegue(withIdentifier: "publish", sender: indexPath)
        }
        if isSubscribeSection(at: indexPath) {
            // Only the "Subscribe" row is selectable.
            performSegue(withIdentifier: "subscribe", sender: indexPath)
        }
        
        customSection.tableView?(self.tableView, didSelectRowAt: indexPath)
    }
    
    override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        if isBindingsSection(at: indexPath) {
            return indexPath.row < model.boundApplicationKeys.count
        }
        if isPublishSection(at: indexPath) {
            return indexPath.row == 0 && model.publish != nil
        }
        if isSubscribeSection(at: indexPath) {
            return indexPath.row < model.subscriptions.count
        }
        return false
    }
    
    override func tableView(_ tableView: UITableView, editActionsForRowAt indexPath: IndexPath) -> [UITableViewRowAction]? {
        if isBindingsSection(at: indexPath) {
            return [UITableViewRowAction(style: .destructive, title: "Unbind", handler: { _, indexPath in
                guard indexPath.row < self.model.boundApplicationKeys.count else {
                        return
                }
                let applicationKey = self.model.boundApplicationKeys[indexPath.row]
                
                // Let's check if the key that's being unbound is set for publication.
                let boundKeyUsedInPublication = self.model.publish?.index == applicationKey.index
                // Check also, if any other Node is set to publish to this Model
                // (using parent Element's Unicast Address) using this key.
                let network = MeshNetworkManager.instance.meshNetwork!
                let thisElement = self.model.parentElement!
                let thisNode = thisElement.parentNode!
                let otherNodes = network.nodes.filter { $0 != thisNode }
                let elementsWithCompatibleModels = otherNodes.flatMap {
                    $0.elements.filter({ $0.contains(modelBoundTo: applicationKey)})
                }
                let compatibleModels = elementsWithCompatibleModels.flatMap {
                    $0.models.filter({ $0.isBoundTo(applicationKey) })
                }
                let boundKeyUsedByOtherNodes = compatibleModels.contains {
                    $0.publish?.publicationAddress.address == thisElement.unicastAddress &&
                    $0.publish?.index == applicationKey.index
                }
                
                if boundKeyUsedInPublication || boundKeyUsedByOtherNodes {
                    var message = "The key you want to unbind is set"
                    if boundKeyUsedInPublication {
                        message += " in the publication settings in this model"
                        if boundKeyUsedByOtherNodes {
                            message += " and"
                        }
                    }
                    if boundKeyUsedByOtherNodes {
                        message += " in at least one model on another node that publish directly to this element."
                    }
                    if boundKeyUsedInPublication {
                        if boundKeyUsedByOtherNodes {
                            message += " The local publication will be cancelled automatically, but other nodes will not be affected. This model will no longer be able to handle those publications."
                        } else {
                            message += "\nThe publication will be cancelled automatically."
                        }
                    }
                    self.confirm(title: "Key in use", message: message, handler: { _ in
                        self.unbindApplicationKey(applicationKey)
                    })
                } else {
                    self.unbindApplicationKey(applicationKey)
                }
            })]
        }
        return nil
    }
    
    override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        if isPublishSection(at: indexPath) {
            removePublication()
        }
        if isSubscribeSection(at: indexPath) {
            let group = model.subscriptions[indexPath.row]
            unsubscribe(from: group)
        }
    }

}

extension ModelViewController: UIAdaptivePresentationControllerDelegate {
    
    func presentationControllerDidDismiss(_ presentationController: UIPresentationController) {
        MeshNetworkManager.delegateCenter.messageDelegate = self
    }
    
}

extension ModelViewController: ModelViewCellDelegate {

    func send(_ message: MeshMessage, description: String, delegate: ProgressViewDelegate?) {
        
        guard !model.boundApplicationKeys.isEmpty else {
            presentAlert(
                title: "Bound key required",
                message: "Bind at least one Application Key before sending the message.")
            delegate?.alertWillCancelled()
            return
        }
        
        start(description, delegate: delegate) {
            self.responseOpCode = nil
            if let acknowledgedMessage =  message as? AcknowledgedMeshMessage {
                self.responseOpCode = acknowledgedMessage.responseOpCode
                self.sendTimestamp = Date()
            }
           
            return try MeshNetworkManager.instance.send(message, to: self.model)
        }
    }
    
    func send(_ message: ConfigMessage, description: String) {
        start(description) {
            return try MeshNetworkManager.instance.send(message, to: self.model)
        }
    }
    
    var isRefreshing: Bool {
        return refreshControl?.isRefreshing ?? false
    }
    
}

private extension ModelViewController {
    
    @objc func reload(_ sender: Any) {
        if !model.isConfigurationServer {
            reloadBindings()
        } else {
            _ = customSection.startRefreshing()
        }
    }
    
    func reloadBindings() {
        let message: ConfigMessage =
            ConfigSIGModelAppGet(of: model) ??
            ConfigVendorModelAppGet(of: model)!
        send(message, description: "Reading Bound Application Keys...")
    }
    
    func reloadPublication() {
        guard let message = ConfigModelPublicationGet(for: model) else {
            return
        }
        send(message, description: "Reading Publication settings...")
    }
    
    func reloadSubscriptions() {
        let message: ConfigMessage =
            ConfigSIGModelSubscriptionGet(of: model) ??
            ConfigVendorModelSubscriptionGet(of: model)!
        send(message, description: "Reading Subscriptions...")
    }
    
    /// Sends a message to the mesh network to unbind the given Application Key
    /// from the Model.
    ///
    /// - parameter applicationKey: The Application Key to unbind.
    func unbindApplicationKey(_ applicationKey: ApplicationKey) {
        guard let message = ConfigModelAppUnbind(applicationKey: applicationKey, to: model) else {
            return
        }
        send(message, description: "Unbinding Application Key...")
    }
    
    /// Removes the publicaton from the model.
    func removePublication() {
        guard let message = ConfigModelPublicationSet(disablePublicationFor: model) else {
            return
        }
        send(message, description: "Removing Publication...")
    }
    
    /// Unsubscribes the Model from publications sent to the given Group.
    ///
    /// - parameter group: The Group to be removed from subscriptions.
    func unsubscribe(from group: Group) {
        let message: ConfigMessage =
            ConfigModelSubscriptionDelete(group: group, from: self.model) ??
            ConfigModelSubscriptionVirtualAddressDelete(group: group, from: self.model)!
        send(message, description: "Unsubscribing...")
    }
    
}

extension ModelViewController: MeshNetworkDelegate {
    
    func meshNetworkManager(_ manager: MeshNetworkManager,
                            didReceiveMessage message: MeshMessage,
                            sentFrom source: Address, to destination: Address) {
        // Has the Node been reset remotely.
        guard !(message is ConfigNodeReset) else {
            (UIApplication.shared.delegate as! AppDelegate).meshNetworkDidChange()
            done() {
                self.navigationController?.popToRootViewController(animated: true)
            }
            return
        }
        // Is the message targeting the current Node or Model?
        guard model.parentElement?.unicastAddress == source ||
             (model.parentElement?.parentNode!.unicastAddress == source
                && message is ConfigMessage) else {
            return
        }
        
        // Handle the message based on its type.
        switch message {
            
        case let status as ConfigModelAppStatus:
            done()
            
            if status.isSuccess {
                tableView.reloadSections(bindingsAndPublication, with: .automatic)
                setEditing(false, animated: true)
            } else {
                presentAlert(title: "Error", message: status.message)
            }
            
        case let status as ConfigModelPublicationStatus:
            // If the Model is being refreshed, the Bindings, Subscriptions
            // and Publication has been read. If the Model has custom UI,
            // try refreshing it as well.
            
        
            if status.isSuccess {
                tableView.reloadSections(publication, with: .automatic)
                setEditing(false, animated: true)
                _ = customSection.startRefreshing()
            } else {
                presentAlert(title: "Error", message: status.message)
                done(){
                    self.refreshControl?.endRefreshing()
                    self.tableView.contentOffset = CGPoint(x: 0, y: -self.refreshControl!.frame.size.height)
                }
            }
            
        case let status as ConfigModelSubscriptionStatus:
            done()
            
            if status.isSuccess {
                tableView.reloadSections(subscriptions, with: .automatic)
                setEditing(false, animated: true)
            } else {
                presentAlert(title: "Error", message: status.message)
            }
            
        case let list as ConfigModelAppList:
            if list.isSuccess {
                tableView.reloadSections(bindingsAndPublication, with: .automatic)
                reloadSubscriptions()
            } else {
                done() {
                    self.presentAlert(title: "Error", message: list.message)
                    self.refreshControl?.endRefreshing()
                    self.tableView.contentOffset = CGPoint(x: 0, y: -self.refreshControl!.frame.size.height)
                }
            }
            
        case let list as ConfigModelSubscriptionList:
            if list.isSuccess {
                tableView.reloadSections(subscriptions, with: .automatic)
                reloadPublication()
            } else {
                done() {
                    self.presentAlert(title: "Error", message: list.message)
                    self.refreshControl?.endRefreshing()
                    self.tableView.contentOffset = CGPoint(x: 0, y: -self.refreshControl!.frame.size.height)
                }
            }
            
        default:
              let isMore = customSection.meshNetworkManager(manager, didReceiveMessage: message,
                                                            sentFrom: source, to: destination)
            if !isMore {
                done()
                
                if let status = message as? StatusMessage, !status.isSuccess {
                    presentAlert(title: "Error", message: status.message)
                }
                if isRefreshing {
                    refreshControl!.endRefreshing()
                    tableView.contentOffset = CGPoint(x: 0, y: -refreshControl!.frame.size.height)
                }
            }
        }
    }
    
    func meshNetworkManager(_ manager: MeshNetworkManager,
                            didSendMessage message: MeshMessage,
                            from localElement: Element, to destination: Address) {
        // Has the Node been reset remotely.
        guard !(message is ConfigNodeReset) else {
            (UIApplication.shared.delegate as! AppDelegate).meshNetworkDidChange()
            navigationController?.popToRootViewController(animated: true)
            return
        }
        
        switch message {
        case is ConfigMessage:
            // Ignore.
            break
            
        default:
            let isMore = customSection.meshNetworkManager(manager, didSendMessage: message,
                                                          from: localElement, to: destination)
            if !isMore {
                done()
            }
        }
    }
    
    func meshNetworkManager(_ manager: MeshNetworkManager,
                            failedToSendMessage message: MeshMessage,
                            from localElement: Element, to destination: Address,
                            error: Error) {
        customSection.meshNetworkManager(manager, failedToSendMessage: message,
                                         from: localElement, to: destination, error: error)
        
        done() {
            self.presentAlert(title: "Error", message: error.localizedDescription)
            self.refreshControl?.endRefreshing()
            self.tableView.contentOffset = CGPoint(x: 0, y: -self.refreshControl!.frame.size.height)
        }
    }
    
}

extension ModelViewController: BindAppKeyDelegate, PublicationDelegate, SubscriptionDelegate {
    
    func keyBound() {
        tableView.reloadSections(bindings, with: .automatic)
    }
    
    func publicationChanged() {
        tableView.reloadSections(publication, with: .automatic)
    }
    
    func subscriptionAdded() {
        tableView.reloadSections(subscriptions, with: .automatic)
    }
    
}

private extension Model {
    
    var isConfigurationServer: Bool {
        return isBluetoothSIGAssigned && modelIdentifier == 0x0000
    }
    
    var isConfigurationClient: Bool {
        return isBluetoothSIGAssigned && modelIdentifier == 0x0001
    }
    
}

// MARK: - Sections helper

private extension ModelViewController {
    
    var customUISection: Int { return 0 }
    var detailsSection: Int { return customSection.numberOfSections(in: tableView) }
    var bindingsSection: Int { return detailsSection + 1 }
    var publishSection: Int { return detailsSection + 2 }
    var subscribeSection: Int { return detailsSection + 3 }
    
    static let detailsTitles = [ "Model ID", "Company" ]
    
    func detailSectionTitle(_ indexPath: IndexPath) -> String? {
        if isDetailsSection(at: indexPath) {
            return Self.detailsTitles[indexPath.row]
        }
        return nil
    }

    func isModelIdRow(at indexPath: IndexPath) -> Bool {
        return isDetailsSection(at: indexPath) && indexPath.row == 0
    }
    
    func isCompanyRow(at indexPath: IndexPath) -> Bool {
        return isDetailsSection(at: indexPath) && indexPath.row == 1
    }
    
    func isDetailsSection(at indexPath: IndexPath) -> Bool {
        return indexPath.section == self.detailsSection
    }
    
    func isBindingsSection(at indexPath: IndexPath) -> Bool {
        return indexPath.section == self.bindingsSection
    }
    
    func isPublishSection(at indexPath: IndexPath) -> Bool {
        return indexPath.section == self.publishSection
    }
    
    func isSubscribeSection(at indexPath: IndexPath) -> Bool {
        return indexPath.section == self.subscribeSection
    }
    
    var customs: IndexSet { return IndexSet(Array(0..<customSection.numberOfSections(in: tableView))) }
    var bindings: IndexSet { return IndexSet(integer: bindingsSection) }
    var publication: IndexSet { return IndexSet(integer: publishSection) }
    var subscriptions: IndexSet { return IndexSet(integer: subscribeSection) }
    var bindingsAndPublication: IndexSet { return IndexSet([bindingsSection, publishSection]) }

}

