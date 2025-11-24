//
//  ConnectionStateEvents.swift
//  SendbirdChat
//
//  Created by Minhyuk Kim on 2022/01/14.
//

import Foundation

public protocol ConnectionStateEventable: InternalEvent {}

public struct ConnectionStateEvent {
    public init() { }
    
    public struct Connected: ConnectionStateEventable {
        public let loginEvent: LoginEvent
        public let isReconnected: Bool
        
        public init(loginEvent: LoginEvent, isReconnected: Bool) {
            self.loginEvent = loginEvent
            self.isReconnected = isReconnected
        }
    }
    
    public struct InternalDisconnected: ConnectionStateEventable {
        public let error: AuthError?
        
        public init(error: AuthError?) {
            self.error = error
        }
    }
    
    public struct ReconnectionFailed: ConnectionStateEventable {
        public let error: AuthError?
        
        public init(error: AuthError?) {
            self.error = error
        }
    }
    
    public struct ReconnectingStarted: ConnectionStateEventable {
        public let userId: String
        public let sessionKey: String?
        public let retryCount: Int
        
        public init(userId: String, sessionKey: String?, retryCount: Int) {
            self.userId = userId
            self.sessionKey = sessionKey
            self.retryCount = retryCount
        }
    }
    
    public struct ReconnectionCanceled: ConnectionStateEventable {
        public init() {}
    }
    
    public struct Logout: ConnectionStateEventable {
        public let userId: String
        public let error: AuthError?
        
        public init(userId: String, error: AuthError?) {
            self.userId = userId
            self.error = error
        }
    }
    
    public struct ExternalDisconnected: ConnectionStateEventable {
        public init() {}
    }
    
    public struct Connecting: ConnectionStateEventable {
        public let userId: String
        public let accessToken: String?
        public let sessionKey: String?
        
        public init(userId: String, accessToken: String?, sessionKey: String?) {
            self.userId = userId
            self.accessToken = accessToken
            self.sessionKey = sessionKey
        }
    }
    
    public struct Reconnecting: ConnectionStateEventable {
        public let userId: String
        public let sessionKey: String
        
        public init(userId: String, sessionKey: String) {
            self.userId = userId
            self.sessionKey = sessionKey
        }
    }
    
    public struct SessionRefreshed: ConnectionStateEventable {
        public init() {}
    }
    
    public struct ConnectionDelayed: ConnectionStateEventable {
        public let retryAfter: UInt  // seconds
    }
}

public protocol ApplicationStateEventable: InternalEvent {}

public struct ApplicationStateEvent {
    public init() {}

    public struct Terminate: ApplicationStateEventable {
        public init() {}
    }
}

public protocol AuthenticationStateEventable: InternalEvent {}

public struct AuthenticationStateEvent {
    public init() {}
    
    public struct Refresh: AuthenticationStateEventable {
        public init() {}
    }
}

public protocol SessionExpirationEventable: InternalEvent {}

public struct SessionExpirationEvent {
    public init() {}
    
    public struct Refreshed: SessionExpirationEventable {
        public init() {}
    }
    public struct RefreshFailed: SessionExpirationEventable {
        public init() {}
    }
}
