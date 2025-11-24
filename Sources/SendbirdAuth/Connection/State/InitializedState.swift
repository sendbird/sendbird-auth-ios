//
//  InitializedState.swift
//  SendbirdChat
//
//  Created by Minhyuk Kim on 2021/08/25.
//

import Foundation

public class InitializedState: ConnectionStatable {
    public func process(context: ConnectionContext) { }
    
    public init() { }

    public func connect(context: ConnectionContext, loginKey: LoginKey, sessionKey: String?, userHandler: AuthUserHandler?) {
        self.connect(context: context, loginKey: loginKey, sessionKey: sessionKey, userHandler: [userHandler])
    }
    
    public func connect(context: ConnectionContext, loginKey: LoginKey, sessionKey: String?, userHandler: [AuthUserHandler?]) {
        context.changeState(
            to: ConnectingState(
                loginKey: loginKey,
                sessionKey: sessionKey,
                loginHandlers: userHandler
            )
        )
    }
    
    public func disconnect(context: ConnectionContext, completionHandler: VoidHandler?) {
        context.changeState(
            to: LogoutState(
                userId: context.userId,
                disconnectHandler: completionHandler
            )
        )
    }
    
    public func disconnectWebSocket(context: ConnectionContext, completionHandler: VoidHandler?) {
        context.serviceForWebSocket? {
            completionHandler?()
        }
    }
    
    public func reconnect(context: ConnectionContext, sessionKey: String?, reconnectedBy: ReconnectingTrigger?) -> Bool {
        return false
    }
    
    public func didEnterBackground(context: ConnectionContext) {
        
    }
}
