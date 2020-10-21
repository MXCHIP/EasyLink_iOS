//
//  browserViewController.swift
//  MICO
//
//  Created by William Xu on 2020/1/27.
//  Copyright © 2020 MXCHIP Co;Ltd. All rights reserved.
//

import UIKit
import Network

let searchingString = "Searching for MXCHIP Modules..."
let kWebServiceType = "_easylink._tcp"
let kInitialDomain = "local"
let PGY_APP_ID = "4d45c2a9a5e80fcb5c0a603b04907a39"
let REFRESH_LIST_TIME = 1.0

class WifiDevice  {
    var name: String = ""
    var resolving: Bool = false
    var bonjourService: NetService!
    var socket: AsyncSocket?
}


class wifiNetworkViewController: UITableViewController, Editable, NetServiceBrowserDelegate, NetServiceDelegate {
    
    private var _services:[WifiDevice] = Array()
    private var _displayServices:[WifiDevice] = Array()
    private var _netServiceBrowser: NetServiceBrowser! = NetServiceBrowser()
    private var _initialWaitOver: Bool = false

    override func viewDidLoad() {
        super.viewDidLoad()
        
        _netServiceBrowser.delegate = self
        tableView.setEmptyView(title: "No device found", message: "Devices should advertise service: \(kWebServiceType) under current network.", messageImage: UIImage(systemName: "wifi")! )
        showEmptyView()
        
        NotificationCenter.default.addObserver(forName: UIApplication.didEnterBackgroundNotification, object:nil, queue:nil) { _ in
            print("\(#function)")
        }
         
        NotificationCenter.default.addObserver(forName: UIApplication.willEnterForegroundNotification, object:nil,queue:nil) { _ in
             self.searchForModules()
        }

        // Make sure we have a chance to discover devices before showing the user that nothing was found (yet)
        tableView.reloadData()
        tableView.allowsMultipleSelection = false

        //refreshDeviceList(timeInterval:REFRESH_LIST_TIME)
        
        _netServiceBrowser.searchForServices(ofType: "_easylink._tcp.", inDomain: "")
         
        // 下拉刷新
//        tableView.mj_header = MJRefreshNormalHeader(){
//            self.searchForModules()
//            DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(1)) {
//                self.tableView.mj_header.endRefreshing()
//            }
//        }
            
        // 设置自动切换透明度(在导航栏下面自动隐藏)
        //browserTableView.mj_header.isAutomaticallyChangeAlpha = true;
        
        
    }
    
    func refreshDeviceList(timeInterval interval: TimeInterval) {
        Timer.scheduledTimer(withTimeInterval: interval, repeats: false) { (Timer) -> Void in
            //self._initialWaitOver = true;
            if self._displayServices.count > 0 {
                self.tableView.reloadData()
            }
        }
    }

    func searchForModules() {
        //self._initialWaitOver = false
        _netServiceBrowser.stop()
        _services.removeAll()
        _displayServices.removeAll()
        
        for i in 0..<_displayServices.count {
            if let socket: AsyncSocket = _displayServices[i].socket {
                socket.disconnect()
                socket.setDelegate(nil)
                _displayServices[i].socket = nil
            }
        }
        
        tableView.reloadData()

        _netServiceBrowser.searchForServices(ofType: kWebServiceType, inDomain: kInitialDomain)
        refreshDeviceList(timeInterval:REFRESH_LIST_TIME)
    }
    
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        guard let indexPath = tableView.indexPathForSelectedRow else {
            return
        }
        tableView.deselectRow(at: indexPath, animated: false)
        /* 蒲公英检查更新 */
        PgyUpdateManager.sharedPgy()?.checkUpdate()
    }
        
    // MARK: - NSNetServiceBrowserDelegate
    
    func netServiceBrowserDidStopSearch(_ browser: NetServiceBrowser) {
        print("Service Search stoped")
    }
    
    func netServiceBrowserWillSearch(_ browser: NetServiceBrowser) {
        print("Service Search will start")
    }
    
    func netServiceBrowser(_ browser: NetServiceBrowser, didRemove service: NetService, moreComing: Bool) {
        // If a service went away, stop resolving it if it's currently being resolved,
        // remove it from the list and update the table view if no more events are queued.
        NSLog("Remove service: \(service.name)")
        
        if let index = _services.firstIndex(where: { $0.name == service.name }) {
            _services[index].bonjourService?.stop()
            _services.remove(at: index)
        }
        
        for (index, value) in _displayServices.enumerated() {
            if value.name == service.name {
                let indexPath: IndexPath = IndexPath(row: index, section: 0)
                if let currentSelectedIndexPath: IndexPath = tableView.indexPathForSelectedRow {
                    if currentSelectedIndexPath == indexPath {
                        let alert = UIAlertController(title: "Disconnected", message: "Please check the power and Wi-Fi connection.", preferredStyle: .alert)
                        alert.addAction(UIAlertAction(title: NSLocalizedString("OK", comment: "Default action"), style: .default, handler: { (UIAlertAction) -> Void in
                            self.navigationController?.popToRootViewController(animated: true)
                        }))
                        self.present(alert, animated: true, completion: nil)
                    }
                }
                
                _displayServices.remove(at: index)
                
                tableView.deleteRows(at: [indexPath], with: .right)
                
                if _displayServices.count == 0 {
                    showEmptyView()
                }
                
                break
            }
        }
    }
        
    func netServiceBrowser(_ browser: NetServiceBrowser, didFind service: NetService, moreComing: Bool) {
        // If a service came online, add it to the list and update the table view if no more events are queued.
        let moduleService: WifiDevice = WifiDevice()
        moduleService.name = service.name
        moduleService.bonjourService = service
        moduleService.resolving = true
        
        service.delegate = self
        service.startMonitoring()
                
        for object in _services {
            if object.name == service.name{
                return
            }
        }
                
        NSLog("service found \(service.name)")
        
        _services.append(moduleService)
        service.resolve(withTimeout: 0.0)
        hideEmptyView(true, false)
    }

