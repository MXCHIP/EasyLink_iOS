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

class GenericOnOffViewCell: ModelViewCell {
    
    // MARK: - Outlets and Actinos

    @IBOutlet weak var defaultTransitionSettingsSwitch: UISwitch!
    @IBAction func defaultTransitionSettingsDidChange(_ sender: UISwitch) {
        transitionTimeSlider.isEnabled = !sender.isOn
        delaySlider.isEnabled = !sender.isOn
        
        if sender.isOn {
            transitionTimeLabel.text = "Default"
            delayLabel.text = "No delay"
        } else {
            transitionTimeSelected(transitionTimeSlider.value)
            delaySelected(delaySlider.value)
        }
    }
    
    @IBOutlet weak var transitionTimeSlider: UISlider!
    @IBOutlet weak var delaySlider: UISlider!
    
    @IBOutlet weak var transitionTimeLabel: UILabel!
    @IBOutlet weak var delayLabel: UILabel!
    @IBOutlet weak var currentStatusLabel: UILabel!
    @IBOutlet weak var targetStatusLabel: UILabel!
    
    @IBAction func transitionTimeDidChange(_ sender: UISlider) {
        transitionTimeSelected(sender.value)
    }
    @IBAction func delayDidChange(_ sender: UISlider) {
        delaySelected(sender.value)
    }
    
    @IBOutlet weak var acknowledgmentSwitch: UISwitch!
    
    @IBOutlet weak var onButton: UIButton!
    @IBAction func onTapped(_ sender: UIButton) {
        sendGenericOnOffMessage(turnOn: true)
    }
    @IBOutlet weak var offButton: UIButton!
    @IBAction func offTapped(_ sender: UIButton) {
        sendGenericOnOffMessage(turnOn: false)
    }
    @IBOutlet weak var readButton: UIButton!
    @IBAction func readTapped(_ sender: UIButton) {
        readGenericOnOffState()
    }
    @IBOutlet weak var repeatButton: UIButton!
    @IBAction func repeatTapped(_ sender: UIButton) {
        
        turnOn = true
        sendCount = 0
        receiveCount = 0
        repeatTimer = Timer.scheduledTimer(withTimeInterval: TimeInterval(Double(repeatIntervalField.text ?? "1")!),
                                           repeats: true) { _ in
            self.sendGenericOnOffMessage(turnOn: self.turnOn)
            self.turnOn = (self.turnOn == true) ? false : true
        }
        self.repeatTimer?.fire()
    }
    
    func stopRepeat() {
        repeatTimer?.invalidate()
        repeatTimer = nil
    }
    
    @IBOutlet weak var repeatIntervalField: UITextField!
    @IBOutlet weak var summaryLable: UILabel!
    
    // MARK: - Properties
    
    private var steps: UInt8 = 0
    private var stepResolution: StepResolution = .hundredsOfMilliseconds
    private var delay: UInt8 = 0
    
    private var sendCount: Int = 0 {
        didSet {
            summaryLable.text = String(format: "\(sendCount)/\(receiveCount), %.2f%%", (Float(receiveCount)/Float(sendCount)*100))
        }
    }
    private var receiveCount: Int = 0 {
        didSet {
            summaryLable.text = String(format: "\(sendCount)/\(receiveCount), %.2f%%", (Float(receiveCount)/Float(sendCount)*100))
        }
    }
    private var turnOn: Bool = true
    
    private var repeatTimer: Timer?
    
    // MARK: - Implementation
    
    override func awakeFromNib() {        
        let tap: UITapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
        self.contentView.addGestureRecognizer(tap)
    }
    
    @objc func dismissKeyboard() {
        self.contentView.endEditing(true)
    }

    override func reload(using model: Model) {
        let localProvisioner = MeshNetworkManager.instance.meshNetwork?.localProvisioner
        let isEnabled = localProvisioner?.hasConfigurationCapabilities ?? false
        
        defaultTransitionSettingsSwitch.isEnabled = isEnabled
        acknowledgmentSwitch.isEnabled = isEnabled
        onButton.isEnabled = isEnabled
        offButton.isEnabled = isEnabled
        readButton.isEnabled = isEnabled
        
        repeatIntervalField.text = "1"
    }
    
    override func meshNetworkManager(_ manager: MeshNetworkManager,
                                     didReceiveMessage message: MeshMessage,
                                     sentFrom source: Address, to destination: Address) -> Bool {
        switch message {
        case let status as GenericOnOffStatus:
            currentStatusLabel.text = status.isOn ? "ON" : "OFF"
            if let targetStatus = status.targetState, let remainingTime = status.remainingTime {
                if remainingTime.isKnown {
                    targetStatusLabel.text = "\(targetStatus ? "ON" : "OFF") in \(remainingTime.interval) sec"
                } else {
                    targetStatusLabel.text = "\(targetStatus ? "ON" : "OFF") in unknown time"
                }
            } else {
                targetStatusLabel.text = "N/A"
            }
            receiveCount += 1
            
        default:
            break
        }
        if repeatTimer?.isValid ?? false {
            return true
        }
        return false
    }
    
