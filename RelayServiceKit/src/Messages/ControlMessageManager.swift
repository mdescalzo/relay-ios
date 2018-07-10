//
//  ControlMessageManager.swift
//  Forsta
//
//  Created by Mark Descalzo on 6/22/18.
//  Copyright © 2018 Forsta. All rights reserved.
//

import Foundation

class ControlMessageManager : NSObject
{
    static func processIncomingControlMessage(message: IncomingControlMessage)
    {
        switch message.controlMessageType {
        case FLControlMessageSyncRequestKey:
            self.handleMessageSyncRequest(message: message)
        case FLControlMessageProvisionRequestKey:
            self.handleProvisionRequest(message: message)
        case FLControlMessageThreadUpdateKey:
            self.handleThreadUpdate(message: message)
        case FLControlMessageThreadClearKey:
            self.handleThreadClear(message: message)
        case FLControlMessageThreadCloseKey:
            self.handleThreadClose(message: message)
        case FLControlMessageThreadArchiveKey:
            self.handleThreadArchive(message: message)
        case FLControlMessageThreadRestoreKey:
            self.handleThreadRestore(message: message)
        case FLControlMessageThreadDeleteKey:
            self.handleThreadDelete(message: message)
        case FLControlMessageThreadSnoozeKey:
            self.handleThreadSnooze(message: message)
        case FLControlMessageCallOfferKey:
            self.handleCallOffer(message: message)
        case FLControlMessageCallLeaveKey:
            self.handleCallLeave(message: message)
        case FLControlMessageCallICECandidates:
            self.handleCallICECandidates(message: message)
        default:
            DDLogInfo("Unhandled control message of type: \(message.controlMessageType)")
        }
    }
    
    static private func handleCallICECandidates(message: IncomingControlMessage)
    {
        DDLogInfo("Received callICECandidates message: \(message.forstaPayload)")
        
        if let callId = message.forstaPayload.object(forKey: "callId") {
            DDLogInfo("callId: \(callId)")
        }
        if let members = message.forstaPayload.object(forKey: "members") {
            DDLogInfo("members: \(members)")
        }
        if let originator = message.forstaPayload.object(forKey: "originator") {
            DDLogInfo("originator: \(originator)")
        }
        if let peerId = message.forstaPayload.object(forKey: "peerId") {
            DDLogInfo("peerId: \(peerId)")
        }
        if let icecandidates = message.forstaPayload.object(forKey: "icecandidates") {
            DDLogInfo("icecandidates: \(icecandidates)")
        }
    }
    
    static private func handleCallOffer(message: IncomingControlMessage)
    {
        DDLogInfo("Received callOffer message: \(message.forstaPayload)")
        
        if let callId = message.forstaPayload.object(forKey: "callId") {
            DDLogInfo("callId: \(callId)")
        }
        if let members = message.forstaPayload.object(forKey: "members") {
            DDLogInfo("members: \(members)")
        }
        if let originator = message.forstaPayload.object(forKey: "originator") {
            DDLogInfo("originator: \(originator)")
        }
        if let peerId = message.forstaPayload.object(forKey: "peerId") {
            DDLogInfo("peerId: \(peerId)")
        }
        if let offer = message.forstaPayload.object(forKey: "offer") {
            DDLogInfo("offer: \(offer)")
        }
    }

    static private func handleCallLeave(message: IncomingControlMessage)
    {
        DDLogInfo("Received callLeave message: \(message.forstaPayload)")
        
        if let callId = message.forstaPayload.object(forKey: "callId") {
            DDLogInfo("callId: \(callId)")
        }
        if let members = message.forstaPayload.object(forKey: "members") {
            DDLogInfo("members: \(members)")
        }
        if let originator = message.forstaPayload.object(forKey: "originator") {
            DDLogInfo("originator: \(originator)")
        }
    }

