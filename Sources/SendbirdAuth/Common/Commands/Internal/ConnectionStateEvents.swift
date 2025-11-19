//
//  ConnectionStateEvents.swift
//  SendbirdChat
//
//  Created by Minhyuk Kim on 2022/01/14.
//

import Foundation

package protocol ConnectionStateEventable: InternalEvent {}

package struct ConnectionStateEvent {
    package init() { }
    
    package struct Connected: ConnectionStateEventable {
        package let loginEvent: LoginEvent
        package let isReconnected: Bool
        
        package init(loginEvent: LoginEvent, isReconnected: Bool) {
            self.loginEvent = loginEvent
            self.isReconnected = isReconnected
        }
    }
    
    package struct InternalDisconnected: ConnectionStateEventable {
        package let error: AuthError?
        
        package init(error: AuthError?) {
            self.error = error
        }
    }
    
    package struct ReconnectionFailed: ConnectionStateEventable {
        package let error: AuthError?
        
        package init(error: AuthError?) {
            self.error = error
        }
    }
    
    package struct ReconnectingStarted: ConnectionStateEventable {
        package let userId: String
        package let sessionKey: String?
        package let retryCount: Int
        
        package init(userId: String, sessionKey: String?, retryCount: Int) {
            self.userId = userId
            self.sessionKey = sessionKey
            self.retryCount = retryCount
        }
    }
    
    package struct ReconnectionCanceled: ConnectionStateEventable {
        package init() {}
    }
    
    package struct Logout: ConnectionStateEventable {
        package let userId: String
        package let error: AuthError?
        
        package init(userId: String, error: AuthError?) {
            self.userId = userId
            self.error = error
        }
    }
    
    package struct ExternalDisconnected: ConnectionStateEventable {
        package init() {}
    }
    
    package struct Connecting: ConnectionStateEventable {
        package let userId: String
        package let accessToken: String?
        package let sessionKey: String?
        
        package init(userId: String, accessToken: String?, sessionKey: String?) {
            self.userId = userId
            self.accessToken = accessToken
            self.sessionKey = sessionKey
        }
    }
    
    package struct Reconnecting: ConnectionStateEventable {
        package let userId: String
        package let sessionKey: String
        
        package init(userId: String, sessionKey: String) {
            self.userId = userId
            self.sessionKey = sessionKey
        }
    }
    
    package struct SessionRefreshed: ConnectionStateEventable {
        package init() {}
    }
    
    package struct ConnectionDelayed: ConnectionStateEventable {
        package let retryAfter: UInt  // seconds
    }
}

package protocol ApplicationStateEventable: InternalEvent {}

package struct ApplicationStateEvent {
    package init() {}

    package struct Terminate: ApplicationStateEventable {
        package init() {}
    }
}

package protocol AuthenticationStateEventable: InternalEvent {}

package struct AuthenticationStateEvent {
    package init() {}
    
    package struct Refresh: AuthenticationStateEventable {
        package init() {}
    }
}

package protocol SessionExpirationEventable: InternalEvent {}

package struct SessionExpirationEvent {
    package init() {}
    
    package struct Refreshed: SessionExpirationEventable {
        package init() {}
    }
    package struct RefreshFailed: SessionExpirationEventable {
        package init() {}
    }
}
