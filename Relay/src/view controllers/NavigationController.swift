//
//  NavigationController.swift
//  Forsta
//
//  Created by Mark Descalzo on 5/31/18.
//  Copyright © 2018 Forsta. All rights reserved.
//

import UIKit

class NavigationController: UINavigationController {
    
    private let STALLED_PROGRESS: Float = 0.9;
    
    var socketStatusView: UIProgressView?
    var updateStatusTimer: Timer?
    
    override func viewDidLoad() {
        super.viewDidLoad()
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.initializeObserver()
        TSSocketManager.sendNotification()
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        NotificationCenter.default.removeObserver(self)
        super.viewDidDisappear(animated)
    }
    
    func initializeSocketStatusBar() {
        if self.socketStatusView == nil {
            self.socketStatusView = UIProgressView(progressViewStyle: .default)
        }
        
        let bar = self.navigationBar.frame
        self.socketStatusView?.frame = CGRect(x: 0.0, y: bar.size.height - 1.0, width: self.view.frame.size.width, height: 1.0)
        self.socketStatusView?.progress = 0.0
        self.socketStatusView?.progressTintColor = ForstaColors.mediumBlue2()
        
        if socketStatusView?.superview == nil {
            self.navigationBar.addSubview(self.socketStatusView!)
        }
    }
    
    // MARK: - Socket Status Notifications
    func initializeObserver() {
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(socketDidOpen),
                                               name: NSNotification.Name.SocketOpened,
                                               object: nil)
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(socketDidClose),
                                               name: NSNotification.Name.SocketClosed,
                                               object: nil)
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(socketIsConnecting),
                                               name: NSNotification.Name.SocketConnecting,
                                               object: nil)
    }
    
    func socketDidOpen() {
        DispatchQueue.main.async {
            self.updateStatusTimer?.invalidate()
            for view in self.navigationBar.subviews {
                if view.isKind(of: UIProgressView.classForCoder()) {
                    view.removeFromSuperview()
                    self.socketStatusView = nil
                }
            }
        }
    }
    
    func socketDidClose() {
        DispatchQueue.main.async {
            if self.socketStatusView == nil {
                self.initializeSocketStatusBar()
                self.updateStatusTimer?.invalidate()
                self.updateStatusTimer = Timer.scheduledTimer(timeInterval: 0.5,
                                                         target: self,
                                                         selector: #selector(self.updateSocketConnecting),
                                                         userInfo: nil,
                                                         repeats: true)
            } else if (self.socketStatusView?.progress)! >= self.STALLED_PROGRESS {
                self.updateStatusTimer?.invalidate()
            }
        }
    }
    
    func updateSocketConnecting() {
        DispatchQueue.main.async {
            if self.socketStatusView != nil {
                let progress = (self.socketStatusView?.progress)! + 0.05
                self.socketStatusView?.progress = min(progress, self.STALLED_PROGRESS)
            }
        }
    }
    
    func socketIsConnecting() {
        DDLogInfo("socketIsConnecting called on NavigationController.")
        // Nothing to see here currently
    }
}
