//
//  MxBoolAttributeCell.swift
//  MICO
//
//  Created by William Xu on 2020/11/10.
//  Copyright © 2020 MXCHIP Co;Ltd. All rights reserved.
//

import Foundation

class MxRangeAttrubuteCell: UITableViewCell {
    
    var delegate: ModelViewCellDelegate?
    
    @IBOutlet weak var title: UILabel!
    @IBOutlet weak var minLable: UILabel!
    @IBOutlet weak var currentLable: UILabel!
    @IBOutlet weak var maxLable: UILabel!
    @IBOutlet weak var slider: UISlider!
    
    var attribute: MxRange! {
        didSet {
            self.title.text = attribute.name
            self.minLable.text = "\(attribute.min)"
            self.maxLable.text = "\(attribute.max)"
            self.currentLable.text = "\(attribute.value)"
            slider.minimumValue = Float(attribute.min)
            slider.maximumValue = Float(attribute.max)
            slider.value = Float(attribute.value)
            slider.isEnabled = attribute.rw
        }
    }
    
    @IBAction func valueDidChange() {
        let current = Int(slider.value)
        currentLable.text = "\(current)"
    }
    
    @IBAction func switchTapped() {
        if let current = Int(currentLable.text!),
           attribute.value != current {
            attribute.value = current
            let message = MxAttributesSet(tid: 0, attributes: [attribute])
            delegate?.send(message, description: "Sending...")
        }
    }
    
}
