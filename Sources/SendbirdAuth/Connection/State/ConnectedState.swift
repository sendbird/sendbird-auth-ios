//
//  ConnectedState.swift
//  SendbirdChat
//
//  Created by Minhyuk Kim on 2021/08/25.
//

import Foundation

package class ConnectedState: ConnectionStatable {
    package let loginEvent: LoginEvent
    package let task: ReconnectionTask?
    
    package let isReconnected: Bool
    
    package var loginHandlers: [AuthUserHandler?]
    
    package var reconnectedBy: ReconnectingTrigger?

    package init(
        loginEvent: LoginEvent,
        sessionKey: String,
        isReconnected: Bool,
        loginHandlers: [AuthUserHandler?] = [],
        reconnectedBy: ReconnectingTrigger?
    ) {
        if let config = loginEvent.reconnectConfiguration, let user = loginEvent.user {
            self.task = config.createTask(
                sessionKey: sessionKey
            )
            
            Logger.main.info(
                """
                [connect] did receive LOGI with configuration: \(config),
                task: \(String(describing: task))
                """
            )
            Logger.main.info("LOGI received. userInfo: \(user.userId)")
            Logger.session.info("Session Key: \(sessionKey)")
            if isReconnected {
                Logger.session.info("Reconnect Succeeded.")
            }
        } else {
            self.task = nil
        }
        
        self.loginEvent = loginEvent
        self.isReconnected = isReconnected
        self.loginHandlers = loginHandlers
        self.reconnectedBy = reconnectedBy
    }
    
    package func process(context: ConnectionContext) {
        Logger.main.debug("lastConnectedAt: \(String(describing: context.dataSourceForWebSocket?.lastConnectedAt)), reconnectedBy: \(String(describing: reconnectedBy))")
        
        let previouslyConnected = context.dataSourceForWebSocket?.lastConnectedAt != 0
        
        context.eventDispatcher.dispatch(
            command: ConnectionStateEvent.Connected(
                loginEvent: loginEvent,
                isReconnected: isReconnected && previouslyConnected || reconnectedBy == .busyServer
            )
        ) { [weak self] in
            guard let self else { return }
            self.loginHandlers.removeFirstThenClear { copiedLoginHandlers in
                context.serviceForWebSocket? {
                    copiedLoginHandlers.forEach { $0?(self.loginEvent.user, nil) }
                }
            }
        }
    }
    
    package func connect(context: ConnectionContext, loginKey: LoginKey, sessionKey: String?, userHandler: AuthUserHandler?) {
        Logger.session.debug("loginKey: \(loginKey), has sessionKey: \(sessionKey != nil)")
      
        context.serviceForWebSocket? {
            userHandler?(context.dataSourceForWebSocket?.currentUser, nil)
        }
    }
    
    package func reconnect(context: ConnectionContext, sessionKey: String?, reconnectedBy: ReconnectingTrigger?) -> Bool {
        Logger.session.debug("reconnect by \(String(describing: reconnectedBy?.rawValue))")
        
        if let sessionKey {
            task?.sessionKey = sessionKey
        }
        
        context.changeState(
            to: InternalDisconnectedState(
                error: nil,
                task: task,
                shouldRetry: true,
                reconnectedBy: reconnectedBy
            )
        )

        return task != nil
    }
    
    package func didEnterBackground(context: ConnectionContext) {
        Logger.main.debug()
        context.changeState(
            to: InternalDisconnectedState(
                error: nil,
                task: task,
                shouldRetry: false,
                reconnectedBy: nil
            )
        )
    }
    
    package func disconnect(context: ConnectionContext, completionHandler: VoidHandler?) {
        Logger.session.debug()
        context.changeState(
            to: LogoutState(
                userId: context.userId,
                disconnectHandler: completionHandler
            )
        )
    }
    
    package func disconnectWebSocket(context: ConnectionContext, completionHandler: VoidHandler?) {
        Logger.session.debug()
        context.changeState(
            to: ExternalDisconnectedState(
                completionHandler: completionHandler
            )
        )
    }
    
    package func didSocketClose(context: ConnectionContext, code: ChatWebSocketStatusCode) {
        Logger.session.debug()
        context.changeState(
            to: InternalDisconnectedState(
                error: code == .normal ? nil : AuthClientError.networkError.asAuthError,
                task: task,
                shouldRetry: true,
                reconnectedBy: code == .noStatusReceived ? .watchdog : .webSocketError
            )
        )
    }
    
    package func didSocketFail(context: ConnectionContext, error: AuthError?) {
        Logger.session.debug("fail \(String(describing: error?.localizedDescription))")
        context.changeState(
            to: InternalDisconnectedState(
                error: error,
                task: task,
                shouldRetry: true,
                reconnectedBy: .webSocketError
            )
        )
    }
    
    package func didReceiveBUSY(context: any ConnectionContext, command: BusyEvent) {
        Logger.session.debug()
        
        context.changeState(
            to: DelayedConnectingState(
                busyEvent: command,
                loginHandlers: []
            )
        )
    }
}
