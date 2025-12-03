//
//  WebSocketDisconnectedStat.swift
//  SendbirdChat
//
//  Created by Kai Lee on 1/14/25.
//

import Foundation

@_spi(SendbirdInternal) public typealias WebSocketDisconnectedReason = WebSocketDisconnectedStat.DisconnectedReason
@_spi(SendbirdInternal) public final class WebSocketDisconnectedStat: DefaultRecordStat {
    @_spi(SendbirdInternal) public enum CodingKeys: String, CodingKey {
        case success = "success"
        case errorCode = "error_code"
        case errorDescription = "error_description"
    }
    
    @_spi(SendbirdInternal) public let success: Bool
    @_spi(SendbirdInternal) public let errorCode: Int
    @_spi(SendbirdInternal) public let errorDescription: String
    
    @_spi(SendbirdInternal) public init(
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
    
    @_spi(SendbirdInternal) public required init(from decoder: Decoder) throws {
        let container = try Self.nestedDecodeContainer(decoder: decoder, keyedBy: CodingKeys.self)
        
        success = try container.decode(Bool.self, forKey: .success)
        errorCode = try container.decode(Int.self, forKey: .errorCode)
        errorDescription = try container.decode(String.self, forKey: .errorDescription)
        
        try super.init(from: decoder)
    }
    
    @_spi(SendbirdInternal) public override func encode(to encoder: Encoder) throws {
        try super.encode(to: encoder)
        
        var container = nestedEncodeContainer(encoder: encoder, keyedBy: CodingKeys.self)
        
        try container.encode(success, forKey: .success)
        try container.encode(errorCode, forKey: .errorCode)
        try container.encode(errorDescription, forKey: .errorDescription)
    }
    
    @_spi(SendbirdInternal) public override var description: String {
        """
            WebSocketDisconnectedStat(
                success: \(String(describing: success)),
                errorCode: \(String(describing: errorCode)),
                errorDescription: \(String(describing: errorDescription))
            )
        """
    }
}

@_spi(SendbirdInternal) public extension WebSocketDisconnectedStat {
    @_spi(SendbirdInternal) public enum DisconnectedReason: CustomStringConvertible {
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
        
        @_spi(SendbirdInternal) public var description: String {
            switch self {
            case .otherReason(let closeCode):
                return "cause=\(closeCode.rawValue)"
            default:
                return "cause=\(rawValue)"
            }
        }
    }
}
