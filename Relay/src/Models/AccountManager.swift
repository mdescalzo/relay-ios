//  Created by Michael Kirk on 10/25/16.
//  Copyright © 2016 Open Whisper Systems. All rights reserved.

import Foundation
import PromiseKit

@objc(OWSAccountManager)
class AccountManager : NSObject {
    let TAG = "[AccountManager]"
    let textSecureAccountManager: TSAccountManager

    required init(textSecureAccountManager:TSAccountManager) {
        self.textSecureAccountManager = textSecureAccountManager
    }

    @objc func register(verificationCode: String) -> AnyPromise {
        return AnyPromise(register(verificationCode: verificationCode));
    }

    func register(verificationCode: String) -> Promise<Void> {
        return firstly {
            Promise { fulfill, reject in
                if verificationCode.count == 0 {
                    let error = OWSErrorWithCodeDescription(.userError,
                                                            NSLocalizedString("REGISTRATION_ERROR_BLANK_VERIFICATION_CODE",
                                                                              comment: "alert body during registration"))
                    reject(error)
                }
                fulfill()
            }
        }.then {
            Logger.debug("\(self.TAG) verification code looks well formed.");
            return self.registerForTextSecure(verificationCode: verificationCode)
        }.then {
            Logger.debug("\(self.TAG) successfully registered for TextSecure")
        }
    }

    func updatePushTokens(pushToken: String, voipToken: String) -> Promise<Void> {
        return firstly {
            return self.updateTextSecurePushTokens(pushToken: pushToken, voipToken: voipToken)
        }.then {
            Logger.info("\(self.TAG) Successfully updated text secure push tokens.")
            return Promise { fulfill, reject in
                fulfill();
            }
        }
    }

    private func updateTextSecurePushTokens(pushToken: String, voipToken: String) -> Promise<Void> {
        return Promise { fulfill, reject in
            self.textSecureAccountManager.registerForPushNotifications(pushToken:pushToken,
                                                                       voipToken:voipToken,
                                                                       success:fulfill,
                                                                       failure:reject)
        }
    }

    private func registerForTextSecure(verificationCode: String) -> Promise<Void> {
        return Promise { fulfill, reject in
            self.textSecureAccountManager.verifyAccount(withCode:verificationCode,
                                                        success:fulfill,
                                                        failure:reject)
        }
    }

    private func fetchRedPhoneToken() -> Promise<String> {
        return Promise { fulfill, reject in
            self.textSecureAccountManager.obtainRPRegistrationToken(success:fulfill,
                                                                    failure:reject)

        }
    }
}
