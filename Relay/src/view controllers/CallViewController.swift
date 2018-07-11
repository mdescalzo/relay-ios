//
//  CallViewController.swift
//  Forsta
//
//  Created by Mark Descalzo on 7/10/18.
//  Copyright © 2018 Forsta. All rights reserved.
//

import UIKit

class CallViewController: UIViewController {

    @IBOutlet private weak var contactView: UIView!
    @IBOutlet private weak var nameLabel: UILabel!
    @IBOutlet private weak var callStatusLabel: UILabel!
    @IBOutlet private weak var contactAvatarView: UIImageView!
    
    @IBOutlet private weak var safewordsView: UIView!
    @IBOutlet private weak var authenticationStringLabel: UILabel!
    @IBOutlet private weak var explainAuthenticationStringLabel: UILabel!
    
    @IBOutlet private weak var activeCallButtonsView: UIView!
    @IBOutlet private weak var endCallButton: UIButton!
    
    @IBOutlet private weak var incomingCallButtonsView: UIView!
    @IBOutlet private weak var rejectButton: UIButton!
    @IBOutlet private weak var answerButton: UIButton!
    
    var callState: CallState?
    var contact: SignalRecipient?
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    func configure(callState: CallState, contact: SignalRecipient) {
        
    }
    
    // MARK: Button Actions
    @IBAction private func endCallTapped(_ sender: Any) {
        
    }
    
    @IBAction private func rejectCallTapped(_ sender: Any) {
        
    }
    
    @IBAction private func acceptCallTapped(_ sender: Any) {
        
    }
    
    @IBAction private func speakerTapped(_ sender: Any) {
        
    }
    
    @IBAction private func muteCallTapped(_ sender: Any) {
        
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
