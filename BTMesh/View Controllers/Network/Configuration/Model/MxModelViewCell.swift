//
//  MxModelViewCell.swift
//  MICO
//
//  Created by William Xu on 2020/6/4.
//  Copyright © 2020 MXCHIP Co;Ltd. All rights reserved.
//


import UIKit
import nRFMeshProvision

/*
struct RuntimeVendorMessage: VendorMessage {
    let opCode: UInt32
    let parameters: Data?
    
    var isSegmented: Bool = false
    var security: MeshMessageSecurity = .low
    
    init(opCode: UInt8, for model: Model, parameters: Data?) {
        self.opCode = (UInt32(0xC0 | opCode) << 16) | UInt32(model.companyIdentifier!.bigEndian)
        self.parameters = parameters
    }
    
    init?(parameters: Data) {
        // This init will never be used, as it's used for incoming messages.
        return nil
    }
}

extension RuntimeVendorMessage: CustomDebugStringConvertible {

    var debugDescription: String {
        let hexOpCode = String(format: "%2X", opCode)
        return "RuntimeVendorMessage(opCode: \(hexOpCode), parameters: \(parameters!.hex), isSegmented: \(isSegmented), security: \(security))"
    }
    
}
 */

class MxModelViewCell: ModelViewCell, UITextFieldDelegate {
    
    @IBOutlet weak var productIdField: UITextField!
    @IBOutlet weak var productKeyField: UITextField!
    @IBOutlet weak var productSecretField: UITextField!
    @IBOutlet weak var deviceNameField: UITextField!
    @IBOutlet weak var deviceSecretField: UITextField!

    @IBAction func editingDidChange(_ sender: UITextField) {
        if let _ = UInt32(productIdField.text ?? ""),
           let pk = productKeyField.text, pk.count > 0,
           let ps = productSecretField.text, ps.count > 0,
           let dn = deviceNameField.text, dn.count > 0,
           let ds = deviceSecretField.text, ds.count > 0 {
            sendQuadruplesButton.isEnabled = true
        } else {
            sendQuadruplesButton.isEnabled = false
        }
    }
    
    @IBOutlet weak var sendQuadruplesButton: UIButton!
    @IBAction func sendQuadruplesTapped(_ sender: UIButton) {
        sendQuadruplesState()
    }
    
    @IBOutlet weak var readQuadruplesButton: UIButton!
    @IBAction func readQuadruplesTapped(_ sender: UIButton) {
        readQuadruplesState()
    }
    
    // MARK: - Implementation

    override func awakeFromNib() {
        productIdField.delegate = self
        productKeyField.delegate = self
        productSecretField.delegate = self
        deviceNameField.delegate = self
        deviceSecretField.delegate = self
        
        sendQuadruplesButton.isEnabled = false
        
        let tap: UITapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
        self.contentView.addGestureRecognizer(tap)
    }

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }
    
    @objc func dismissKeyboard() {
        self.contentView.endEditing(true)
    }
    
    override func meshNetworkManager(_ manager: MeshNetworkManager,
                                     didReceiveMessage message: MeshMessage,
                                     sentFrom source: Address, to destination: Address) -> Bool {
        switch message {
        //case let status as MxQuadruplesStatus where status.isQuadruplesKnown:
        case let status as MxQuadruplesStatus:
            productIdField.text = status.productId
            productKeyField.text = status.productKey
            productSecretField.text = status.productSecret
            deviceNameField.text = status.deviceName
            deviceSecretField.text = status.deviceSecret
            
        default:
            break
        }
        return false
    }
    

    override func meshNetworkManager(_ manager: MeshNetworkManager,
                                     didSendMessage message: MeshMessage,
                                     from localElement: Element, to destination: Address) -> Bool {
        // For acknowledged messages wait for the Acknowledgement Message.
        switch message {
        case _ as MxQuadruplesSet: fallthrough
        case _ as MxQuadruplesGet:
            return true
            
        default:
            return false
        }
    }
}


private extension MxModelViewCell {
    
    /// Sends the MXCHIP Message with the opcode and parameters given
    /// by the user.
    func sendQuadruplesState() {
        guard !model.boundApplicationKeys.isEmpty else {
            parentViewController?.presentAlert(
                title: "Bound key required",
                message: "Bind at least one Application Key before sending the message.")
            return
        }
        
        let message = MxQuadruplesSet(pid: productIdField.text!, pk: productKeyField.text!, ps: productSecretField.text!, dn: deviceNameField.text!, ds: deviceSecretField.text!)
            
        delegate?.send(message, description: "Sending...")
    }
    
    func readQuadruplesState() {
        guard !model.boundApplicationKeys.isEmpty else {
            parentViewController?.presentAlert(
                title: "Bound key required",
                message: "Bind at least one Application Key before sending the message.")
            return
        }
        productIdField.text = nil
        productKeyField.text = nil
        productSecretField.text = nil
        deviceNameField.text = nil
        deviceSecretField.text = nil
        
        delegate?.send(MxQuadruplesGet(), description: "Reading quadruples state...")
    }
}
