//
//  ReconnectingTrigger.swift
//  SendbirdChat
//
//  Created by Kai Lee on 6/16/25.
//

package enum ReconnectingTrigger: Int {
    case manual
    case networkReachability
    case enteringForeground
    case watchdog
    case refreshedSessionKey
    case sessionValidation
    case cachedSessionKey
    case webSocketError
    case busyServer
}

/// Extension of ReconnectingTrigger for unit test that
/// improves the readability of the test code.
extension ReconnectingTrigger {
    package static var notManual: ReconnectingTrigger {
        ReconnectingTrigger.enteringForeground
    }
}
