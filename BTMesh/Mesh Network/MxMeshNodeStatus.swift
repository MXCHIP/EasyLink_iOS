//
//  MxMeshNodeStatus.swift
//  MICO
//
//  Created by William Xu on 2020/8/15.
//  Copyright © 2020 MXCHIP Co;Ltd. All rights reserved.
//

import Foundation
import nRFMeshProvision


enum NodeStatus: Equatable {
    case unknown
    /// The bearer is disconnected, node will go offline after a period.
    case paused(remainTime: TimeInterval?)
    /// The node has gone offline, as did not receive any message for a while or bearer
    ///  is disconnected for a period
    case offline
    /// We have received any message from the node, then set the node to online status
    case online
    /// Local provisioner node is always online
    case allwaysOnline
}

typealias StatusContext = (
    status: NodeStatus,
    remainTime: TimeInterval?,
    timer: Timer?
)


public protocol MxNodeStatusDelegate: class {
    /// A callback called whenever a Mesh node online status is changed.
    ///
    func update(to nodes: [Node])
}

class MxNodeStatusManager {
    
    // Mesh设备响应同步请求的最大延时时间
    static let syncResponseDelay: UInt16 = 5
    // 节点收到任何消息后，将节点设置成“在线”状态的时间
    var messageTimeout: TimeInterval = 60
    // 连接上代理后，是否立即显示在线。还是等带同步请求的应答
    var immediatelyShow: Bool = false
    // 断开和代理的连接或者APP进入后台的一段时间后，需要重新发送
    var interactiveTimeout: TimeInterval = 120
    // 节点状态处理的代理
    weak var statusDelegate: MxNodeStatusDelegate?
    
    // 是否重置节点，并且发送同步请求
    private var synced: Bool = false
    
    private let manager: MeshNetworkManager!
    /// The node records
    private var nodeStatus: [Node: StatusContext] = [:]
    private var latestMessage: [Node: MeshMessage] = [:]
    private var attributes: [Node: [MxGenericAttribute]] = [:]
    
    /// A shortcut to the manager's logger.
    private var logger: LoggerDelegate? {
        return manager.logger
    }
    
    
    var firstSyncedTimer: Timer?
    var latestBackgroundTime: Date = Date()
    var latestDisconnectedTime: Date = Date()
    
    // MARK: - Implementation

    init(_ meshNetworkManager: MeshNetworkManager, messageTimeout: TimeInterval, interactiveTimeout: TimeInterval) {
        manager = meshNetworkManager
        
        self.messageTimeout = messageTimeout
        self.interactiveTimeout = interactiveTimeout
        
        NotificationCenter.default.addObserver(self, selector: #selector(appDidEnterBackground), name: UIApplication.didEnterBackgroundNotification, object: nil)
        
        NotificationCenter.default.addObserver(self, selector: #selector(appWillEnterForeground), name: UIApplication.willEnterForegroundNotification, object: nil)
    }
    
    
    func handle(incomingMessage message: MeshMessage, sentFrom source: Address, to destination: Address) {
        guard let node = manager.meshNetwork?.node(withAddress: source), !node.isLocalProvisioner else {
            return
        }
        logger?.i(.mxNodeStatus, "[Online] Recv the message form \(node.name ?? source.description)")
        bringOnline(for: node, in: messageTimeout)
        latestMessage[node] = message
        
        if case let status as MxAttributeStatusMessage = message {
            var new = attributes[node] ?? Array<MxGenericAttribute>()
            new.insert(status.attributes)
            attributes[node] = new
        }
    }
    
    func scheduledMessageTimer(_ interval: TimeInterval, for node: Node)-> Timer {
        let timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: false) { [node, self] _ in
            if let _ = self.nodeStatus[node] {
                self.nodeStatus[node] = (.offline, nil, nil)
                self.statusDelegate?.update(to: [node])
                self.logger?.i(.mxNodeStatus ,"[Offline] Set \(node.name ?? "Unknown") to offline after \(messageTimeout) seconds")
            }
        }
        return timer
    }

    func pauseStatusCheck() {
        var nodesToUpdate: [Node] = []
        for node in nodeStatus.keys {
            if case .online = nodeStatus[node]?.status {
                var fireTime = messageTimeout
                if let timer = nodeStatus[node]?.timer, timer.isValid {
                    fireTime = timer.fireDate.timeIntervalSinceNow
                    timer.invalidate()
                }
                nodeStatus[node] = (.paused(remainTime: nil), fireTime, nil)
                nodesToUpdate.append(node)
            }
        }
        if nodesToUpdate.count > 0 {
            statusDelegate?.update(to: nodesToUpdate)
        }
    }
    
    /// 把暂停状态改成在线状态，恢复定时器。如果未同步，则发送同步请求。
    func resumeStatusCheck() {
        if !synced {
            // 将设备立即设置成在线状态，是否可以提升用户体验。
            if immediatelyShow {
                bringAllNodesOnline()
            }
            sendSyncMessage()
            return
        }
        var nodesToUpdate: [Node] = []
        for node in nodeStatus.keys {
            if case .paused = nodeStatus[node]?.status {
                let timer = scheduledMessageTimer((nodeStatus[node]?.remainTime)!, for: node)
                nodeStatus[node] = (.online, 0, timer)
                nodesToUpdate.append(node)
            }
        }
        if nodesToUpdate.count > 0 {
            statusDelegate?.update(to: nodesToUpdate)
        }
    }
    
    func newProxyDidSetup(type: ProxyFilerType, addresses: Set<Address>) {
        logger?.i(.mxNodeStatus, "Proxy filter is synced!")

        /// 只有在代理在断开时间较长时才发送同步请求
        if (-latestDisconnectedTime.timeIntervalSinceNow) > interactiveTimeout {
            synced = false
        }

        resumeStatusCheck()
    }
    
    @objc func appDidEnterBackground() {
        logger?.d(.mxNodeStatus, "Application did enter background!")
        pauseStatusCheck()
        terminateSyncMessage()
        latestBackgroundTime = Date()

    }
    
    @objc func appWillEnterForeground() {
        logger?.d(.mxNodeStatus, "Application will enter foreground!")
        
        if (-latestBackgroundTime.timeIntervalSinceNow) > interactiveTimeout {
            synced = false
        }
        
        if MeshNetworkManager.bearer.isOpen {
            resumeStatusCheck()
        }
    }
}

private extension MxNodeStatusManager {
   
