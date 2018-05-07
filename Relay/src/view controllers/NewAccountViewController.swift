//
//  NewAccountViewController.swift
//  Forsta
//
//  Created by Mark Descalzo on 5/2/18.
//  Copyright © 2018 Forsta. All rights reserved.
//

import UIKit
import ReCaptcha
import CocoaLumberjack

class NewAccountViewController: UITableViewController, UITextFieldDelegate {

    
    @IBOutlet weak var firstNameTextField: UITextField!
    @IBOutlet weak var lastNameTextField: UITextField!
    @IBOutlet weak var phoneNumberTextField: UITextField!
    @IBOutlet weak var emailTextField: UITextField!
    
    @IBOutlet weak var submitButton: UIButton!
    @IBOutlet weak var spinner: UIActivityIndicatorView!
    
    private var simplePhoneNumber: NSString!

    private lazy var inputFields: Array<UITextField>! = [ self.firstNameTextField,
                                                          self.lastNameTextField,
                                                          self.emailTextField,
                                                          self.phoneNumberTextField ]
    
    private var recaptcha: ReCaptcha!
    
    private let recaptchaWebViewTag = 123
    
    override func viewDidLoad() {
        super.viewDidLoad()

        self.firstNameTextField.placeholder = NSLocalizedString("Enter First Name", comment: "")
        self.lastNameTextField.placeholder = NSLocalizedString("Enter Last Name", comment: "")
        self.phoneNumberTextField.placeholder = NSLocalizedString("Enter Phone Number", comment: "")
        self.emailTextField.placeholder = NSLocalizedString("Enter Email Address", comment: "")
        self.submitButton.setTitle(NSLocalizedString("Submit", comment: ""), for: .normal)
        
        do {
            try self.recaptcha = ReCaptcha(apiKey: self.recaptchaSiteKey(), baseURL: self.recaptchaDomain(), endpoint: ReCaptcha.Endpoint.default)
        } catch ReCaptchaError.apiKeyNotFound {
            DDLogError("Recaptcha apiKeyNotFound")
        } catch ReCaptchaError.baseURLNotFound {
            DDLogError("Recaptcha baseURLNotFound")
        } catch ReCaptchaError.htmlLoadError {
            DDLogError("Recaptcha htmlLoadError")
        } catch {
            DDLogError("Recaptcha unknown")
        }
        self.recaptcha.configureWebView { webView in
            webView.frame = self.view.bounds
            webView.tag = self.recaptchaWebViewTag
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        self.navigationController?.navigationBar.isHidden = false
    }
    
    override func viewDidAppear(_ animated: Bool) {
        self.hideKeyboard()
        
        super.viewDidAppear(animated)
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    // MARK: - Actions
    
    @IBAction func didPressSubmit(_ sender: UIButton) {
        
        DispatchQueue.main.async {
            self.startSpinner()
            
            if (self.firstNameTextField.text?.count == 0) {
                self.presentAlertWithMessage(message: "Please enter your first name")
                self.stopSpinner()
            } else if (self.lastNameTextField.text?.count == 0) {
                self.presentAlertWithMessage(message: "Please enter your last name")
                self.stopSpinner()
            } else if ((self.phoneNumberTextField.text?.count)! < 14) {
                self.presentAlertWithMessage(message: "Please enter your phone number")
                self.stopSpinner()
            } else if !(self.validateEmailString(strEmail: self.emailTextField.text!)) {
                self.presentAlertWithMessage(message: "Please enter a valid email address")
                self.stopSpinner()
            } else {
                self.recaptcha.forceVisibleChallenge = true
                self.recaptcha.validate(on: self.view,
                                        completion: { (result: ReCaptchaResult) in
                                            
                                            var resultString: String?
                                            do {
                                                resultString = try result.dematerialize()
                                            } catch {
                                                DDLogDebug("Error retrieving token.")
                                            }
                                            DDLogDebug(resultString!)
                                            
                                            // remove the recaptcha webview
                                            self.view.viewWithTag(self.recaptchaWebViewTag)?.removeFromSuperview()
                })
                //                let payload = [ "first_name" : self.firstNameTextField.text!,
//                    "last_name" : self.lastNameTextField.text!,
//                    "phone" : String(format: "+1%@", self.simplePhoneNumber),
//                    "email" : self.emailTextField.text!]
//
//                CCSMCommManager.requestAccountCreation(withUserDict: payload,
//                                                       success: {
//                                                            self.stopSpinner()
//                                                            self.performSegue(withIdentifier: "validationViewSegue",
//                                                                          sender: self)
//                },
//                                                       failure: { (NSError) in
//                                                            self.stopSpinner()
//                })
            }
        }
    }
    
    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destinationViewController.
        // Pass the selected object to the new view controller.
    }
    */
    
    // MARK: - Helper methods
    private func hideKeyboard() {
        self.firstNameTextField.resignFirstResponder()
        self.lastNameTextField.resignFirstResponder()
        self.phoneNumberTextField.resignFirstResponder()
        self.emailTextField.resignFirstResponder()
    }
    
    private func startSpinner() {
        self.spinner.startAnimating()
        self.submitButton.isEnabled = false
        self.submitButton.alpha = 0.5
    }

    private func stopSpinner() {
        self.spinner.stopAnimating()
        self.submitButton.isEnabled = true
        self.submitButton.alpha = 1.0
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
    
    // Swiped from: https://stackoverflow.com/questions/5428304/email-validation-on-textfield-in-iphone-sdk
    private func validateEmailString(strEmail:String) -> Bool
    {
        let emailRegex = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,4}"
        let emailText = NSPredicate(format:"SELF MATCHES [c]%@",emailRegex)
        return (emailText.evaluate(with: strEmail))
    }
    
    // Retrieve reCaptcha key from plist
    private func recaptchaSiteKey() -> String {
        var forstaDict: NSDictionary?
        if let path = Bundle.main.path(forResource: "Forsta-values", ofType: "plist") {
            forstaDict = NSDictionary(contentsOfFile: path)
        }
        if let dict = forstaDict {
            return dict.object(forKey: "RECAPTCHA_SITE_KEY") as! String
        } else {
            return ""
        }
    }
    
    // Retrieve reCaptcha domain from plist
    private func recaptchaDomain() -> URL {
        var forstaDict: NSDictionary?
        if let path = Bundle.main.path(forResource: "Forsta-values", ofType: "plist") {
            forstaDict = NSDictionary(contentsOfFile: path)
        }
        if let dict = forstaDict {
            return URL(string: dict.object(forKey: "RECAPTHCA_DOMAIN") as! String)!
        } else {
            return URL(string:"")!
        }
    }

    
    // MARK: - UITextfield delegate methods
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        // Gracefully cycle through text entry fields on return tap
        let currentIndex = self.inputFields.index(of: textField)
        let nextIndex = (self.inputFields.count > currentIndex! + 1 ? currentIndex! + 1 : 0)
        self.inputFields[nextIndex].becomeFirstResponder()
        
        return true
    }
    
