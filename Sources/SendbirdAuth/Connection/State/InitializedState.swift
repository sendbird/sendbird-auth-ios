//
//  InitializedState.swift
//  SendbirdChat
//
//  Created by Minhyuk Kim on 2021/08/25.
//

import Foundation

@_spi(SendbirdInternal) public class InitializedState: ConnectionStatable {
    @_spi(SendbirdInternal) public func process(context: ConnectionContext) { }
    
    @_spi(SendbirdInternal) public init() { }

    @_spi(SendbirdInternal) public func connect(context: ConnectionContext, loginKey: LoginKey, sessionKey: String?, userHandler: AuthUserHandler?) {
        self.connect(context: context, loginKey: loginKey, sessionKey: sessionKey, userHandler: [userHandler])
    }
    
    @_spi(SendbirdInternal) public func connect(context: ConnectionContext, loginKey: LoginKey, sessionKey: String?, userHandler: [AuthUserHandler?]) {
        context.changeState(
            to: ConnectingState(
                loginKey: loginKey,
                sessionKey: sessionKey,
                loginHandlers: userHandler
            )
        )
    }
    
    @_spi(SendbirdInternal) public func disconnect(context: ConnectionContext, completionHandler: VoidHandler?) {
        context.changeState(
            to: LogoutState(
                userId: context.userId,
                disconnectHandler: completionHandler
            )
        )
    }
    
    @_spi(SendbirdInternal) public func disconnectWebSocket(context: ConnectionContext, completionHandler: VoidHandler?) {
        context.serviceForWebSocket? {
            completionHandler?()
        }
    }
    
    @_spi(SendbirdInternal) public func reconnect(context: ConnectionContext, sessionKey: String?, reconnectedBy: ReconnectingTrigger?) -> Bool {
        return false
    }
    
    @_spi(SendbirdInternal) public func didEnterBackground(context: ConnectionContext) {
        
    }
}