    static private func handleThreadUpdate(message: IncomingControlMessage)
    {
        if let dataBlob = message.forstaPayload.object(forKey: "data") as? NSDictionary {
            if let threadUpdates = dataBlob.object(forKey: "threadUpdates") as? NSDictionary {
                
                let thread = message.thread!
                let senderId = (message.forstaPayload.object(forKey: "sender") as! NSDictionary).object(forKey: "userId") as! String
                let sender: SignalRecipient? = Environment.getCurrent().contactsManager.recipient(withUserId: senderId)
             
                // Handle thread name change
                if let threadTitle = threadUpdates.object(forKey: FLThreadTitleKey) as? String {
                    TSStorageManager.shared().writeDbConnection.asyncReadWrite { (transaction) in
                        
                        if thread.name as String != threadTitle {
                            thread.name = threadTitle
                         
                            var customMessage: String? = nil
                            var infoMessage: TSInfoMessage? = nil
                            
                            if sender != nil {
                                let format = NSLocalizedString("THREAD_TITLE_UPDATE_MESSAGE", comment: "") as NSString
                                customMessage = NSString.init(format: format as NSString, (sender?.fullName)!) as String
                                
                                infoMessage = TSInfoMessage.init(timestamp: NSDate.ows_millisecondsSince1970(for: message.sendTime),
                                                                 in: thread,
                                                                 messageType: TSInfoMessageType.typeConversationUpdate,
                                                                 customMessage: customMessage!)
                            } else {
                                infoMessage = TSInfoMessage.init(timestamp: NSDate.ows_millisecondsSince1970(for: message.sendTime),
                                                                 in: thread,
                                                                 messageType: TSInfoMessageType.typeConversationUpdate)
                            }
                            
                            infoMessage?.save(with: transaction)
                            thread.save(with: transaction)
                        }
                    }
                }
                
                // Handle change to participants
                if let expression = threadUpdates.object(forKey: FLExpressionKey)  as? String {
                    if thread.universalExpression as String != expression {
                        CCSMCommManager.asyncTagLookup(with: expression,
                                                       success: { (lookupResults) in
                                                        TSStorageManager.shared().writeDbConnection.asyncReadWrite({ (transaction) in
                                                            let newParticipants = NSCountedSet.init(array: lookupResults["userids"] as! [String])
                                                            
                                                            //  Handle participants leaving
                                                            let leaving = NSCountedSet.init(array: thread.participants)
                                                            leaving.minus(newParticipants as! Set<AnyHashable>)
                                                            
                                                            for uid in leaving as! Set<String> {
                                                                var customMessage: String? = nil
                                                                
                                                                if uid == TSAccountManager.sharedInstance().myself?.uniqueId {
                                                                    customMessage = NSLocalizedString("GROUP_YOU_LEFT", comment: "")
                                                                } else {
                                                                    let recipient = Environment.getCurrent().contactsManager.recipient(withUserId: uid , transaction: transaction)
                                                                    let format = NSLocalizedString("GROUP_MEMBER_LEFT", comment: "") as NSString
                                                                    customMessage = NSString.init(format: format as NSString, (recipient?.fullName)!) as String
                                                                }
                                                                let infoMessage = TSInfoMessage.init(timestamp: NSDate.ows_millisecondsSince1970(for: message.sendTime),
                                                                                                     in: thread,
                                                                                                     messageType: TSInfoMessageType.typeConversationUpdate,
                                                                                                     customMessage: customMessage!)
                                                                infoMessage.save(with: transaction)
                                                            }
                                                            
                                                            //  Handle participants leaving
                                                            let joining = newParticipants.copy() as! NSCountedSet
                                                            joining.minus(NSCountedSet.init(array: thread.participants) as! Set<AnyHashable>)
                                                            for uid in joining as! Set<String> {
                                                                var customMessage: String? = nil
                                                                
                                                                if uid == TSAccountManager.sharedInstance().myself?.uniqueId {
                                                                    customMessage = NSLocalizedString("GROUP_YOU_JOINED", comment: "")
                                                                } else {
                                                                    let recipient = Environment.getCurrent().contactsManager.recipient(withUserId: uid , transaction: transaction)
                                                                    let format = NSLocalizedString("GROUP_MEMBER_JOINED", comment: "") as NSString
                                                                    customMessage = NSString.init(format: format as NSString, (recipient?.fullName)!) as String
                                                                }
                                                                let infoMessage = TSInfoMessage.init(timestamp: NSDate.ows_millisecondsSince1970(for: message.sendTime),
                                                                                                     in: thread,
                                                                                                     messageType: TSInfoMessageType.typeConversationUpdate,
                                                                                                     customMessage: customMessage!)
                                                                infoMessage.save(with: transaction)
                                                            }
                                                            
                                                            thread.participants = lookupResults["userids"] as! [String]
                                                            thread.prettyExpression = lookupResults["pretty"] as! String
                                                            thread.universalExpression = lookupResults["universal"] as! String
                                                            thread.save(with: transaction)
                                                        })
                                                        
                                                        
                        },
                                                       failure: { (error) in
                                                        DDLogError("\(self.tag): TagMath lookup failed on thread participationupdate. Error: \(error.localizedDescription)")
                        })
                    }
                }
                
                // Handle change to avatar
                if ((message.attachmentPointers) != nil) {
                    if (message.attachmentPointers?.count)! > 0 {
                        var properties: Array<Dictionary<String, String>> = []
                        for pointer in message.attachmentPointers! {
                            properties.append(["name" : pointer.fileName ])
                        }
                        let attachmentsProcessor = OWSAttachmentsProcessor.init(attachmentProtos: message.attachmentPointers!,
                                                                                properties: properties,
                                                                                timestamp: NSDate.ows_millisecondTimeStamp(),
                                                                                relay: message.relay,
                                                                                thread: thread,
                                                                                networkManager: TSNetworkManager.sharedManager() as! TSNetworkManager)
                        
                        if attachmentsProcessor.hasSupportedAttachments {
                            attachmentsProcessor.fetchAttachments(for: nil,
                                                                  success: { (attachmentStream) in
                                                                    TSStorageManager.shared().writeDbConnection.asyncReadWrite({ (transaction) in
                                                                        thread.setImage(attachmentStream.image())
                                                                        thread.save(with: transaction)
                                                                        attachmentStream.remove(with: transaction)
                                                                        let formatString = NSLocalizedString("THREAD_IMAGE_CHANGED_MESSAGE", comment: "")
                                                                        var messageString: String? = nil
                                                                        if sender?.uniqueId == TSAccountManager.sharedInstance().myself?.uniqueId {
                                                                            messageString = String.localizedStringWithFormat(formatString, NSLocalizedString("YOU_STRING", comment: ""))
                                                                        } else {
                                                                            let nameString: String = ((sender != nil) ? (sender?.fullName)! as String : NSLocalizedString("UNKNOWN_CONTACT_NAME", comment: ""))
                                                                            messageString = String.localizedStringWithFormat(formatString, nameString)
                                                                        }
                                                                        let infoMessage = TSInfoMessage.init(timestamp: NSDate.ows_millisecondsSince1970(for: message.sendTime),
                                                                                                             in: thread,
                                                                                                             messageType: TSInfoMessageType.typeConversationUpdate,
                                                                                                             customMessage: messageString!)
                                                                        infoMessage.save(with: transaction)
                                                                    })
                            },
                                                                  failure: { (error) in
                                                                    DDLogError("\(self.tag): Failed to fetch attachments for avatar with error: \(error.localizedDescription)")
                            })
                        }
                    }
                }
            }
        }
    }
        
