//  Created by Michael Kirk on 10/31/16.
//  Copyright © 2016 Open Whisper Systems. All rights reserved.

import Foundation
import PromiseKit

@objc(OWSSessionResetJob)
class SessionResetJob: NSObject {

    let TAG = "SessionResetJob"

    let recipientId: String
    let thread: TSThread
    let storageManager: TSStorageManager
    let messageSender: MessageSender

    required init(recipientId: String, thread: TSThread, messageSender: MessageSender, storageManager: TSStorageManager) {
        self.thread = thread
        self.recipientId = recipientId
        self.messageSender = messageSender
        self.storageManager = storageManager
    }

    func run() {
        Logger.info("\(TAG) Local user reset session.")

        let endSessionMessage = EndSessionMessage(timestamp:NSDate.ows_millisecondTimeStamp(), in: thread)
        self.messageSender.send(endSessionMessage, success: {
            let dbConnection = TSStorageManager.shared().newDatabaseConnection()
            dbConnection?.readWrite { (transaction) in
            Logger.info("\(self.TAG) successfully sent EndSession<essage.")

            Logger.info("\(self.TAG) deleting sessions for recipient: \(self.recipientId)")
                
                // TODO: Integrate session archiving
            self.storageManager.deleteAllSessions(forContact: self.recipientId, protocolContext: transaction)
            }
            
            let message = TSInfoMessage(timestamp: NSDate.ows_millisecondTimeStamp(),
                                        in: self.thread,
                                        messageType: TSInfoMessageType.typeSessionDidEnd)
            message.save()
        }, failure: {error in
            Logger.error("\(self.TAG) failed to send EndSesionMessage with error: \(error.localizedDescription)")
        });
    }

    class func run(corruptedMessage: TSErrorMessage, contactThread: TSThread, messageSender: MessageSender, storageManager: TSStorageManager) {
        let job = self.init(recipientId: contactThread.uniqueId,
                            thread: contactThread,
                            messageSender: messageSender,
                            storageManager: storageManager)
        job.run()
    }

    class func run(recipientId: String, thread: TSThread, messageSender: MessageSender, storageManager: TSStorageManager) {
        let job = self.init(recipientId: recipientId, thread: thread, messageSender: messageSender, storageManager: storageManager)
        job.run()
    }
}
