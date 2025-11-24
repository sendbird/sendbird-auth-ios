//
//  BusyEvent.swift
//  SendbirdAuth
//
//  Created by Celine Moon on 9/2/25.
//

import Foundation

/// The `BUSY` command payload.
/// The `BUSY` command is received when:
/// - When server is overloaded, instead of `LOGI`, we receive `BUSY`
/// - Or while already having been connected, the server becomes overloaded.
/// - Since : 4.34.0
public struct BusyEvent: Decodable, SBCommand {
    public let cmd: CommandType = .busy
    
    public let retryAfter: UInt  // unit: seconds
    public let reasonCode: Int  // 4xxxxx
    public let message: String  // "server is overloaded"
    
    public init(retryAfter: UInt, reasonCode: Int, message: String) {
        self.retryAfter = retryAfter
        self.reasonCode = reasonCode
        self.message = message
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodeCodingKeys.self)
        self.retryAfter = try container.decode(UInt.self, forKey: .retryAfter)
        self.reasonCode = try container.decode(Int.self, forKey: .reasonCode)
        self.message = (try? container.decodeIfPresent(String.self, forKey: .message)) ?? ""
    }
    
    public func updateRetryAfter(_ newRetryAfter: UInt) -> BusyEvent {
        return BusyEvent(
            retryAfter: newRetryAfter,
            reasonCode: self.reasonCode,
            message: self.message
        )
    }
}

/// Wrapper struct of BusyEvent.
/// Used to pass busyEvent related data to InternalDisconnectedState.
/// - Since : 4.34.0
public struct BusyEventWrapper {
    public let busyEvent: BusyEvent
    public let timerStartTime: TimeInterval
}
