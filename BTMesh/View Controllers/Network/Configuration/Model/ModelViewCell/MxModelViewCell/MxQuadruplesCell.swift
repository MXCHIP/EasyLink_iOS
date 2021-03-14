//
//  MxModelViewCell.swift
//  MICO
//
//  Created by William Xu on 2020/6/4.
//  Copyright © 2020 MXCHIP Co;Ltd. All rights reserved.
//


import UIKit
import nRFMeshProvision


class MxQuadruplesCell: ModelViewCell, UITextFieldDelegate {
    
    @IBOutlet weak var productIdField: UITextField!
    @IBOutlet weak var productKeyField: UITextField!
    @IBOutlet weak var productSecretField: UITextField!
    @IBOutlet weak var deviceNameField: UITextField!
    @IBOutlet weak var deviceSecretField: UITextField!
    
    var quintuples: MxAttribute.Quintuples! {
        didSet {
            productKeyField.text = quintuples.pk
            productSecretField.text = quintuples.ps
            deviceNameField.text = quintuples.dn
            deviceSecretField.text = quintuples.ds
            productIdField.text = quintuples.pid
        }
    }

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
        if case let status as MxAttributesStatus = message {
            status.attributes.forEach {
                if case let quintuples as MxAttribute.Quintuples = $0 {
                    productKeyField.text = quintuples.pk
                    productSecretField.text = quintuples.ps
                    deviceNameField.text = quintuples.dn
                    deviceSecretField.text = quintuples.ds
                    productIdField.text = quintuples.pid
                }
            }
        }
        return false
    }
    

    override func meshNetworkManager(_ manager: MeshNetworkManager,
                                     didSendMessage message: MeshMessage,
                                     from localElement: Element, to destination: Address) -> Bool {
        // For acknowledged messages wait for the Acknowledgement Message.
        switch message {
        case _ as MxAttributesSet: fallthrough
        case _ as MxAttributesGet:
            return true
            
        default:
            return false
        }
    }
}


private extension MxQuadruplesCell {
    
    /// Sends the MXCHIP Message with the opcode and parameters given
    /// by the user.
    func sendQuadruplesState() {
        let quintuples = MxAttribute.Quintuples(productKeyField.text!, productSecretField.text!, deviceNameField.text!, deviceSecretField.text!, productIdField.text!)
        let message = MxAttributesSet(tid: 0, attributes: [quintuples])
            
        delegate?.send(message, description: "Sending...")
    }
    
    func readQuadruplesState() {
        productIdField.text = nil
        productKeyField.text = nil
        productSecretField.text = nil
        deviceNameField.text = nil
        deviceSecretField.text = nil
        
        delegate?.send(MxAttributesGet(tid: 0, types: [.quintuplesType]), description: "Reading quadruples state...")
    }
}
