//
//  FLNavigationController.swift
//  Forsta
//
//  Created by Mark Descalzo on 5/31/18.
//  Copyright © 2018 Forsta. All rights reserved.
//

import UIKit

class FLNavigationController: UINavigationController {

    static let STALLED_PROGRESS: Float = 0.9;

    var socketStatusView: UIProgressView?
    var updateStatusTimer: Timer?

    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destinationViewController.
        // Pass the selected object to the new view controller.
    }
    */

}
