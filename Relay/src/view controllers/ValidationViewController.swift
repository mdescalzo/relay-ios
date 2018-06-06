//
//  ValidationViewController.swift
//  Forsta
//
//  Created by Mark Descalzo on 5/30/18.
//  Copyright © 2018 Forsta. All rights reserved.
//

import UIKit
import CocoaLumberjack

class ValidationViewController: UITableViewController {
    
    var passwoordAuth: Bool = false
    
    @IBOutlet private weak var validationCodeTextField: UITextField!
    @IBOutlet private weak var submitButton: UIButton!
    @IBOutlet private weak var spinner: UIActivityIndicatorView!
    @IBOutlet private weak var resendCodeButton: UIButton!
    @IBOutlet private weak var infoLabel: UILabel!
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        

    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        self.navigationController?.navigationBar.isHidden = false
        
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(updateInfoLabel),
                                               name: NSNotification.Name(rawValue: FLRegistrationStatusUpdateNotification),
                                               object: nil)
        self.infoLabel.text = ""
        
        if passwoordAuth {
            self.validationCodeTextField.placeholder = NSLocalizedString("ENTER_PASSWORD", comment: "")
            self.validationCodeTextField.keyboardType = .default
            self.validationCodeTextField.isSecureTextEntry = true
            self.resendCodeButton.setTitle(NSLocalizedString("FORGOT_PASSWORD", comment: ""), for: .normal)
            self.resendCodeButton.isEnabled = true
            self.resendCodeButton.isHidden = false
        } else {
            self.validationCodeTextField.placeholder = NSLocalizedString("ENTER_VALIDATION_CODE", comment: "")
            self.validationCodeTextField.isSecureTextEntry = false
            self.validationCodeTextField.keyboardType = .numberPad
            self.resendCodeButton.setTitle(NSLocalizedString("RESEND_CODE", comment: ""), for: .normal)
            self.resendCodeButton.isEnabled = true
            self.resendCodeButton.isHidden = false
            
        }
        self.submitButton.titleLabel?.text = NSLocalizedString("SUBMIT_BUTTON_LABEL", comment: "")
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        self.validationCodeTextField.resignFirstResponder()
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        NotificationCenter.default.removeObserver(self)
        super.viewDidDisappear(animated)
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    // MARK: - Navigation
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "mainSegue" {
            DispatchQueue.main.async {
                let snc = segue.destination as! NavigationController
                let appDelegate = UIApplication.shared.delegate as! AppDelegate
                appDelegate.window.rootViewController = snc
                
                // TODO: Validate this step is necessary
                appDelegate.applicationDidBecomeActive(UIApplication.shared)
            }
        }
    }
    
    private func proceedToMain() {
        DispatchQueue.global(qos: .default).async {
            TSSocketManager.becomeActiveFromForeground()
            CCSMCommManager.refreshCCSMData()
        }
        self.performSegue(withIdentifier: "mainSegue", sender: self)
    }
    
    
    
    // MARK: - Actions
    @IBAction func onValidationButtonTap(sender: Any) {
        self.startSpinner()

        DispatchQueue.main.async {
            self.infoLabel.text = NSLocalizedString("Validating...", comment: "")
        }
        
        let orgName = CCSMStorage.sharedInstance().getOrgName()!
        let userName = CCSMStorage.sharedInstance().getUserName()!
        // Password Auth required
        if passwoordAuth {
            CCSMCommManager.authenticate(withPayload: [ "fq_tag": "@\(userName):\(orgName)",
                                                        "password": self.validationCodeTextField.text! ]) { (success, error) in
                                                            self.stopSpinner()
                                                            DispatchQueue.main.async {
                                                                self.infoLabel.text = NSLocalizedString("", comment: "")
                                                            }
                                                            
                                                            if success {
                                                                self.ccsmValidationSucceeded()
                                                            } else {
                                                                DDLogInfo("Password Validation failed with error: \(String(describing: error?.localizedDescription))")
                                                                self.ccsmValidationFailed()
                                                            }
            }
        } else {
            // SMS Auth required
            CCSMCommManager.authenticate(withPayload: [ "authtoken": "\(orgName):\(userName):\(self.validationCodeTextField.text!)" ]) { (success, error) in
                self.stopSpinner()
                if success {
                    self.ccsmValidationSucceeded()
                } else {
                    DDLogInfo("SMS Validation failed with error: \(String(describing: error?.localizedDescription))")
                    self.ccsmValidationFailed()
                }
            }
        }
    }
    
    @IBAction func onResendCodeButtonTap(sender: Any) {
        if passwoordAuth {
            DispatchQueue.main.async {
                let alert = UIAlertController(title: NSLocalizedString("RESETTING_PASSWORD", comment: ""), message: NSLocalizedString("ARE_YOU_SURE", comment: ""), preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: NSLocalizedString("NO", comment: ""), style: .default, handler: nil))
                alert.addAction(UIAlertAction(title: NSLocalizedString("YES", comment: ""), style: .destructive, handler: { (action) in
                    
                    CCSMCommManager.requestPasswordReset(forUser: CCSMStorage.sharedInstance().getUserName(),
                                                         org: CCSMStorage.sharedInstance().getOrgName(),
                                                         completion: { (success, error) in
                                                            if success {
                                                                DDLogInfo("Password reset request successful sent.")
                                                                self.presentAlertWithMessage(message: "Password reset request successful.\nPlease check your email or SMS for instructions.")
                                                            } else {
                                                                DDLogDebug("Password reset request failed with error:\(String(describing: error?.localizedDescription))")
                                                                self.presentAlertWithMessage(message: "Password reset request failed.\n\(String(describing: error?.localizedDescription))")
                                                            }
                    })
                }))
                self.navigationController?.present(alert, animated: true, completion: nil)
            }
        } else {
            CCSMCommManager.requestLogin(CCSMStorage.sharedInstance().getUserName(),
                                         orgName: CCSMStorage.sharedInstance().getOrgName(),
                                         success: {
                                            DDLogInfo("Request for code resend succeeded.")
                                            DispatchQueue.main.async {
                                                self.validationCodeTextField.text = ""
                                            }
            },
                                         failure: { error in
                                            DDLogDebug("Request for code resend failed.  Error: \(String(describing: error?.localizedDescription))");
            })
        }
    }
    
    // MARK: - Comms
    private func ccsmValidationSucceeded() {
        // Check if registered and proceed to next storyboard accordingly
        if TSAccountManager.isRegistered() {
            // We are, move onto main
            DispatchQueue.main.async {
                self.infoLabel.text = NSLocalizedString("This device is already registered.", comment: "")
            }
            self.proceedToMain()
        } else {
            FLDeviceRegistrationService.sharedInstance().registerWithTSS { error in
                if error == nil {
                    // Success!
                    self.proceedToMain()
                } else {
                    let err = error! as NSError
                    if err.domain == NSCocoaErrorDomain && err.code == NSUserActivityRemoteApplicationTimedOutError {
                        // Device provision timed out.
                        DDLogInfo("Device Autoprovisioning timed out.");
                        let alert = UIAlertController(title: NSLocalizedString("REGISTRATION_ERROR", comment: ""),
                                                      message: NSLocalizedString("PROVISION_FAILURE_MESSAGE", comment: ""),
                                                      preferredStyle: .alert)
                        alert.addAction(UIAlertAction(title: NSLocalizedString("TXT_CANCEL_TITLE", comment: ""),
                                                      style: .cancel,
                                                      handler: nil))
                        alert.addAction(UIAlertAction(title: NSLocalizedString("TRY_AGAIN", comment: ""),
                                                      style: .default,
                                                      handler: { action in
                                                        self.onValidationButtonTap(sender: self)
                        }))
                        alert.addAction(UIAlertAction(title: NSLocalizedString("REGISTER_FAILED_FORCE_REGISTRATION", comment: ""),
                                                      style: .destructive,
                                                      handler: { action in
                                                        let verifyAlert = UIAlertController(title: nil,
                                                                                            message: NSLocalizedString("REGISTER_FORCE_VALIDATION", comment: ""),
                                                                                            preferredStyle: .alert)
                                                        verifyAlert.addAction(UIAlertAction(title:NSLocalizedString("YES", comment: ""),
                                                                                            style: .destructive,
                                                                                            handler: { action in
                                                                                                self.startSpinner()
                                                                                                FLDeviceRegistrationService.sharedInstance().forceRegistration(completion: { provisionError in
                                                                                                    if provisionError == nil {
                                                                                                        DDLogInfo("Force registration successful.")
                                                                                                        self.proceedToMain()
                                                                                                    } else {
                                                                                                        DDLogError("Force registration failed with error: \(String(describing: provisionError?.localizedDescription))");
                                                                                                        self.stopSpinner()
                                                                                                        self.presentAlertWithMessage(message: "Forced provisioning failed.  Please try again.")
                                                                                                    }
                                                                                                })
                                                        }))
                                                        verifyAlert.addAction(UIAlertAction(title: NSLocalizedString("NO", comment: ""),
                                                                                            style: .default,
                                                                                            handler: { action in
                                                                                                // User Bailed
                                                                                                self.stopSpinner()
                                                        }))
                                                        DispatchQueue.main.async {
                                                            self.navigationController?.present(verifyAlert, animated: true, completion: {
                                                                self.infoLabel.text = ""
                                                                self.stopSpinner()
                                                            })
                                                        }
                        }))
                        DispatchQueue.main.async {
                            self.navigationController?.present(alert, animated: true, completion: {
                                self.infoLabel.text = ""
                                self.stopSpinner()
                            })
                        }
                        
                        
                    } else {
                        DDLogError("TSS Validation error: \(String(describing: error?.localizedDescription))");
                        DispatchQueue.main.async {
                            // TODO: More user-friendly alert here
                            let alert = UIAlertController(title: NSLocalizedString("REGISTRATION_ERROR", comment: ""),
                                                          message: NSLocalizedString("REGISTRATION_CONNECTION_FAILED", comment: ""),
                                                          preferredStyle: .alert)
                            alert.addAction(UIAlertAction(title: NSLocalizedString("OK", comment: ""),
                                                          style: .default,
                                                          handler: nil))
                            self.navigationController?.present(alert, animated: true, completion: {
                                self.infoLabel.text = ""
                                self.stopSpinner()
                            })
                        }
                    }
                }
            }
        }
    }
    
    private func ccsmValidationFailed() {
        self.presentAlertWithMessage(message: NSLocalizedString("Invalid credentials.  Please try again.", comment: ""))
    }
    
    // MARK: - Notificaton handling
    func updateInfoLabel(notification: Notification) {
        let payload = notification.object as! NSDictionary
        let messageString = payload["message"] as! String
        
        if messageString.count == 0 {
            DDLogWarn("Empty registration status notification received.  Ignoring.")
        } else {
            DispatchQueue.main.async {
                self.infoLabel.text = messageString
            }
        }
    }
    
    
    // MARK: - Helper methods
    private func startSpinner() {
        DispatchQueue.main.async {
            self.spinner.startAnimating()
            self.submitButton.isEnabled = false
            self.submitButton.alpha = 0.5
        }
    }
    
    private func stopSpinner() {
        DispatchQueue.main.async {
            self.spinner.stopAnimating()
            self.submitButton.isEnabled = true
            self.submitButton.alpha = 1.0
        }
    }
    
    private func presentAlertWithMessage(message: String) {
        DispatchQueue.main.async {
            let alertView = UIAlertController(title: nil,
                                              message: message,
                                              preferredStyle: .alert)
            
            let okAction = UIAlertAction(title: NSLocalizedString("OK", comment: ""),
                                         style: .default,
                                         handler: nil)
            alertView.addAction(okAction)
            self.navigationController?.present(alertView, animated: true, completion: nil)
        }
    }
}
