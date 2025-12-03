//
//  WebSocketStatEvent.swift
//  SendbirdChat
//
//  Created by Kai Lee on 6/16/25.
//

@_spi(SendbirdInternal) public struct WebSocketStatEvent {
    @_spi(SendbirdInternal) public struct WebSocketStartEvent: InternalEvent {}
    
    @_spi(SendbirdInternal) public struct WebSocketOpenedEvent: InternalEvent {
        @_spi(SendbirdInternal) public let hostURL: String
        @_spi(SendbirdInternal) public let openedTimestampMs: Int64 // ms
    }
    
    @_spi(SendbirdInternal) public struct WebSocketFailedEvent: InternalEvent {
        @_spi(SendbirdInternal) public let hostURL: String
        @_spi(SendbirdInternal) public let code: Int
        @_spi(SendbirdInternal) public let reason: String?
    }
    
    @_spi(SendbirdInternal) public struct WebSocketLoginTimeoutEvent: InternalEvent {
        @_spi(SendbirdInternal) public let hostURL: String
        @_spi(SendbirdInternal) public let error: AuthError
        @_spi(SendbirdInternal) public let retryCount: Int
    }
    
    @_spi(SendbirdInternal) public struct WebSocketReconnectLoginTimeoutEvent: InternalEvent {
        @_spi(SendbirdInternal) public let hostURL: String
        @_spi(SendbirdInternal) public let error: AuthError
        @_spi(SendbirdInternal) public let retryCount: Int
    }
    
    @_spi(SendbirdInternal) public struct WebSocketDisconnectEvent: InternalEvent {
        @_spi(SendbirdInternal) public let error: AuthError?
        @_spi(SendbirdInternal) public let reason: WebSocketDisconnectedReason
    }
}
