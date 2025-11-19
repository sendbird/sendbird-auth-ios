//
//  SBDSessionDelegate.swift
//  SendbirdChat
//
//  Created by Wooyoung Chung on 7/15/21.
//

import Foundation

// Represents a delegate to receive session relates events
@objc(SBDAuthSessionDelegate)
package protocol AuthSessionDelegate {
    func sessionTokenDidRequire(
        successCompletion success: @escaping (String?) -> Void,
        failCompletion fail: @escaping () -> Void
    )

    func sessionWasClosed()
    
    @available(*, unavailable)
    @objc
    optional func sessionWasExpired()
    
    @objc
    optional func sessionWasRefreshed()

    @objc
    optional func sessionDidHaveError(_ error: NSError)
}
