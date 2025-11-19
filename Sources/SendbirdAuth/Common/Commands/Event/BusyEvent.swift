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
/// - Since : [NEXT_VERSION]
package struct BusyEvent: Decodable, SBCommand {
    package let cmd: CommandType = .busy
    
    package let retryAfter: UInt  // unit: seconds
    package let reasonCode: Int  // 4xxxxx
    package let message: String  // "server is overloaded"
    
    package init(retryAfter: UInt, reasonCode: Int, message: String) {
        self.retryAfter = retryAfter
        self.reasonCode = reasonCode
        self.message = message
    }
    
    package init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodeCodingKeys.self)
        self.retryAfter = try container.decode(UInt.self, forKey: .retryAfter)
        self.reasonCode = try container.decode(Int.self, forKey: .reasonCode)
        self.message = (try? container.decodeIfPresent(String.self, forKey: .message)) ?? ""
    }
    
    package func updateRetryAfter(_ newRetryAfter: UInt) -> BusyEvent {
        return BusyEvent(
            retryAfter: newRetryAfter,
            reasonCode: self.reasonCode,
            message: self.message
        )
    }
}

/// Wrapper struct of BusyEvent.
/// Used to pass busyEvent related data to InternalDisconnectedState.
/// - Since : [NEXT_VERSION]
package struct BusyEventWrapper {
    package let busyEvent: BusyEvent
    package let timerStartTime: TimeInterval
}
