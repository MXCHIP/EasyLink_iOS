//
//  RootViewController.swift
//  MICO
//
//  Created by William Xu on 2020/5/11.
//  Copyright © 2020 MXCHIP Co;Ltd. All rights reserved.
//

import UIKit
import CoreLocation

let sceneSegmentHeight = CGFloat(40)

class RootViewController: UIViewController, UIScrollViewDelegate {
    
    let manager: CLLocationManager = CLLocationManager()
    var scrollView: UIScrollView!
    var scrollWidth, scrollHeight : CGFloat!
    
    override func awakeFromNib() {
        sleep(1)
        super.awakeFromNib()
    }
    
    override func viewDidLoad() {
        
        super.viewDidLoad()
        
        scrollWidth = UIScreen.main.bounds.size.width
        scrollHeight =  UIScreen.main.bounds.size.height - (self.navigationController?.navigationBar.bounds.size.height ?? CGFloat(44)) - sceneSegmentHeight
        
        
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
        self.title = "My Device Center v\(version)"
        
        let sceneSegment: HMSegmentedControl! = HMSegmentedControl.init(sectionTitles: ["Wi-Fi", "BT Mesh"])
        sceneSegment.autoresizingMask = [.flexibleRightMargin, .flexibleWidth]
        sceneSegment.frame = CGRect(x: 0, y: 0, width: scrollWidth, height: sceneSegmentHeight)
        sceneSegment.segmentEdgeInset = UIEdgeInsets(top: 0, left: 10, bottom: 0, right: 10)
        sceneSegment.selectionIndicatorHeight = 2.0
        sceneSegment.backgroundColor = UIColor(red: 0.1, green: 0.4, blue: 0.8, alpha: 1)
        sceneSegment.titleTextAttributes = [NSAttributedString.Key.foregroundColor: UIColor.gray]
        sceneSegment.selectedTitleTextAttributes = [NSAttributedString.Key.foregroundColor: UIColor.white]
        sceneSegment.selectionIndicatorColor = UIColor(red: 0.5, green: 0.8, blue: 1, alpha: 1)
        sceneSegment.selectionStyle = .box
        sceneSegment.selectionIndicatorLocation = .up
        sceneSegment.addTarget(self, action: #selector(segmentedControlChangedValue), for: .valueChanged)
        self.view.addSubview(sceneSegment)
        
        scrollView = UIScrollView.init(frame: CGRect(x: 0, y: sceneSegmentHeight, width: scrollWidth, height: scrollHeight))
        scrollView.backgroundColor = UIColor(red: 0.7, green: 0.7, blue: 0.7, alpha: 1)
        scrollView.isPagingEnabled = true
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.contentSize = CGSize(width: scrollWidth * 2, height: scrollHeight)
        scrollView.delegate = self;
        scrollView.scrollRectToVisible(CGRect(x: 0, y: 0, width: scrollWidth, height: scrollHeight), animated: true)
        self.view.addSubview(scrollView)
        
        let localDevice = self.storyboard!.instantiateViewController(withIdentifier: "Wi-Fi") as! browserViewController
        let conThings = self.storyboard!.instantiateViewController(withIdentifier: "BTMesh") as! ConThingsViewController
        
        /*Local devices list*/
        localDevice.view.frame = CGRect(x: 0, y: 0, width: scrollWidth, height: scrollHeight)
        //localDevice.willMove(toParent: self)
        scrollView.addSubview(localDevice.view)
        self.addChild(localDevice)
        //localDevice.didMove(toParent: self)
        
        /*Devices list on www.conthings.com*/
        conThings.view.frame = localDevice.view.frame.offsetBy(dx: scrollWidth, dy: 0)
        //conThings.willMove(toParent: self)
        scrollView.addSubview(conThings.view)
        self.addChild(conThings)
        //conThings.didMove(toParent: self)
        
        manager.requestWhenInUseAuthorization()
        
    }
    
    @objc func segmentedControlChangedValue(_ segmentedControl: HMSegmentedControl) {
        let scrollRect = UIScreen.main.bounds.offsetBy(dx: CGFloat(segmentedControl.selectedSegmentIndex) * scrollWidth, dy: 0)
        self.scrollView.scrollRectToVisible(scrollRect, animated: true)
    }

    @IBAction func guideButtonPressed(_ button: UIButton) {
        NSLog("guideButtonPressed")
        if let guildURL = URL.init(string: "http://www.mxchip.com") {
            UIApplication.shared.open(guildURL)
        }
    }

//    - (void)scrollViewDidEndDecelerating:(UIScrollView *)scrollView {
//        CGFloat pageWidth = scrollView.frame.size.width;
//        NSInteger page = scrollView.contentOffset.x / pageWidth;
//        
//        [sceneSegment setSelectedSegmentIndex:page animated:YES];
//    }
    
}
