//
//  InitializedState.swift
//  SendbirdChat
//
//  Created by Minhyuk Kim on 2021/08/25.
//

import Foundation

package class InitializedState: ConnectionStatable {
    package func process(context: ConnectionContext) { }
    
    package init() { }

    package func connect(context: ConnectionContext, loginKey: LoginKey, sessionKey: String?, userHandler: AuthUserHandler?) {
        self.connect(context: context, loginKey: loginKey, sessionKey: sessionKey, userHandler: [userHandler])
    }
    
    package func connect(context: ConnectionContext, loginKey: LoginKey, sessionKey: String?, userHandler: [AuthUserHandler?]) {
        context.changeState(
            to: ConnectingState(
                loginKey: loginKey,
                sessionKey: sessionKey,
                loginHandlers: userHandler
            )
        )
    }
    
    package func disconnect(context: ConnectionContext, completionHandler: VoidHandler?) {
        context.changeState(
            to: LogoutState(
                userId: context.userId,
                disconnectHandler: completionHandler
            )
        )
    }
    
    package func disconnectWebSocket(context: ConnectionContext, completionHandler: VoidHandler?) {
        context.serviceForWebSocket? {
            completionHandler?()
        }
    }
    
    package func reconnect(context: ConnectionContext, sessionKey: String?, reconnectedBy: ReconnectingTrigger?) -> Bool {
        return false
    }
    
    package func didEnterBackground(context: ConnectionContext) {
        
    }
}
