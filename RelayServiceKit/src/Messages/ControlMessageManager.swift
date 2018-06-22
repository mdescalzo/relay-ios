//
//  ControlMessageManager.swift
//  Forsta
//
//  Created by Mark Descalzo on 6/22/18.
//  Copyright © 2018 Forsta. All rights reserved.
//

import Foundation

class ControlMessageManager
{
    static func processControlMessage(message: FLControlMessage)
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
    
    static private func handleThreadUpdate(message: FLControlMessage)
    {
        
    }
    static private func handleThreadClear(message: FLControlMessage)
    {
        
    }

    static private func handleThreadClose(message: FLControlMessage)
    {
        
    }

    static private func handleThreadArchive(message: FLControlMessage)
    {
        
    }

    static private func handleThreadRestore(message: FLControlMessage)
    {
        
    }

    static private func handleThreadDelete(message: FLControlMessage)
    {
        
    }

    static private func handleThreadSnooze(message: FLControlMessage)
    {
        
    }

    static private func handleProvisionRequest(message: FLControlMessage)
    {
        
    }

    static private func handleMessageSyncRequest(message: FLControlMessage)
    {
        
    }
}
