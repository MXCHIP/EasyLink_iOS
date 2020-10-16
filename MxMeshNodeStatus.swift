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
    case paused(latestMessage: MeshMessage?, remainTime: TimeInterval)
    /// The node has gone offline, as did not receive any message for a while or bearer
    ///  is disconnected for a period
    case offline
    /// We have received any message from the node, then set the node to online status
    case online(latestMessage: MeshMessage?)
    case allwaysOnline
    
    func isEqual(_ status: NodeStatus)->Bool {
        switch self {
        case .unknown:
            if case .unknown = status  { return true }
        case .offline:
            if case .offline = status  { return true }
        case .allwaysOnline:
            if case .allwaysOnline = status  { return true }
        case .paused(_, _):
            if case .paused(_, _) = status { return true }
        case .online(_):
            if case .online(_) = status { return true }
        }
        return false
    }
    
    static func ==(lhs: NodeStatus, rhs: NodeStatus)->Bool {
        return lhs.isEqual(rhs)
    }
}

typealias StatusContext = (status: NodeStatus, timer: Timer?)


public protocol MxNodeStatusDelegate: class {
    /// A callback called whenever a Mesh node online status is changed.
    ///
    func update(to nodes: [Node])
}

class MxNodeStatusManager {

    static let syncResponseDelay: UInt16 = 5
    var immediatelyShow: Bool = false
    let manager: MeshNetworkManager!
    /// The delegate will receive callbacks whenever a complete
    /// Mesh Message has been received and reassembled.
    public weak var delegate: MeshNetworkDelegate?
    public weak var proxyFilterdelegate: ProxyFilterDelegate?
    public weak var statusDelegate: MxNodeStatusDelegate?
    
    /// The status records
    var nodeStatus: [Node: StatusContext] = [:]
    var messageTimeout: TimeInterval = 60
    
    /// A shortcut to the manager's logger.
    private var logger: LoggerDelegate? {
        return manager.logger
    }
    
    /// After beraer is disconnected
    /// 1. Set status to offlining and stop message timer
    /// 2. Start bearerDisconnected timer
    ///
    /// If bearerDisconnected timer reach the Timeout
    /// 1. Set offlining to offline
    ///
    /// Once beraer is connected
    /// * bearerDisconnected timer is not reach the timeout
    ///    Set offlining to online and restart the message timer
    /// * bearerDisconnected timer is fired
    ///    Send the MXCHIP Sync message?
    var interactiveTimeout: TimeInterval = 120
    var synced: Bool = false
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
        bring(node, to: NodeStatus.online(latestMessage: message))
    }
    
    func scheduledMessageTimer(_ interval: TimeInterval, for node: Node)-> Timer {
        let timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: false) { [node, self] _ in
            if let _ = self.nodeStatus[node] {
                self.nodeStatus[node] = (.offline, nil)
                self.statusDelegate?.update(to: [node])
                self.logger?.i(.mxNodeStatus ,"[Offline] Set \(node.name ?? "Unknown") to offline after \(messageTimeout) seconds")
            }
        }
        return timer
    }

    func pauseStatusCheck() {
        var nodesToUpdate: [Node] = []
        for node in nodeStatus.keys {
            if case .online(let message) = nodeStatus[node]?.status {
                var fireTime = messageTimeout
                if let timer = nodeStatus[node]?.timer, timer.isValid {
                    fireTime = timer.fireDate.timeIntervalSinceNow
                    timer.invalidate()
                }
                nodeStatus[node] = (.paused(latestMessage: message, remainTime: fireTime), nil)
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
                bringAllNodes(to: NodeStatus.online(latestMessage: nil))
            }
            sendSyncMessage()
            return
        }
        var nodesToUpdate: [Node] = []
        for node in nodeStatus.keys {
            if case let .paused(message, remainTime: time) = nodeStatus[node]?.status {
                let timer = scheduledMessageTimer(time, for: node)
                nodeStatus[node] = (.online(latestMessage: message), timer)
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
   
    func bring(_ node: Node, to status: NodeStatus, in timeout: TimeInterval = 60) {
        guard !node.isLocalProvisioner else {
            return
        }
        let oldStatus = nodeStatus[node]?.status
        nodeStatus[node]?.timer?.invalidate()
        nodeStatus[node] = (status, scheduledMessageTimer(timeout, for: node))
        
        if oldStatus != status {
            statusDelegate?.update(to: [node])
        }
    }
    
    ///首次连接，将所有设备先直接切换成在线，并且启动定时器，定时器时间设置成大于同步消息的最大延时时间
    func bringAllNodes(to status: NodeStatus, in timeout: TimeInterval = TimeInterval(syncResponseDelay + 2)) {
        if let network = MeshNetworkManager.instance.meshNetwork {
            for node in network.nodes {
                bring(node, to: status, in: timeout)
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
            if case .online(_) = nodeStatus[node]?.status  {
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
