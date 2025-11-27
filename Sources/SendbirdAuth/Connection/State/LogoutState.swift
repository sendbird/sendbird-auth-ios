//
//  LogoutState.swift
//  SendbirdChat
//
//  Created by Minhyuk Kim on 2022/01/19.
//

import Foundation

@_spi(SendbirdInternal) public class LogoutState: ConnectionStatable {
    @_spi(SendbirdInternal) public let error: AuthError?
    @_spi(SendbirdInternal) public var disconnectHandler: VoidHandler?
    @_spi(SendbirdInternal) public let userId: String

    @_spi(SendbirdInternal) public init(
        error: AuthError? = nil,
        userId: String,
        disconnectHandler: VoidHandler? = nil
    ) {
        self.error = error
        self.userId = userId
        self.disconnectHandler = disconnectHandler
    }

    @_spi(SendbirdInternal) public func process(context: ConnectionContext) {
        Logger.session.info("Clear local data.")
        context.eventDispatcher.dispatch(command: ConnectionStateEvent.Logout(userId: userId, error: error))
        
        context.disconnectSocket()
        context.changeState(to: InitializedState())
        
        context.serviceForWebSocket? {
            self.disconnectHandler?()
            self.disconnectHandler = nil
        }
    }

    @_spi(SendbirdInternal) public func connect(context: ConnectionContext, loginKey: LoginKey, sessionKey: String?, userHandler: AuthUserHandler?) {
        Logger.main.debug("connect with \(context.userId), hasSessionKey: \(sessionKey != nil)")
        
        context.changeState(
            to: ConnectingState(
                loginKey: loginKey,
                sessionKey: sessionKey,
                loginHandlers: [userHandler]
            )
        )
    }
    
    @_spi(SendbirdInternal) public func disconnect(context: ConnectionContext, completionHandler: VoidHandler?) {
        Logger.main.debug()
        context.serviceForWebSocket? {
            completionHandler?()
        }
    }

    @_spi(SendbirdInternal) public func disconnectWebSocket(context: ConnectionContext, completionHandler: VoidHandler?) {
        Logger.main.debug()
    }

    @_spi(SendbirdInternal) public func didSocketClose(context: ConnectionContext, code: ChatWebSocketStatusCode) {
        Logger.main.debug()
        context.serviceForWebSocket? {
            self.disconnectHandler?()
            self.disconnectHandler = nil
        }
    }
    
    @_spi(SendbirdInternal) public func reconnect(context: ConnectionContext, sessionKey: String?, reconnectedBy: ReconnectingTrigger?) -> Bool {
        return false
    }
}
