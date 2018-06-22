//
//  OutgoingControlMessage.swift
//  Forsta
//
//  Created by Mark Descalzo on 6/22/18.
//  Copyright © 2018 Forsta. All rights reserved.
//

import UIKit

class OutgoingControlMessage: TSOutgoingMessage {
    
    let controlMessageType: String

    @objc required init(thread: TSThread, controlType: String) {

        self.controlMessageType = controlType

        super.init(timestamp: NSDate.ows_millisecondTimeStamp(), in: thread, messageBody: nil, attachmentIds: [], expiresInSeconds: 0, expireStartedAt: 0)
        
        self.messageType = "control"
        self.body = FLCCSMJSONService.blob(from: self)
    }
    
    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    required init(dictionary dictionaryValue: [AnyHashable : Any]!) throws {
        fatalError("init(dictionary:) has not been implemented")
    }
    
    override var plainTextBody: String?
    {
        get { return nil }
        set { }
    }

    override var attributedTextBody: NSAttributedString?
    {
        get { return nil }
        set { }
    }

    override func save() {
        return      // never save control messages
    }

    override func save(with transaction: YapDatabaseReadWriteTransaction!) {
        return      // never save control messages
    }
}
