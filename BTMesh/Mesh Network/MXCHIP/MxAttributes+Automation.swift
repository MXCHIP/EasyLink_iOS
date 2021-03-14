//
//  MxAttribute.swift
//  MICO
//
//  Created by William Xu on 2020/7/22.
//  Copyright © 2020 MXCHIP Co;Ltd. All rights reserved.
//

import Foundation
import nRFMeshProvision


extension MxAttribute {

    struct Automation: MxStaticAttribute {

        static var type: MxAttributeType = .automationType
        
        var rules: [MxAutoRule]
        var length: Int
        
        init() {
            self.rules = []
            self.length = 0
        }
         
        init?(pdu: Data) {
            var rules: [MxAutoRule] = []
            var length = 0
            
            let valueData = Data(pdu.suffix(from: 2))
            var index = 0
            while index < valueData.count {
                guard let rule = MxAutoRule(pdu: Data(valueData.suffix(from: index))) else {
                    break
                }
                rules.append(rule)
                length += rule.length
                index += rule.length
            }
            
            self.rules = rules
            self.length = length
            
        }
        
        var pdu: Data? {
            return Data()
        }
    }
    
}


struct MxAutoRule {
    
    /// Action pdu = trigger(2) + length(1)+ logics(length),
    var trigger: UInt16
    var logics: [Logic]
    var length: Int
    
    init?(pdu: Data) {
                    
        guard pdu.count >= 3,
              let trigger: UInt16 = pdu.readBigEndian() else {
            return nil
        }
        let logicsLength = Int(pdu[2])

        self.trigger = trigger
        self.logics = []
        self.length = 2 + 1 + logicsLength

        let logicsPdu = Data(pdu.suffix(from: 3).prefix(logicsLength)) //actions(length)
        var index = 0
        while index < logicsPdu.count {
            guard let logic = Logic(pdu: Data(logicsPdu.suffix(from: index))) else {
                return nil
            }
            self.logics.append(logic)
            index += logic.length
        }
        
    }
}

extension MxAutoRule {
    struct Logic {

        /// Action pdu = typeValue(2) + length(1)+ actions(length),
        var type: MxAttributeType
        var actions: [Action]
        var length: Int
        
        init?(pdu: Data) {
                        
            guard pdu.count >= 3,
                  let type = MxAttributeType.init(pdu: pdu, endian: .bigEndian) else {
                return nil
            }
            let actionsLength = Int(pdu[2])

            self.type = type
            self.actions = []
            self.length = 2 + 1 + actionsLength

            let actionsPdu = Data(pdu.suffix(from: 3).prefix(actionsLength)) //actions(length)
            var index = 0
            while index < actionsPdu.count {
                guard let action = Action(type: type, pdu: Data(actionsPdu.suffix(from: index))) else {
                    return nil
                }
                self.actions.append(action)
                index += action.length
            }
            
        }
        
    }
}

extension MxAutoRule.Logic {
    
    /// Action pdu = value(?) + length(1)+ executes(length),
    struct Action {
        
        var attribute: MxGenericAttribute
        var executes: [Execute]
        var length: Int
        
        init?(type: MxAttributeType, pdu: Data) {
            
            let tmpPdu = type.pdu + pdu
            
            guard let attribute = MxAttribute.decode(pdu: tmpPdu),
                  pdu.count >= attribute.valueLength + 1 else {
                return nil
            }
            let executesLength = Int(pdu[attribute.valueLength])

            self.attribute = attribute
            self.executes = []
            self.length = attribute.valueLength + 1 + executesLength
            

            let executesPdu = Data(pdu.suffix(from: attribute.valueLength + 1).prefix(executesLength)) //executes(length)
            var index = 0
            while index < executesPdu.count {
                guard let execute = Execute(pdu: Data(executesPdu.suffix(from: index))) else {
                    return nil
                }
                self.executes.append(execute)
                index += execute.length
            }
            
        }
        
    }
    
}

extension MxAutoRule.Logic.Action {
    
    /// Execute pdu = executor(2) + typeValue(2) + length(1)+ value(length),
    struct Execute {
        
        var executor: UInt16
        var attribute: MxGenericAttribute
        var length: Int
        
        init?(pdu: Data) {
            
            guard pdu.count >= 5,
                  let executor: UInt16 = pdu.readBigEndian() else {
                return nil
            }
            
            self.length = 2 + 2 + 1 + Int(pdu[4])
            var attributePdu = pdu.subdata(in: 2..<self.length) //typeValue(2) + length(1)+ value(length)
            attributePdu.remove(at: 2) //typeValue(2) + value(length)
            
            guard let attribute = MxAttribute.decode(pdu: attributePdu, typeByteOrder: .bigEndian) else {
                return nil
            }
            
            self.executor = executor
            self.attribute = attribute
            
        }
        
    }
    
}


extension MxGenericAttribute {
    var valueLength: Int {
        return self.length - MxAttributeType.size
    }
}


extension MxAttribute {
    
    static func decode(pdu: Data, typeByteOrder: MxAttributeType.ByteOrder ) -> MxGenericAttribute?  {

        guard var type: UInt16 = pdu.read() else { return nil }
        
        var pdu = pdu
        if case .bigEndian = typeByteOrder {
            type = type.littleEndian
            pdu.replaceSubrange(0..<2, with: Data(from: type))
        }
        
        // 确认已知的属性能够按照格式解码成功
        if let attributeType = MxAttributeType.attribute[type] {
            return attributeType.init(pdu: pdu)
        } else {
            return MxAttribute.Unknown(type, pdu.subdata(in: 2..<pdu.count))
        }
    }
    
}