    override func meshNetworkManager(_ manager: MeshNetworkManager,
                                     didSendMessage message: MeshMessage,
                                     from localElement: Element, to destination: Address) -> Bool {
        // For acknowledged messages wait for the Acknowledgement Message.
        sendCount += 1
        if repeatTimer?.isValid ?? false {
            return true
        }
        return message is AcknowledgedMeshMessage
    }

}

private extension GenericOnOffViewCell {
    
    func transitionTimeSelected(_ value: Float) {
        switch value {
        case let period where period < 1.0:
            transitionTimeLabel.text = "Immediate"
            steps = 0
            stepResolution = .hundredsOfMilliseconds
        case let period where period >= 1 && period < 10:
            transitionTimeLabel.text = "\(Int(period) * 100) ms"
            steps = UInt8(period)
            stepResolution = .hundredsOfMilliseconds
        case let period where period >= 10 && period < 63:
            transitionTimeLabel.text = String(format: "%.1f sec", floorf(period) / 10)
            steps = UInt8(period)
            stepResolution = .hundredsOfMilliseconds
        case let period where period >= 63 && period < 116:
            transitionTimeLabel.text = "\(Int(period) - 56) sec"
            steps = UInt8(period) - 56
            stepResolution = .seconds
        case let period where period >= 116 && period < 119:
            transitionTimeLabel.text = "\(Int((period + 4) / 60) - 1) min 0\(Int(period + 4) % 60) sec"
            steps = UInt8(period) - 56
            stepResolution = .seconds
        case let period where period >= 119 && period < 175:
            let sec = (Int(period + 2) % 6) * 10
            let secString = sec == 0 ? "00" : "\(sec)"
            transitionTimeLabel.text = "\(Int(period + 2) / 6 - 19) min \(secString) sec"
            steps = UInt8(period) - 112
            stepResolution = .tensOfSeconds
        case let period where period >= 175 && period < 179:
            transitionTimeLabel.text = "\((Int(period) - 173) * 10) min"
            steps = UInt8(period) - 173
            stepResolution = .tensOfMinutes
        case let period where period >= 179:
            let min = (Int(period) - 173) % 6 * 10
            let minString = min == 0 ? "00" : "\(min)"
            transitionTimeLabel.text = "\(Int(period + 1) / 6 - 29) h \(minString) min"
            steps = UInt8(period) - 173
            stepResolution = .tensOfMinutes
        default:
            break
        }
    }
    
    func delaySelected(_ value: Float) {
        delay = UInt8(value)
        if delay == 0 {
            delayLabel.text = "No delay"
        } else {
            delayLabel.text = "Delay \(Int(delay) * 5) ms"
        }
    }
    
    func sendGenericOnOffMessage(turnOn: Bool) {
        
        // Clear the response fields.
        currentStatusLabel.text = nil
        targetStatusLabel.text = nil
        
        var message: MeshMessage!
        
        if acknowledgmentSwitch.isOn {
            if defaultTransitionSettingsSwitch.isOn {
                message = GenericOnOffSet(turnOn)
                //message.isSegmented = true
            } else {
                let transitionTime = TransitionTime(steps: steps, stepResolution: stepResolution)
                message = GenericOnOffSet(turnOn, transitionTime: transitionTime, delay: delay)
            }
        } else {
            if defaultTransitionSettingsSwitch.isOn {
                message = GenericOnOffSetUnacknowledged(turnOn)
            } else {
                let transitionTime = TransitionTime(steps: steps, stepResolution: stepResolution)
                message = GenericOnOffSetUnacknowledged(turnOn, transitionTime: transitionTime, delay: delay)
            }
        }
        if repeatTimer?.isValid == true {
            delegate?.send(message,
                           description: "Sending \(self.sendCount + 1) package\r\n Received \(self.receiveCount) packages",
                           delegate: self)
        } else {
            delegate?.send(message, description: "Sending...")
        }
    }
    
    func readGenericOnOffState() {
        guard !model.boundApplicationKeys.isEmpty else {
            parentViewController?.presentAlert(
                title: "Bound key required",
                message: "Bind at least one Application Key before sending the message.")
            return
        }
        
        delegate?.send(GenericOnOffGet(), description: "Reading state...")
    }
    

}

extension GenericOnOffViewCell: ProgressViewDelegate {
    
    func alertWillCancelled() {
        stopRepeat()
    }
    
}

//TODO MXCHIP 需要增加发送失败，退出repeat的回调
//TODO MXCHIP 增加键盘退出的处理
//TODO MXCHIP 速度快的时候，GATT连接丢包的原因是什么