    // Swiped from: https://stackoverflow.com/questions/1246439/uitextfield-for-phone-number
    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        if (textField == self.phoneNumberTextField) {
            let oldText: NSString = textField.text! as NSString
            let newText: NSString = oldText.replacingCharacters(in: range, with: string) as NSString
            let deleting: Bool = (newText.length) < (oldText.length)
            self.simplePhoneNumber = newText.replacingOccurrences(of: "[^0-9]", with: "", options: .regularExpression, range: NSMakeRange(0, newText.length) ) as NSString

            let digits = self.simplePhoneNumber.length
            
            if digits > 10 {
                self.simplePhoneNumber = self.simplePhoneNumber.substring(to: 10) as NSString
            }
            
            if digits == 0 {
                textField.text = ""
            } else if (digits < 3 || (digits == 3 && deleting)) {
                textField.text = String(format: "(%@", self.simplePhoneNumber)
            } else if (digits < 6 || (digits == 6 && deleting)) {
                textField.text = String(format: "(%@) %@",
                                        (self.simplePhoneNumber.substring(to: 3)),
                                        (self.simplePhoneNumber.substring(from: 3)))
            } else {
                textField.text = String(format: "(%@) %@-%@",
                                        (self.simplePhoneNumber.substring(to: 3)),
                                        self.simplePhoneNumber.substring(with: NSMakeRange(3, 3)),
                                        (self.simplePhoneNumber.substring(from: 6)))
            }
            return false
        }
        return true
    }
}
