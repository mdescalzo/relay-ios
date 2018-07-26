//
//  Copyright © 2018 Forsta. All rights reserved.
//
//  Based upon SpeakerBox sample provided by Apple
//

import UIKit
import CallKit
import WebRTC

@available(iOS 10.0, *)
@objc final class CallKitManager: NSObject {
    
    // MARK: Shared singleton
//    static let shared = CallKitManager()
    
    private let callController = CXCallController()
    
    // MARK: Actions
    
    func startCall(handle: String, video: Bool = false) {
        let handle = CXHandle(type: .generic, value: handle)
        let startCallAction = CXStartCallAction(call: UUID(), handle: handle)
        
        startCallAction.isVideo = video
        
        let transaction = CXTransaction()
        transaction.addAction(startCallAction)
        
        requestTransaction(transaction)
    }
    
    func end(call: CallKitCall) {
        let endCallAction = CXEndCallAction(call: call.uuid)
        let transaction = CXTransaction()
        transaction.addAction(endCallAction)
        
        requestTransaction(transaction)
    }
    
    func setHeld(call: CallKitCall, onHold: Bool) {
        let setHeldCallAction = CXSetHeldCallAction(call: call.uuid, onHold: onHold)
        let transaction = CXTransaction()
        transaction.addAction(setHeldCallAction)
        
        requestTransaction(transaction)
    }
    
    private func requestTransaction(_ transaction: CXTransaction) {
        callController.request(transaction) { error in
            if let error = error {
                print("Error requesting transaction: \(error)")
            } else {
                print("Requested transaction successfully")
            }
        }
    }
    
    // MARK: Call Management
    
//    static let CallsChangedNotification = Notification.Name("CallManagerCallsChangedNotification")
    static let CallStateChangedNotification = Notification.Name("CallManagerCallStateChangedNotification")
    
    private(set) var calls = [CallKitCall]()
    
    func callWithUUID(uuid: UUID) -> CallKitCall? {
        guard let index = calls.index(where: { $0.uuid == uuid }) else {
            return nil
        }
        return calls[index]
    }
    
    func addCall(_ call: CallKitCall) {
        calls.append(call)
        
        call.stateDidChange = { [weak self] in
            self?.postCallStateChangedNotification(call: call)
        }
        
        call.hasEndedDidChange = { [weak self] in
            self?.postCallStateChangedNotification(call: call)
        }

        
    }
    
    func removeCall(_ call: CallKitCall) {
        guard let index = calls.index(where: { $0 === call }) else { return }
        calls.remove(at: index)
    }
    
    func removeAllCalls() {
        calls.removeAll()
    }
 
    
    private func postCallStateChangedNotification(call: CallKitCall) {
        NotificationCenter.default.post(name: type(of: self).CallStateChangedNotification, object: call)
    }

//    private func postCallsChangedNotification() {
//        NotificationCenter.default.post(name: type(of: self).CallsChangedNotification, object: self)
//    }

}
