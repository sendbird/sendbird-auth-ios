//
//  ConnectionStateEvents.swift
//  SendbirdChat
//
//  Created by Minhyuk Kim on 2022/01/14.
//

import Foundation

@_spi(SendbirdInternal) public protocol ConnectionStateEventable: InternalEvent {}

@_spi(SendbirdInternal) public struct ConnectionStateEvent {
    @_spi(SendbirdInternal) public init() { }
    
    @_spi(SendbirdInternal) public struct Connected: ConnectionStateEventable {
        @_spi(SendbirdInternal) public let loginEvent: LoginEvent
        @_spi(SendbirdInternal) public let isReconnected: Bool
        
        @_spi(SendbirdInternal) public init(loginEvent: LoginEvent, isReconnected: Bool) {
            self.loginEvent = loginEvent
            self.isReconnected = isReconnected
        }
    }
    
    @_spi(SendbirdInternal) public struct InternalDisconnected: ConnectionStateEventable {
        @_spi(SendbirdInternal) public let error: AuthError?
        
        @_spi(SendbirdInternal) public init(error: AuthError?) {
            self.error = error
        }
    }
    
    @_spi(SendbirdInternal) public struct ReconnectionFailed: ConnectionStateEventable {
        @_spi(SendbirdInternal) public let error: AuthError?
        
        @_spi(SendbirdInternal) public init(error: AuthError?) {
            self.error = error
        }
    }
    
    @_spi(SendbirdInternal) public struct ReconnectingStarted: ConnectionStateEventable {
        @_spi(SendbirdInternal) public let userId: String
        @_spi(SendbirdInternal) public let sessionKey: String?
        @_spi(SendbirdInternal) public let retryCount: Int
        
        @_spi(SendbirdInternal) public init(userId: String, sessionKey: String?, retryCount: Int) {
            self.userId = userId
            self.sessionKey = sessionKey
            self.retryCount = retryCount
        }
    }
    
    @_spi(SendbirdInternal) public struct ReconnectionCanceled: ConnectionStateEventable {
        @_spi(SendbirdInternal) public init() {}
    }
    
    @_spi(SendbirdInternal) public struct Logout: ConnectionStateEventable {
        @_spi(SendbirdInternal) public let userId: String
        @_spi(SendbirdInternal) public let error: AuthError?
        
        @_spi(SendbirdInternal) public init(userId: String, error: AuthError?) {
            self.userId = userId
            self.error = error
        }
    }
    
    @_spi(SendbirdInternal) public struct ExternalDisconnected: ConnectionStateEventable {
        @_spi(SendbirdInternal) public init() {}
    }
    
    @_spi(SendbirdInternal) public struct Connecting: ConnectionStateEventable {
        @_spi(SendbirdInternal) public let userId: String
        @_spi(SendbirdInternal) public let accessToken: String?
        @_spi(SendbirdInternal) public let sessionKey: String?
        
        @_spi(SendbirdInternal) public init(userId: String, accessToken: String?, sessionKey: String?) {
            self.userId = userId
            self.accessToken = accessToken
            self.sessionKey = sessionKey
        }
    }
    
    @_spi(SendbirdInternal) public struct Reconnecting: ConnectionStateEventable {
        @_spi(SendbirdInternal) public let userId: String
        @_spi(SendbirdInternal) public let sessionKey: String
        
        @_spi(SendbirdInternal) public init(userId: String, sessionKey: String) {
            self.userId = userId
            self.sessionKey = sessionKey
        }
    }
    
    @_spi(SendbirdInternal) public struct SessionRefreshed: ConnectionStateEventable {
        @_spi(SendbirdInternal) public init() {}
    }
    
    @_spi(SendbirdInternal) public struct ConnectionDelayed: ConnectionStateEventable {
        @_spi(SendbirdInternal) public let retryAfter: UInt  // seconds
    }
}

@_spi(SendbirdInternal) public protocol ApplicationStateEventable: InternalEvent {}

@_spi(SendbirdInternal) public struct ApplicationStateEvent {
    @_spi(SendbirdInternal) public init() {}

    @_spi(SendbirdInternal) public struct Terminate: ApplicationStateEventable {
        @_spi(SendbirdInternal) public init() {}
    }
}

@_spi(SendbirdInternal) public protocol AuthenticationStateEventable: InternalEvent {}

@_spi(SendbirdInternal) public struct AuthenticationStateEvent {
    @_spi(SendbirdInternal) public init() {}
    
    @_spi(SendbirdInternal) public struct Refresh: AuthenticationStateEventable {
        @_spi(SendbirdInternal) public init() {}
    }
}

@_spi(SendbirdInternal) public protocol SessionExpirationEventable: InternalEvent {}

@_spi(SendbirdInternal) public struct SessionExpirationEvent {
    @_spi(SendbirdInternal) public init() {}
    
    @_spi(SendbirdInternal) public struct Refreshed: SessionExpirationEventable {
        @_spi(SendbirdInternal) public init() {}
    }
    @_spi(SendbirdInternal) public struct RefreshFailed: SessionExpirationEventable {
        @_spi(SendbirdInternal) public init() {}
    }
}
