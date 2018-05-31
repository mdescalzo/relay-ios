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
        
        if passwoordAuth {
            self.validationCodeTextField.placeholder = NSLocalizedString("ENTER_PASSWORD", comment: "")
            self.resendCodeButton.isEnabled = false
            self.resendCodeButton.isHidden = true
        } else {
            self.validationCodeTextField.placeholder = NSLocalizedString("ENTER_VALIDATION_CODE", comment: "")
            self.resendCodeButton.isEnabled = true
            self.resendCodeButton.isHidden = false
            
        }
        self.submitButton.titleLabel?.text = NSLocalizedString("SUBMIT_BUTTON_LABEL", comment: "")
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        self.navigationController?.navigationBar.isHidden = false
        
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(updateInfoLabel),
                                               name: NSNotification.Name(rawValue: FLRegistrationStatusUpdateNotification),
                                               object: nil)
        self.infoLabel.text = ""
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        NotificationCenter.default.removeObserver(self)
        super.viewDidDisappear(animated)
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    /*
     override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
     let cell = tableView.dequeueReusableCell(withIdentifier: "reuseIdentifier", for: indexPath)
     
     // Configure the cell...
     
     return cell
     }
     */
    
    /*
     // Override to support conditional editing of the table view.
     override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
     // Return false if you do not want the specified item to be editable.
     return true
     }
     */
    
    /*
     // Override to support editing the table view.
     override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCellEditingStyle, forRowAt indexPath: IndexPath) {
     if editingStyle == .delete {
     // Delete the row from the data source
     tableView.deleteRows(at: [indexPath], with: .fade)
     } else if editingStyle == .insert {
     // Create a new instance of the appropriate class, insert it into the array, and add a new row to the table view
     }
     }
     */
    
    /*
     // Override to support rearranging the table view.
     override func tableView(_ tableView: UITableView, moveRowAt fromIndexPath: IndexPath, to: IndexPath) {
     
     }
     */
    
    /*
     // Override to support conditional rearranging of the table view.
     override func tableView(_ tableView: UITableView, canMoveRowAt indexPath: IndexPath) -> Bool {
     // Return false if you do not want the item to be re-orderable.
     return true
     }
     */
    
    
    // MARK: - Navigation
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "mainSegue" {
            let snc = segue.destination as! NavigationController
            let appDelegate = UIApplication.shared.delegate as! AppDelegate
            appDelegate.window.rootViewController = snc
            
            // TODO: Validate this step is necessary
            appDelegate.applicationDidBecomeActive(UIApplication.shared)
        }
    }
    
    private func proceedToMain() {
        DispatchQueue.global(qos: .default).async {
            TSSocketManager.becomeActiveFromForeground()
            CCSMCommManager.refreshCCSMData()
        }
        DispatchQueue.main.async {
            self.stopSpinner()
            self.performSegue(withIdentifier: "mainSegue", sender: self)
        }
    }
    
    
    
    // MARK: - Actions
    @IBAction func onValidationButtonTap(sender: Any) {
        if passwoordAuth {
            // TODO: Password auth submission
        } else {
            DispatchQueue.main.async {
                self.infoLabel.text = NSLocalizedString("Validating code", comment: "")
                self.startSpinner()
            }
            
            CCSMCommManager.verifyLogin(self.validationCodeTextField.text,
                                        success: {
                                            self.ccsmValidationSucceeded()
            },
                                        failure: { error in
                                            DDLogInfo("SMS Validation failed with error: \(String(describing: error?.localizedDescription))")
                                            self.stopSpinner()
                                            self.ccsmValidationFailed()
            })
        }
        
    }
    
    @IBAction func onResendCodeButtonTap(sender: Any) {
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
                                                        self.startSpinner()
                                                        CCSMCommManager.verifyLogin(self.validationCodeTextField.text,
                                                                                    success: {
                                                                                        self.ccsmValidationSucceeded()
                                                        },
                                                                                    failure: { error in
                                                                                        DDLogInfo("SMS Validation failed with error: \(String(describing: error?.localizedDescription))")
                                                                                        self.stopSpinner()
                                                                                        self.ccsmValidationFailed()
                                                                                        
                                                        })
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
    private func hideKeyboard() {
        self.validationCodeTextField.resignFirstResponder()
    }
    
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
