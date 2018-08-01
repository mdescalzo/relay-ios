//
//  Copyright (c) 2018 Open Whisper Systems. All rights reserved.
//

import Foundation

@objc(OWSWebRTCCallMessageHandler)
public class WebRTCCallMessageHandler: NSObject {
    
    // MARK - Properties
    
    let TAG = "[WebRTCCallMessageHandler]"
    
    // MARK: Dependencies
    
    static let shared = WebRTCCallMessageHandler()
    
    let accountManager = TSAccountManager.sharedInstance()
    let callService = Environment.shared().callService
    let messageSender = Environment.shared().messageSender
    
    // MARK: Initializers
//    @objc public required init() {
//        super.init()
    
    // TODO: Investigate/implement SwiftSingletons?
//        SwiftSingletons.register(self)
//}
    
    // MARK: - Call Handlers
    
//    public func receivedOffer(_ offer: CallOffer) {
//        SwiftAssertIsOnMainThread(#function)
//
//        guard offer.callId.count > 0 else {
//            DDLogDebug("no callId passed to \(#function)")
//            return
//        }
//        // TODO: attach calls to threads/converstations
//        self.callService.processIncomingOffer(callId: offer.callId, sessionDescription: offer.sessionDescription)
//    }
    
    public func receivedAnswer(_ answer: OWSSignalServiceProtosCallMessageAnswer, from callerId: String) {
        SwiftAssertIsOnMainThread(#function)
        guard answer.hasId() else {
            owsFail("no callId in \(#function)")
            return
        }
        
//        let thread = TSThread.getOrCreateThread(contactId: callerId)
        self.callService.handleReceivedAnswer(thread: thread, callId: answer.id, sessionDescription: answer.sessionDescription)
    }
    
    public func receivedIceUpdate(_ iceUpdate: OWSSignalServiceProtosCallMessageIceUpdate, from callerId: String) {
        SwiftAssertIsOnMainThread(#function)
        guard iceUpdate.hasId() else {
            owsFail("no callId in \(#function)")
            return
        }
        
//        let thread = TSThread.getOrCreateThread(contactId: callerId)
        
        // Discrepency between our protobuf's sdpMlineIndex, which is unsigned,
        // while the RTC iOS API requires a signed int.
        let lineIndex = Int32(iceUpdate.sdpMlineIndex)
        
        self.callService.handleRemoteAddedIceCandidate(thread: thread, callId: iceUpdate.id, sdp: iceUpdate.sdp, lineIndex: lineIndex, mid: iceUpdate.sdpMid)
    }
    
    public func receivedHangup(_ hangup: OWSSignalServiceProtosCallMessageHangup, from callerId: String) {
        SwiftAssertIsOnMainThread(#function)
        guard hangup.hasId() else {
            owsFail("no callId in \(#function)")
            return
        }
        
//        let thread = TSThread.getOrCreateThread(contactId: callerId)
        self.callService.handleRemoteHangup(thread: thread, callId: hangup.id)
    }
    
    public func receivedBusy(_ busy: OWSSignalServiceProtosCallMessageBusy, from callerId: String) {
        SwiftAssertIsOnMainThread(#function)
        guard busy.hasId() else {
            owsFail("no callId in \(#function)")
            return
        }
        
//        let thread = TSThread.getOrCreateThread(contactId: callerId)
        self.callService.handleRemoteBusy(thread: thread, callId: busy.id)
    }
    
}

