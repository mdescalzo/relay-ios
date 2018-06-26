//
//  IncomingControlMessage.swift
//  Forsta
//
//  Created by Mark Descalzo on 6/22/18.
//  Copyright © 2018 Forsta. All rights reserved.
//

import UIKit

@objc public class IncomingControlMessage: TSIncomingMessage {

    let controlMessageType: String
    let attachmentPointers: Array<OWSSignalServiceProtosAttachmentPointer>?

    @objc required public init?(thread: TSThread, author: String, payload: NSDictionary, attachments: Array<OWSSignalServiceProtosAttachmentPointer>?) {
        
        let messageType = payload.object(forKey: "messageType") as! String
        
        if (messageType.count == 0) {
            DDLogError("Attempted to create control message with invalid payload.");
            return nil
        }

        let dataBlob = payload.object(forKey: "data") as! NSDictionary
        if dataBlob.allKeys.count == 0 {
            DDLogError("Attempted to create control message without data object.")
            return nil
        }

        let controlType = dataBlob.object(forKey: "control") as! String
        if controlType.count == 0 {
            DDLogError("Attempted to create control message without a type.")
            return nil
        }
        
        attachmentPointers = attachments
        controlMessageType = dataBlob.object(forKey: "control") as! String
        
        super.init(timestamp: NSDate.ows_millisecondTimeStamp(),
                   in: thread,
                   authorId: author, messageBody: nil,
                   attachmentIds: dataBlob.object(forKey: "attachments") as! [String],
                   expiresInSeconds: 0)

        self.messageType = "control"
        self.forstaPayload = payload.copy() as! NSMutableDictionary
    }
    
    @objc required public init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    @objc required public init(dictionary dictionaryValue: [AnyHashable : Any]!) throws {
        fatalError("init(dictionary:) has not been implemented")
    }
}
