//
//  wifiDeviceCell.swift
//  MICO
//
//  Created by William Xu on 2020/2/4.
//  Copyright © 2020 MXCHIP Co;Ltd. All rights reserved.
//


extension Data {
    func host() -> String {
        let sock_len = MemoryLayout<sockaddr_in>.size
        
        let p_buf = UnsafeMutablePointer<UInt8>.allocate(capacity: sock_len)
        self.copyBytes(to: p_buf, count: Int(MemoryLayout<sockaddr>.size))
        
        let p_addrIn = UnsafeRawPointer(p_buf).bindMemory(to: sockaddr_in.self, capacity: 1)
        let p_addrIn6 = UnsafeRawPointer(p_buf).bindMemory(to: sockaddr_in6.self, capacity: 1)

        let addrIn:sockaddr_in = p_addrIn.pointee
        let addrIn6:sockaddr_in6 = p_addrIn6.pointee
                
        if addrIn.sin_family == AF_INET {
            if let address = inet_ntoa(addrIn.sin_addr) {
                let uint64Pointer: UnsafePointer<UInt8> = UnsafeRawPointer(address).bindMemory(to: UInt8.self, capacity: 1)
                return String(cString: uint64Pointer)
            } else {
                return "Unknown"
            }
        }
        else if addrIn.sin_family == AF_INET6 {
//            let addr_in6: UnsafePointer<sockaddr_in6> = UnsafeRawPointer(&addrIn).bindMemory(to: sockaddr_in6.self, capacity: 1)
            var ip6 = addrIn6.sin6_addr
            var addrStr: [CChar] = Array(repeating: 0, count: Int(INET6_ADDRSTRLEN))
            inet_ntop(AF_INET6, &ip6, &addrStr, socklen_t(Int(INET6_ADDRSTRLEN)))
            return String(cString: &addrStr)
        }
        else {
            return "Unknown"
        }
    }
}

class wifiDeviceCell: UITableViewCell {
    
    var device: WifiDevice?
    @IBOutlet weak var lightStrengthView:UIImageView!
    var checkMarkView: UIView?
    var socket: AsyncSocket?
    private var _wifiDevice: WifiDevice?
    
    var wifiDevice: WifiDevice {
        set(newWifiDevice) {
            _wifiDevice = newWifiDevice
                        
            // Set up the text for the cell
            let bonjourService: NetService! = newWifiDevice.bonjourService
            
            let txtRecordDict = NetService.dictionary(fromTXTRecord: bonjourService.txtRecordData() ?? Data())
            let mac = String(data: txtRecordDict["MAC"] ?? Data(), encoding: .ascii)
            
            // Set module image
            if let moduleData = txtRecordDict["Model"],
                let module = String(data: moduleData, encoding: .ascii),
                let moduleImage = UIImage(named: "\(module).png")  {
                self.imageView!.image = moduleImage
            }
            else{
                self.imageView!.image = UIImage(named: "known_logo.png")
            }
            
            self.imageView!.contentMode = .scaleAspectFit
            
            // Set module name
            var serviceName = newWifiDevice.name
            if let seperateor = serviceName.lastIndex(of: "#") {
                serviceName = String(serviceName.prefix(upTo: seperateor))
            }
            self.textLabel!.text = serviceName
            self.textLabel!.backgroundColor = UIColor(ciColor: .clear)
            //self.textLabel!.textColor = UIColor(cgColor: .black)
            
            // Display ip adress and mac address
            let ip = bonjourService.addresses?[0] ?? Data()
            let detailString = String("MAC: \(mac ?? "Format error")\nIP :\(ip.host())")
            
            self.detailTextLabel!.backgroundColor = UIColor(ciColor: .clear)
            self.detailTextLabel!.text = detailString;
            
            //[self startCheckIndicator:YES];
            self.accessoryType = .detailButton
            //[self startActivityIndicator: YES];
            

        }
        get{
            return _wifiDevice ?? WifiDevice()
        }
    }
    
    override func awakeFromNib() {
        // Initialization code
        let cellFrame: CGRect = self.contentView.frame
        let frame: CGRect = CGRect(x: 283, y: (cellFrame.size.height)/2-32, width: 25, height: 25)
        let checkMarkView: UIView = UIView.init(frame: frame)
        self.contentView.addSubview(checkMarkView)
        super.awakeFromNib()
    }

}

/*
- (void)closeClient:(NSTimer *)timer
{
    //[self setSelected:NO animated:(BOOL)YES];
    //self.accessoryView = nil;
}
 */
/*
- (void)setSelected:(BOOL)selected animated:(BOOL)animated
{
    if(selected==YES){
        NSLog(@"selected");
    }else{
        NSLog(@"unselected");
    }
    [super setSelected:selected animated:animated];

    // Configure the view for the selected state
}


- (void)startActivityIndicator: (BOOL) enable
{
    for(UIView *subview in [checkMarkView subviews])
        [subview removeFromSuperview];
    
    if(enable == YES){
        CGRect frame = CGRectMake(0.0, 0.0, kProgressIndicatorSize, kProgressIndicatorSize);
        UIActivityIndicatorView* spinner = [[UIActivityIndicatorView alloc] initWithFrame:frame];
        [spinner setBackgroundColor:[UIColor whiteColor]];
        [spinner startAnimating];
        spinner.activityIndicatorViewStyle = UIActivityIndicatorViewStyleGray;
        [spinner sizeToFit];
        spinner.autoresizingMask = (UIViewAutoresizingFlexibleLeftMargin |
                                    UIViewAutoresizingFlexibleRightMargin |
                                    UIViewAutoresizingFlexibleTopMargin |
                                    UIViewAutoresizingFlexibleBottomMargin);
        [checkMarkView addSubview:spinner];

    }
}

- (void)startCheckIndicator: (BOOL) enable
{
    for(UIView *subview in [checkMarkView subviews])
        [subview removeFromSuperview];
    
    if(enable == YES){
        CGRect frame = CGRectMake(0.0, 0.0, kProgressIndicatorSize, kProgressIndicatorSize);
        UIActivityIndicatorView* spinner = [[UIActivityIndicatorView alloc] initWithFrame:frame];
        [spinner startAnimating];
        spinner.activityIndicatorViewStyle = UIActivityIndicatorViewStyleGray;
        [spinner sizeToFit];
        spinner.autoresizingMask = (UIViewAutoresizingFlexibleLeftMargin |
                                    UIViewAutoresizingFlexibleRightMargin |
                                    UIViewAutoresizingFlexibleTopMargin |
                                    UIViewAutoresizingFlexibleBottomMargin);
        [checkMarkView addSubview:spinner];
    }
}



@end
*/