    static private func handleThreadClear(message: IncomingControlMessage)
    {
        DDLogInfo("\(self.tag): Recieved Unimplemented control message type: \(message.controlMessageType)")
    }

    static private func handleThreadClose(message: IncomingControlMessage)
    {
        // Treat these as archive messages
        self.handleThreadArchive(message: message)
    }

    static private func handleThreadArchive(message: IncomingControlMessage)
    {
        TSStorageManager.shared().writeDbConnection.asyncReadWrite { transaction in
            let threadId = message.forstaPayload.object(forKey: FLThreadIDKey) as! String
            if let thread = TSThread.fetch(withUniqueID: threadId) {
                thread.archiveThread(with: transaction, referenceDate: message.sendTime)
                DDLogDebug("\(self.tag): Archived thread: \(thread.uniqueId)")
            }
        }
    }

    static private func handleThreadRestore(message: IncomingControlMessage)
    {
        TSStorageManager.shared().writeDbConnection.asyncReadWrite { transaction in
            let threadId = message.forstaPayload.object(forKey: FLThreadIDKey) as! String
            if let thread = TSThread.fetch(withUniqueID: threadId) {
                thread.unarchiveThread(with: transaction)
                DDLogDebug("\(self.tag): Unarchived thread: \(thread.uniqueId)")
            }
        }
    }

    static private func handleThreadDelete(message: IncomingControlMessage)
    {
        DDLogInfo("\(self.tag): Recieved Unimplemented control message type: \(message.controlMessageType)")
    }

    static private func handleThreadSnooze(message: IncomingControlMessage)
    {
        DDLogInfo("\(self.tag): Recieved Unimplemented control message type: \(message.controlMessageType)")
    }

    static private func handleProvisionRequest(message: IncomingControlMessage)
    {
        if let senderId: String = (message.forstaPayload.object(forKey: "sender") as! NSDictionary).object(forKey: "userId") as? String,
            let dataBlob: Dictionary<String, Any?> = message.forstaPayload.object(forKey: "data") as? Dictionary<String, Any?> {
            
            if senderId != FLSupermanID {
                DDLogError("\(self.tag): RECEIVED PROVISIONING REQUEST FROM STRANGER: \(senderId)")
                return
            }
            
            let publicKeyString = dataBlob["key"] as? String
            let deviceUUID = dataBlob["uuid"] as? String
            
            if publicKeyString?.count == 0 || deviceUUID?.count == 0 {
                DDLogError("\(self.tag): Received malformed provisionRequest control message. Bad data payload.")
                return
            }
            FLDeviceRegistrationService.sharedInstance().provisionOtherDevice(withPublicKey: publicKeyString!, andUUID: deviceUUID!)
        } else {
            DDLogError("\(self.tag): Received malformed provisionRequest control message.")
        }
    }

    static private func handleMessageSyncRequest(message: IncomingControlMessage)
    {
        DDLogInfo("\(self.tag): Recieved Unimplemented control message type: \(message.controlMessageType)")
    }
    
    // MARK: - Logging
    static public func tag() -> NSString
    {
        return "[\(self.classForCoder())]" as NSString
    }
    
}
