//
//  Copyright (c) 2018 Open Whisper Systems. All rights reserved.
//

import Foundation

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

// All Observer methods will be invoked from the main thread.
protocol CallObserver: class {
    func stateDidChange(call: RelayCall, state: CallState)
    func hasLocalVideoDidChange(call: RelayCall, hasLocalVideo: Bool)
    func muteDidChange(call: RelayCall, isMuted: Bool)
    func holdDidChange(call: RelayCall, isOnHold: Bool)
    func audioSourceDidChange(call: RelayCall, audioSource: AudioSource?)
}

/**
 * Data model for a WebRTC backed voice/video call.
 *
 * This class' state should only be accessed on the main queue.
 */
@objc public class RelayCall: NSObject {

    let TAG = "[RelayCall]"

    var observers = [Weak<CallObserver>]()

    @objc
    let remoteId: String

    var isTerminated: Bool {
        switch state {
        case .localFailure, .localHangup, .remoteHangup, .remoteBusy:
            return true
        case .idle, .dialing, .answering, .remoteRinging, .localRinging, .connected, .reconnecting:
            return false
        }
    }

    let direction: CallDirection

    // Distinguishes between calls locally, e.g. in CallKit
    @objc
    let callUUID: UUID

    // TODO: Implement thread assiciation
    var thread: TSThread?

    var callRecord: TSCall? {
        didSet {
            SwiftAssertIsOnMainThread(#function)
            assert(oldValue == nil)

            updateCallRecordType()
        }
    }

    var hasLocalVideo = false {
        didSet {
            SwiftAssertIsOnMainThread(#function)

            for observer in observers {
                observer.value?.hasLocalVideoDidChange(call: self, hasLocalVideo: hasLocalVideo)
            }
        }
    }

    var state: CallState {
        didSet {
            SwiftAssertIsOnMainThread(#function)
            Logger.debug("\(TAG) state changed: \(oldValue) -> \(self.state) for call: \(self.identifiersForLogs)")

            // Update connectedDate
            if case .connected = self.state {
                // if it's the first time we've connected (not a reconnect)
                if connectedDate == nil {
                    connectedDate = NSDate()
                }
            }

            updateCallRecordType()

            for observer in observers {
                observer.value?.stateDidChange(call: self, state: state)
            }
        }
    }

    var isMuted = false {
        didSet {
            SwiftAssertIsOnMainThread(#function)

            Logger.debug("\(TAG) muted changed: \(oldValue) -> \(self.isMuted)")

            for observer in observers {
                observer.value?.muteDidChange(call: self, isMuted: isMuted)
            }
        }
    }

    let audioActivity: AudioActivity

    var audioSource: AudioSource? = nil {
        didSet {
            SwiftAssertIsOnMainThread(#function)
            Logger.debug("\(TAG) audioSource changed: \(String(describing: oldValue)) -> \(String(describing: audioSource))")

            for observer in observers {
                observer.value?.audioSourceDidChange(call: self, audioSource: audioSource)
            }
        }
    }

    var isSpeakerphoneEnabled: Bool {
        guard let audioSource = self.audioSource else {
            return false
        }

        return audioSource.isBuiltInSpeaker
    }

    var isOnHold = false {
        didSet {
            SwiftAssertIsOnMainThread(#function)
            Logger.debug("\(TAG) isOnHold changed: \(oldValue) -> \(self.isOnHold)")

            for observer in observers {
                observer.value?.holdDidChange(call: self, isOnHold: isOnHold)
            }
        }
    }

    var connectedDate: NSDate?

    var error: CallError?

    // MARK: Initializers and Factory Methods

    init(direction: CallDirection, callUUID: UUID, state: CallState, remoteId: String) {
        self.direction = direction
        self.callUUID = callUUID
        self.state = state
        self.remoteId = remoteId
        // TODO: Thread association
//        self.thread = TSThread.getOrCreateThread(contactId: remoteId)
        self.audioActivity = AudioActivity(audioDescription: "[RelayCall] with \(remoteId)")
    }

    // A string containing the three identifiers for this call.
    var identifiersForLogs: String {
        return "{\(remoteId), \(callUUID)}"
    }

    class func outgoingCall(idString: String, remoteId: String) -> RelayCall {
        return RelayCall(direction: .outgoing, callUUID: UUID.init(uuidString: idString)!, state: .dialing, remoteId: remoteId)
    }

    class func incomingCall(idString: String, remoteId: String) -> RelayCall {
        return RelayCall(direction: .incoming, callUUID: UUID.init(uuidString: idString)!, state: .answering, remoteId: remoteId)
    }

    // -

    func addObserverAndSyncState(observer: CallObserver) {
        SwiftAssertIsOnMainThread(#function)

        observers.append(Weak(value: observer))

        // Synchronize observer with current call state
        observer.stateDidChange(call: self, state: state)
    }

    func removeObserver(_ observer: CallObserver) {
        SwiftAssertIsOnMainThread(#function)

        while let index = observers.index(where: { $0.value === observer }) {
            observers.remove(at: index)
        }
    }

    func removeAllObservers() {
        SwiftAssertIsOnMainThread(#function)

        observers = []
    }

    private func updateCallRecordType() {
        SwiftAssertIsOnMainThread(#function)

        guard let callRecord = self.callRecord else {
            return
        }

        // Mark incomplete calls as completed if call has connected.
        if state == .connected &&
            callRecord.callType == RPRecentCallTypeOutgoingIncomplete {
            callRecord.updateCallType(RPRecentCallTypeOutgoing)
        }
        if state == .connected &&
            callRecord.callType == RPRecentCallTypeIncomingIncomplete {
            callRecord.updateCallType(RPRecentCallTypeIncoming)
        }
    }

    // MARK: Equatable

    static func == (lhs: RelayCall, rhs: RelayCall) -> Bool {
        return lhs.callUUID == rhs.callUUID
    }

    static func newCallSignalingId() -> UInt64 {
        return UInt64.ows_random()
    }

    // This method should only be called when the call state is "connected".
    func connectionDuration() -> TimeInterval {
        return -connectedDate!.timeIntervalSinceNow
    }
}

fileprivate extension UInt64 {
    static func ows_random() -> UInt64 {
        var random: UInt64 = 0
        arc4random_buf(&random, MemoryLayout.size(ofValue: random))
        return random
    }
}
