//
//  WebSocketStatEvent.swift
//  SendbirdChat
//
//  Created by Kai Lee on 6/16/25.
//

public struct WebSocketStatEvent {
    public struct WebSocketStartEvent: InternalEvent {}
    
    public struct WebSocketOpenedEvent: InternalEvent {
        public let hostURL: String
        public let openedTimestampMs: Int64 // ms
    }
    
    public struct WebSocketFailedEvent: InternalEvent {
        public let hostURL: String
        public let code: Int
        public let reason: String?
    }
    
    public struct WebSocketLoginTimeoutEvent: InternalEvent {
        public let hostURL: String
        public let error: AuthError
        public let retryCount: Int
    }
    
    public struct WebSocketReconnectLoginTimeoutEvent: InternalEvent {
        public let hostURL: String
        public let error: AuthError
        public let retryCount: Int
    }
    
    public struct WebSocketDisconnectEvent: InternalEvent {
        public let error: AuthError?
        public let reason: WebSocketDisconnectedReason
    }
}
