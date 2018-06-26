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
    static let dbConnection = TSStorageManager.shared().newDatabaseConnection()
    
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
        default:
            DDLogInfo("Unhandled control message of type: \(message.controlMessageType)")
        }
    }
    
    static private func handleThreadUpdate(message: IncomingControlMessage)
    {
        if let dataBlob = message.forstaPayload.object(forKey: "data") as? NSDictionary {
            if let threadUpdates = dataBlob.object(forKey: "threadUpdates") as? NSDictionary {
                var threadId: String = (threadUpdates.object(forKey: FLThreadIDKey) as? String)!
                if threadId.count == 0 {
                    threadId = message.forstaPayload.object(forKey: FLThreadIDKey) as! String
                }
                
                let thread = TSThread.getOrCreateThread(withID: threadId)
                let senderId = (message.forstaPayload.object(forKey: "sender") as! NSDictionary).object(forKey: "userId") as! String
                let sender: SignalRecipient? = Environment.getCurrent().contactsManager.recipient(withUserId: senderId)!
             
                // Handle thread name change
                if let threadTitle = threadUpdates.object(forKey: FLThreadTitleKey) as? String {
                    self.dbConnection.asyncReadWrite { (transaction) in
                        
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
                    self.dbConnection.asyncReadWrite { (transaction) in
                        
                        if thread.universalExpression as String != expression {
                            CCSMCommManager.asyncTagLookup(with: expression,
                                                           success: { (lookupResults) in
                                                            self.dbConnection.asyncReadWrite({ (transaction) in
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
                }
                
                // Handle change to avatar
                if message.attachmentIds.count > 0 {}
//                    OWSAttachmentsProcessor *attachmentsProcessor = [[OWSAttachmentsProcessor alloc] initWithAttachmentProtos:dataMessage.attachments
//                        properties:[dataBlob objectForKey:@"attachments"]
//                        timestamp:envelope.timestamp
//                        relay:envelope.relay
//                        thread:thread
//                        networkManager:self.networkManager];
//
//                    if (attachmentsProcessor.hasSupportedAttachments) {
//                        [attachmentsProcessor fetchAttachmentsForMessage:nil
//                            success:^(TSAttachmentStream *_Nonnull attachmentStream) {
//                            [thread updateImageWithAttachmentStream:attachmentStream];
//
//                            NSString *messageFormat = NSLocalizedString(@"THREAD_IMAGE_CHANGED_MESSAGE", nil);
//                            NSString *customMessage = nil;
//                            if ([sender.uniqueId isEqual:TSAccountManager.sharedInstance.myself]) {
//                            customMessage = [NSString stringWithFormat:messageFormat, NSLocalizedString(@"YOU_STRING", nil)];
//                            } else {
//                            customMessage = [NSString stringWithFormat:messageFormat, sender.fullName];
//                            }
//
//                            TSInfoMessage *infoMessage = [[TSInfoMessage alloc] initWithTimestamp:[NSDate ows_millisecondTimeStamp]
//                            inThread:thread
//                            messageType:TSInfoMessageTypeConversationUpdate
//                            customMessage:customMessage];
//                            [infoMessage save];
//                            }
//                            failure:^(NSError *_Nonnull error) {
//                            DDLogError(@"%@ failed to fetch attachments for group avatar sent at: %llu. with error: %@",
//                            self.tag,
//                            envelope.timestamp,
//                            error);
//                            }];
//                    }
//                }
            }
        }
    }
        
    static private func handleThreadClear(message: IncomingControlMessage)
    {
        
    }

    static private func handleThreadClose(message: IncomingControlMessage)
    {
        // Tread these as archive messages
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
        
    }

    static private func handleThreadSnooze(message: IncomingControlMessage)
    {
        
    }

    static private func handleProvisionRequest(message: IncomingControlMessage)
    {
        
    }

    static private func handleMessageSyncRequest(message: IncomingControlMessage)
    {
        
    }
    
    // MARK: - Logging
    static public func tag() -> NSString
    {
        return "[\(self.classForCoder())]" as NSString
    }
    
}
