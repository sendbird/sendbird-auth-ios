//
//  WebSocketStatEvent.swift
//  SendbirdChat
//
//  Created by Kai Lee on 6/16/25.
//

package struct WebSocketStatEvent {
    package struct WebSocketStartEvent: InternalEvent {}
    
    package struct WebSocketOpenedEvent: InternalEvent {
        package let hostURL: String
        package let openedTimestampMs: Int64 // ms
    }
    
    package struct WebSocketFailedEvent: InternalEvent {
        package let hostURL: String
        package let code: Int
        package let reason: String?
    }
    
    package struct WebSocketLoginTimeoutEvent: InternalEvent {
        package let hostURL: String
        package let error: AuthError
        package let retryCount: Int
    }
    
    package struct WebSocketReconnectLoginTimeoutEvent: InternalEvent {
        package let hostURL: String
        package let error: AuthError
        package let retryCount: Int
    }
    
    package struct WebSocketDisconnectEvent: InternalEvent {
        package let error: AuthError?
        package let reason: WebSocketDisconnectedReason
    }
}
