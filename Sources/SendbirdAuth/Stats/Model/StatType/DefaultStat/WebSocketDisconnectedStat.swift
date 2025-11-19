//
//  WebSocketDisconnectedStat.swift
//  SendbirdChat
//
//  Created by Kai Lee on 1/14/25.
//

import Foundation

package typealias WebSocketDisconnectedReason = WebSocketDisconnectedStat.DisconnectedReason
package final class WebSocketDisconnectedStat: DefaultRecordStat {
    package enum CodingKeys: String, CodingKey {
        case success = "success"
        case errorCode = "error_code"
        case errorDescription = "error_description"
    }
    
    package let success: Bool
    package let errorCode: Int
    package let errorDescription: String
    
    package init(
        success: Bool,
        errorCode: Int,
        reason: DisconnectedReason,
        timestamp: Int64 = Date().milliSeconds
    ) {
        self.success = success
        self.errorCode = errorCode
        self.errorDescription = reason.description
        super.init(statType: .webSocketDisconnect, timestamp: timestamp)
    }
    
    package required init(from decoder: Decoder) throws {
        let container = try Self.nestedDecodeContainer(decoder: decoder, keyedBy: CodingKeys.self)
        
        success = try container.decode(Bool.self, forKey: .success)
        errorCode = try container.decode(Int.self, forKey: .errorCode)
        errorDescription = try container.decode(String.self, forKey: .errorDescription)
        
        try super.init(from: decoder)
    }
    
    package override func encode(to encoder: Encoder) throws {
        try super.encode(to: encoder)
        
        var container = nestedEncodeContainer(encoder: encoder, keyedBy: CodingKeys.self)
        
        try container.encode(success, forKey: .success)
        try container.encode(errorCode, forKey: .errorCode)
        try container.encode(errorDescription, forKey: .errorDescription)
    }
    
    package override var description: String {
        """
            WebSocketDisconnectedStat(
                success: \(String(describing: success)),
                errorCode: \(String(describing: errorCode)),
                errorDescription: \(String(describing: errorDescription))
            )
        """
    }
}

package extension WebSocketDisconnectedStat {
    package enum DisconnectedReason: CustomStringConvertible {
        case background
        case sessionExpired
        case networkDisconnected
        case pingPongTimeout
        case explicitDisconnect
        case explicitReconnect
        case explicitDisconnectWebSocket
        case otherReason(closeCode: ChatWebSocketStatusCode)
        
        private var rawValue: String {
            switch self {
            case .background: return "background"
            case .sessionExpired: return "session_expired"
            case .networkDisconnected: return "network_closed"
            case .pingPongTimeout: return "ping_pong_timedout"
            case .explicitDisconnect: return "explicit_disconnect"
            case .explicitReconnect: return "explicit_reconnect"
            case .explicitDisconnectWebSocket: return "explicit_disconnect_websocket"
            case .otherReason: return ""
            }
        }
        
        package var description: String {
            switch self {
            case .otherReason(let closeCode):
                return "cause=\(closeCode.rawValue)"
            default:
                return "cause=\(rawValue)"
            }
        }
    }
}