// MARK: - NSNetServiceDelegate
// This should never be called, since we resolve with a timeout of 0.0, which means indefinite
    func netService(_ sender: NetService, didNotResolve errorDict: [String : NSNumber]) {
        tableView .reloadData()
    }
    
    
    func netServiceDidResolveAddress(_ sender: NetService) {
        guard let txtRecoardData = sender.txtRecordData() else {
            return
        }
        
        let newTXTRecordData: [String : Data] = NetService.dictionary(fromTXTRecord: txtRecoardData)
        
        guard let newMacData: Data = newTXTRecordData["MAC"] else {
            return
        }
                
        NSLog("service info:\(sender.name)")
                
        if let wifiDevice = _services.first(where: { $0.bonjourService == sender }) {
            wifiDevice.resolving = false
            
            // Device already existed with same name
            if let j = _displayServices.firstIndex(where: { $0.bonjourService == sender }) {
                NSLog("Found an old service, \(_displayServices[j].bonjourService!.name), same service name, ignore...")
            }
            // Device already existed but updatd (has same MAC info)
            else if let j = _displayServices.firstIndex(where: {
                let oldTXTRecordData : [String : Data] = NetService.dictionary(fromTXTRecord: $0.bonjourService?.txtRecordData() ?? Data())
                let oldMacData: Data? = oldTXTRecordData["MAC"]
                return newMacData == oldMacData
            }) {
                NSLog("Found an new service, \(_displayServices[j].bonjourService?.name ?? "Error"), same MAC address, same device, replace at \(j)")
                _displayServices[j] = wifiDevice
                tableView.reloadRows(at: [IndexPath(row: j, section: 0)], with: .left)
            }
            // Device is not existed
            else {
                _displayServices.append(wifiDevice)
                let row: Int = _displayServices.count - 1
                
                tableView.insertRows(at: [IndexPath(row: row, section: 0)], with: .left)
            }
        }
    }
    
    // MARK: - UITableViewDataSource
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return _displayServices.count
    }
    
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return "Wi-Fi Devices"
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
//        let count = _displayServices.count
//
//        // If there are no services and searchingForServicesString is set, show one row explaining that to the user.
//        if count == 0 {
//            let cell = tableView.dequeueReusableCell(withIdentifier: "Searching", for: indexPath)
//
//            cell.textLabel!.text = searchingString
//            cell.textLabel!.textColor = UIColor(white: 0.5, alpha: 0.5)
//            cell.accessoryType = .none
//
//            // Make sure to get rid of the activity indicator that may be showing if we were resolving cell zero but
//            // then got didRemoveService callbacks for all services (e.g. the network connection went down).
//            cell.accessoryView = nil
//            return cell
//        }
        
        let cell: wifiDeviceCell = tableView.dequeueReusableCell(withIdentifier: "ModuleCell", for: indexPath) as! wifiDeviceCell
        
        cell.wifiDevice = _displayServices[indexPath.row]
        
        return cell;
        
    }
    
// MARK: - UITableViewDelegate
    override func tableView(_ tableView: UITableView, willSelectRowAt indexPath: IndexPath) -> IndexPath? {
        tableView.deselectRow(at: indexPath, animated: true)
        guard _displayServices.count != 0 else {
            return nil
        }
        
        guard let txtRecoardData = _displayServices[indexPath.row].bonjourService.txtRecordData() else {
            return nil
        }
        
        let txtRecoardDict: [String : Data] = NetService.dictionary(fromTXTRecord: txtRecoardData)
        let dataConvertProtocol = String(data: txtRecoardDict["Protocol"] ?? Data(), encoding: .ascii)
        
        if dataConvertProtocol == "com.mxchip.ha"{
            return indexPath;
        }
        else if dataConvertProtocol == "com.mxchip.spp" {
            return indexPath;
        }
        else{
            let alert = UIAlertController(title: "Cannot talk to me!", message: "Needs a compatiable data protocol.", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: NSLocalizedString("OK", comment: "Default action"), style: .default, handler: nil))
            self.present(alert, animated: true, completion: nil)
            return nil;
        }
    }
    
    override func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return 0.1
    }
    
    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
          return 70
      }
 

    func prepareForSegue(segue: UIStoryboardSegue!, sender: AnyObject!) {
        
        guard let indexPath = tableView.indexPath(for: sender as! UITableViewCell) else {
            return
        }
        let bonjourService = _displayServices[indexPath.row].bonjourService
        
        if segue.identifier == "Bonjour detail" {
            (segue.destination as! bonjourDetailTableViewController).service = bonjourService
        }
        else if segue.identifier == "Talk" {
            (segue.destination as! talkToModuleViewController).service = bonjourService
        }
        
    }


}
