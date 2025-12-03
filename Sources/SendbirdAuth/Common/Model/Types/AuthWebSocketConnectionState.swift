//
//  AuthWebSocketConnectionState.swift
//  SendbirdChat
//
//  Created by Kai Lee on 6/16/25.
//

/// Connection state
@_spi(SendbirdInternal) public enum AuthWebSocketConnectionState: String {
    /// Connecting
    case connecting
    /// Open
    case open
    /// Closed
    case closed
}