    func bringOnline(for node: Node, in timeout: TimeInterval = 60) {
        guard !node.isLocalProvisioner else {
            return
        }
        var needsUpdate = true
        if let oldStatus = nodeStatus[node]?.status, oldStatus == .online {
            needsUpdate = false
        }
        
        nodeStatus[node]?.timer?.invalidate()
        nodeStatus[node] = (.online, nil, scheduledMessageTimer(timeout, for: node))
        
        if needsUpdate {
            statusDelegate?.update(to: [node])
        }
    }
    
    ///首次连接，将所有设备先直接切换成在线，并且启动定时器，定时器时间设置成大于同步消息的最大延时时间
    func bringAllNodesOnline(timeout: TimeInterval = TimeInterval(syncResponseDelay + 2)) {
        if let network = MeshNetworkManager.instance.meshNetwork {
            for node in network.nodes {
                bringOnline(for: node, in: timeout)
            }
        }
    }
}
    
    // MARK: - APIs

extension MxNodeStatusManager {

    /// Call this function in meshNetworkDidChange() when Mesh network is changed
    func clear() {
        
        var announceNodes: [Node] = []
        for node in nodeStatus.keys {
            nodeStatus[node]?.timer?.invalidate()
            if case .online = nodeStatus[node]?.status  {
                nodeStatus[node]?.status = .offline
                announceNodes.append(node)
            }
        }
        if announceNodes.count > 0 {
            statusDelegate?.update(to: announceNodes)
        }
 
        nodeStatus.removeAll()
        synced = false
    }
    
    func getStatus(ofNode node: Node) -> NodeStatus {
        if node.isLocalProvisioner {
            return .allwaysOnline
        }
        
        guard let status = nodeStatus[node]?.status else {
            return .offline
        }
        
        return status
    }
    
    // 获取MXCHIP属性值
    func getMxAttributes(ofNode node: Node) -> [MxGenericAttribute] {
        return attributes[node] ?? Array<MxGenericAttribute>()
    }
    
    func sendSyncMessage() {
        let message = MxSync(tid: 0, range: .mainAttribute, maxDelay: MxNodeStatusManager.syncResponseDelay)
        do {
            try _ = manager.send(message, to:  MeshAddress(0xD002), using: manager.meshNetwork!.applicationKeys[0])
        } catch {
            return
        }
        
        logger?.i(.mxNodeStatus, "Send SYNC message")
        firstSyncedTimer = Timer.scheduledTimer(withTimeInterval: 5, repeats: false) {_ in self.synced = true }
    }
    
    func terminateSyncMessage() {
        if let firstSyncedTimer = firstSyncedTimer, firstSyncedTimer.isValid {
            firstSyncedTimer.invalidate()
            self.firstSyncedTimer = nil
        }
    }
}

// MARK: - BearerDelegate

extension MxNodeStatusManager: BearerDelegate {
    
    func bearerDidOpen(_ bearer: Bearer) {
        logger?.d(.mxNodeStatus, "Bearer is open!")
    }
    
    func bearer(_ bearer: Bearer, didClose error: Error?) {
        logger?.d(.mxNodeStatus, "Bearer disconnected!")
        pauseStatusCheck()
        terminateSyncMessage()
        latestDisconnectedTime = Date()
    }
    
}


extension Node: Hashable {
    
    var status: NodeStatus {
        return MeshNetworkManager.statusManager.getStatus(ofNode: self)
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(uuid)
    }
    
}


//TODO MXCHIP 增加存储节点的状态
//TODO MXCHIP 增加一个刷新状态的功能
