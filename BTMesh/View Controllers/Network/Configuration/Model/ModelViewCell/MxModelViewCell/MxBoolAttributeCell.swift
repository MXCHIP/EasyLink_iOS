//
//  MxBoolAttributeCell.swift
//  MICO
//
//  Created by William Xu on 2020/11/10.
//  Copyright © 2020 MXCHIP Co;Ltd. All rights reserved.
//

import Foundation

class MxBoolAttrubuteCell: UITableViewCell {
    
    var delegate: ModelViewCellDelegate?
    
    @IBOutlet weak var switcher: UISwitch!
    
    var attribute: MxBoolValue! {
        didSet {
            switcher.isOn = attribute.value
            self.textLabel?.text = attribute.name
            switcher.isEnabled = attribute.rw
        }
    }
    
    @IBAction func switchTapped() {
        // Re-use the existed attribute
        attribute.value = switcher.isOn
        let message = MxAttributesSet(tid: 0, attributes: [attribute])
        delegate?.send(message, description: "Sending...")
        
        
//        Create a new attribute to send,
//        if let attributeType = MxAttributeType.attribute[typeValue] as? MxBoolValue.Type {
//            var att = attributeType.init()
//            att.value = switcher.isOn
//
//            let message = MxAttributesSet(tid: 0, attributes: [att])
//            delegate?.send(message, description: "Sending...")
//
//        }
        
    }
    
}
