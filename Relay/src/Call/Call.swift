//
//  Copyright © 2018 Forsta. All rights reserved.
//
//  Based upon SpeakerBox sample provided by Apple
//

import Foundation
import WebRTC

public enum CallState: String {
    case idle
    case dialing
    case answering
    case remoteRinging
    case localRinging
    case connected
    case reconnecting
    case localFailure // terminal
    case localHangup // terminal
    case remoteHangup // terminal
    case remoteBusy // terminal
}

enum CallDirection {
    case outgoing, incoming
}

@objc public class Call : NSObject {
    
    // MARK: Metadata Properties
    
    let uuid: UUID
    let isOutgoing: Bool
    var handle: String?
    var connectedDate: NSDate?
    let direction: CallDirection
    
    // MARK: Call State Properties
    
    var connectingDate: Date? {
        didSet {
            stateDidChange?()
            hasStartedConnectingDidChange?()
        }
    }
    var connectDate: Date? {
        didSet {
            stateDidChange?()
            hasConnectedDidChange?()
        }
    }
    var endDate: Date? {
        didSet {
            stateDidChange?()
            hasEndedDidChange?()
        }
    }
    var isOnHold = false {
        didSet {
            stateDidChange?()
        }
    }
    
    var isTerminated: Bool {
        switch state {
        case .localFailure, .localHangup, .remoteHangup, .remoteBusy:
            return true
        case .idle, .dialing, .answering, .remoteRinging, .localRinging, .connected, .reconnecting:
            return false
        }
    }
    
    var state: CallState {
        didSet {
//            SwiftAssertIsOnMainThread(#function)
//            Logger.debug("\(TAG) state changed: \(oldValue) -> \(self.state) for call: \(self.identifiersForLogs)")
            
            // Update connectedDate
            if case .connected = self.state {
                // if it's the first time we've connected (not a reconnect)
                if connectedDate == nil {
                    connectedDate = NSDate()
                }
            }
            
//            updateCallRecordType()
//            
//            for observer in observers {
//                observer.value?.stateDidChange(call: self, state: state)
//            }
        }
    }
    
    // MARK: State change callback blocks
    
    var stateDidChange: (() -> Void)?
    var hasStartedConnectingDidChange: (() -> Void)?
    var hasConnectedDidChange: (() -> Void)?
    var hasEndedDidChange: (() -> Void)?
    
    // MARK: Derived Properties
    
    var hasStartedConnecting: Bool {
        get {
            return connectingDate != nil
        }
        set {
            connectingDate = newValue ? Date() : nil
        }
    }
    var hasConnected: Bool {
        get {
            return connectDate != nil
        }
        set {
            connectDate = newValue ? Date() : nil
        }
    }
    var hasEnded: Bool {
        get {
            return endDate != nil
        }
        set {
            endDate = newValue ? Date() : nil
        }
    }
    var duration: TimeInterval {
        guard let connectDate = connectDate else {
            return 0
        }
        
        return Date().timeIntervalSince(connectDate)
    }
    
    // MARK: Initialization
    
    init(uuid: UUID, isOutgoing: Bool = false) {
        self.uuid = uuid
        self.isOutgoing = isOutgoing
    }
    
    // MARK: Actions
    
    func startCall(completion: ((_ success: Bool) -> Void)?) {
        // Simulate the call starting successfully
        completion?(true)
        
        /*
         Simulate the "started connecting" and "connected" states using artificial delays, since
         the example app is not backed by a real network service
         */
        DispatchQueue.main.asyncAfter(wallDeadline: DispatchWallTime.now() + 3) {
            self.hasStartedConnecting = true
            
            DispatchQueue.main.asyncAfter(wallDeadline: DispatchWallTime.now() + 1.5) {
                self.hasConnected = true
            }
        }
    }
    
    func answerCall() {
        /*
         Simulate the answer becoming connected immediately, since
         the example app is not backed by a real network service
         */
        hasConnected = true
    }
    
    func endCall() {
        /*
         Simulate the end taking effect immediately, since
         the example app is not backed by a real network service
         */
        hasEnded = true
    }
    
}
