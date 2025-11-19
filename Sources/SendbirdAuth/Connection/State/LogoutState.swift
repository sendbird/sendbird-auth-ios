//
//  LogoutState.swift
//  SendbirdChat
//
//  Created by Minhyuk Kim on 2022/01/19.
//

import Foundation

package class LogoutState: ConnectionStatable {
    package let error: AuthError?
    package var disconnectHandler: VoidHandler?
    package let userId: String

    package init(
        error: AuthError? = nil,
        userId: String,
        disconnectHandler: VoidHandler? = nil
    ) {
        self.error = error
        self.userId = userId
        self.disconnectHandler = disconnectHandler
    }

    package func process(context: ConnectionContext) {
        Logger.session.info("Clear local data.")
        context.eventDispatcher.dispatch(command: ConnectionStateEvent.Logout(userId: userId, error: error))
        
        context.disconnectSocket()
        context.changeState(to: InitializedState())
        
        context.serviceForWebSocket? {
            self.disconnectHandler?()
            self.disconnectHandler = nil
        }
    }

    package func connect(context: ConnectionContext, loginKey: LoginKey, sessionKey: String?, userHandler: AuthUserHandler?) {
        Logger.main.debug("connect with \(context.userId), hasSessionKey: \(sessionKey != nil)")
        
        context.changeState(
            to: ConnectingState(
                loginKey: loginKey,
                sessionKey: sessionKey,
                loginHandlers: [userHandler]
            )
        )
    }
    
    package func disconnect(context: ConnectionContext, completionHandler: VoidHandler?) {
        Logger.main.debug()
        context.serviceForWebSocket? {
            completionHandler?()
        }
    }

    package func disconnectWebSocket(context: ConnectionContext, completionHandler: VoidHandler?) {
        Logger.main.debug()
    }

    package func didSocketClose(context: ConnectionContext, code: ChatWebSocketStatusCode) {
        Logger.main.debug()
        context.serviceForWebSocket? {
            self.disconnectHandler?()
            self.disconnectHandler = nil
        }
    }
    
    package func reconnect(context: ConnectionContext, sessionKey: String?, reconnectedBy: ReconnectingTrigger?) -> Bool {
        return false
    }
}
