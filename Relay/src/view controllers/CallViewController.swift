//
//  CallViewController.swift
//  Forsta
//
//  Created by Mark Descalzo on 7/10/18.
//  Copyright © 2018 Forsta. All rights reserved.
//

import UIKit

@available(iOS 10.0, *)
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
    
    @IBOutlet weak var muteButton: UIButton!
    @IBOutlet weak var speakerButton: UIButton!
    
    var call: CallKitCall?
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        self.muteButton.isEnabled = false
        self.speakerButton.isEnabled = false

    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(handleCallStateDidChangeNotification(notification:)),
                                               name: CallKitManager.CallStateChangedNotification,
                                               object: nil)
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        
        NotificationCenter.default.removeObserver(self, name: CallKitManager.CallStateChangedNotification, object: nil)
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    func configure(call: CallKitCall) {
        
        self.call = call
        self.updateUI()
    }
    
    // MARK: Button Actions
    @IBAction private func endCallTapped(_ sender: Any) {
        Environment.endCall(withId: (call?.uuid.uuidString)!)
    }
    
    @IBAction private func rejectCallTapped(_ sender: Any) {
        Environment.endCall(withId: (call?.uuid.uuidString)!)
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
    
    // Handler for changes to call state
    @objc fileprivate func handleCallStateDidChangeNotification(notification: NSNotification){
        DDLogInfo("Call state changed with notification: \(notification)")
        // TODO: extract the call and apply changes to the UI
        self.updateUI()
        
        if (self.call?.hasEnded)! {
            self.dismiss(animated: true, completion: nil)
        }
    }

    fileprivate func updateUI() {
        
        DispatchQueue.main.async {
            
            self.nameLabel.text = self.call?.handle
            
            self.safewordsView.isHidden = true
            self.authenticationStringLabel.isHidden = true
            self.explainAuthenticationStringLabel.isHidden = true

            self.activeCallButtonsView.isHidden = true
            self.incomingCallButtonsView.isHidden = true

            if (self.call?.hasConnected)! {
                self.callStatusLabel.text = NSLocalizedString("IN_CALL_CONNECTED", comment: "")
                self.activeCallButtonsView.isHidden = false
                self.muteButton.isEnabled = true
                self.speakerButton.isEnabled = true
            } else if (self.call?.hasStartedConnecting)! {
                self.callStatusLabel.text = NSLocalizedString("IN_CALL_CONNECTING", comment: "")
                self.activeCallButtonsView.isHidden = false
            } else if (self.call?.hasEnded)! {
                self.callStatusLabel.text = NSLocalizedString("CALL_ENDED", comment: "")
                self.activeCallButtonsView.isHidden = false
             } else {
                if (self.call?.isOutgoing)! {
                    self.callStatusLabel.text = NSLocalizedString("IN_CALL_DIALING", comment: "")
                    self.activeCallButtonsView.isHidden = false
                } else {
                    self.callStatusLabel.text = NSLocalizedString("IN_CALL_RINGING", comment: "")
                    self.incomingCallButtonsView.isHidden = false
                }
            }
        }
    }
}
