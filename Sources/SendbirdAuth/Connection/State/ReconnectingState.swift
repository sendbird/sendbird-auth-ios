//
//  ReconnectingState.swift
//  SendbirdChat
//
//  Created by Minhyuk Kim on 2021/08/25.
//

import Foundation

package class ReconnectingState: ConnectionStatable {
    package var retryCount: Int = 0
    
    /// Changed to optional since [NEXT_VERSION].
    /// Must be optional because when transitioned from DelayedConnectingState with no previous successful connection,
    /// the reconnectionConfiguration (from LOGI payload) does not exist,
    /// hence can't create a ReconnectionTask either.
    package let task: ReconnectionTask?
    
    package var timerBoard: SBTimerBoard = SBTimerBoard(capacity: 1)
    package var loginHandlers: [AuthUserHandler?]
    package var reconnectedBy: ReconnectingTrigger?
    
    package init(
        task: ReconnectionTask?,
        loginHandlers: [AuthUserHandler?] = [],
        reconnectedBy: ReconnectingTrigger?,
        retryCount: Int
    ) {
        self.task = task
        self.loginHandlers = loginHandlers
        self.reconnectedBy = reconnectedBy
        self.retryCount = retryCount
    }
    
    package func process(context: ConnectionContext) {
        Logger.main.debug("retryCount: \(retryCount)")
        
        // if sessionKey exists => reconnect with sessionKey
        // if sessionKey is nil => connect with userId & authToken
        if let sessionKey = task?.sessionKey {
            if retryCount == 0 {
                Logger.session.debug("Reconnect with sessionKey")
                context.notifyNewReconnectionStarted()
                context.eventDispatcher.dispatch(
                    command: ConnectionStateEvent.ReconnectingStarted(
                        userId: context.userId,
                        sessionKey: sessionKey,
                        retryCount: retryCount
                    )
                )
            }
            
            retryConnection(context: context, sessionKey: sessionKey)
        } else if self.reconnectedBy == .busyServer {
            Logger.session.debug("Reconnect with userId or with userId & authToken")
            context.eventDispatcher.dispatch(
                command: ConnectionStateEvent.ReconnectingStarted(
                    userId: context.userId,
                    sessionKey: nil,
                    retryCount: retryCount
                )
            )
            
            connect(context: context, loginKey: context.loginKey)
        } else {
            Logger.session.debug("No sessionKey, and was not transitioned from DelayedConnectingState")
        }
    }
    
    private func retryConnection(context: ConnectionContext, sessionKey: String?) {
        Logger.main.debug("retryCount: \(retryCount)")
        
        guard let task = self.task, task.shouldRetry(with: retryCount) else {
            Logger.main.info("Will broadcast 'didFailReconnection' event")
            context.eventDispatcher.dispatch(command: ConnectionStateEvent.ReconnectionFailed(error: nil))
            processLoginHandlers(context: context, error: AuthClientError.connectionRequired.asAuthError)
            
            context.changeState(
                to: InternalDisconnectedState(
                    error: nil,
                    task: task,
                    shouldRetry: false,
                    reconnectedBy: nil
                )
            )
            return
        }
        
        Logger.session.info("Try to schedule timer with task: \(task)")
        _ = SBTimer(
            timeInterval: task.backoffPeriod(with: retryCount),
            userInfo: nil,
            onBoard: timerBoard,
            identifier: "reconnect",
            repeats: false
        ) { [weak self] in
            guard self != nil else { return }
            
            Logger.session.info("Attempting to reconnect after the backoff period has elapsed.")
            context.notifyReconnectionAttempt()
            context.eventDispatcher.dispatch(
                command: ConnectionStateEvent.Reconnecting(
                    userId: context.userId,
                    sessionKey: sessionKey ?? task.sessionKey
                )
            )
            
            let url = context.createWebSocketURL(userId: context.userId)
            context.connectSocket(url: url, accessToken: nil, sessionKey: task.sessionKey)
        }
        Logger.session.info("Scheduled timer with timeout interval: \(task.backoffPeriod(with: retryCount))")
    }
    
    package func connect(context: ConnectionContext, loginKey: LoginKey, sessionKey: String?, userHandler: AuthUserHandler?) {
        Logger.session.debug("prev retryCount: \(retryCount), reset retryCount")
        retryCount = 0
        timerBoard.stopAll()
        loginHandlers.append(userHandler)
        retryConnection(context: context, sessionKey: sessionKey)
        
        processLoginHandlers(context: context, error: nil)
    }
    
    package func disconnect(context: ConnectionContext, completionHandler: VoidHandler? = nil) {
        timerBoard.stopAll()
        Logger.session.info("disconnectWithCompletionHandler. loginTimer invalidated.")
        
        Logger.session.info("Cancel the current reconnecting.")
        context.eventDispatcher.dispatch(command: ConnectionStateEvent.ReconnectionCanceled())
        processLoginHandlers(context: context, error: AuthClientError.connectionCanceled.asAuthError)
        
        context.changeState(
            to: LogoutState(
                error: AuthClientError.connectionCanceled.asAuthError,
                userId: context.userId,
                disconnectHandler: completionHandler
            )
        )
        // NOTE: reconnecting -> disconnected socket connection is not made so return immediately
    }
    
    package func disconnectWebSocket(context: ConnectionContext, completionHandler: VoidHandler?) {
        Logger.session.debug()
        context.changeState(
            to: ExternalDisconnectedState(
                completionHandler: completionHandler
             )
        )
    }

    package func didEnterBackground(context: ConnectionContext) {
        Logger.session.verbose("called in \(Self.self) state")
        
        processLoginHandlers(context: context, error: AuthClientError.connectionCanceled.asAuthError)
        context.changeState(
            to: InternalDisconnectedState(
                error: nil,
                task: task,
                shouldRetry: false,
                reconnectedBy: nil
            )
        )
    }
    
    package func didSocketOpen(context: ConnectionContext) {
        Logger.session.debug("socket opened. waiting for LOGI")
        guard let webSocketTimeout = context.configForWebSocket?.websocketTimeout else {
            Logger.session.error(errorMessage: .notResolved)
            return
        }
        
         _ = SBTimer(
            timeInterval: webSocketTimeout,
            userInfo: nil,
            onBoard: timerBoard,
            identifier: "login",
            repeats: false
        ) { [weak self] in
            Logger.session.debug("LOGI timed out. retry again")

            context.eventDispatcher.dispatch(
                command: WebSocketStatEvent.WebSocketReconnectLoginTimeoutEvent(
                    hostURL: context.hostURL,
                    error: AuthClientError.reconnectLoginTimeout.asAuthError,
                    retryCount: context.reconnectionTryCount
                )
            )
            
            guard let self = self else { return }
            
            if let sessionKey = task?.sessionKey {
                self.retryConnection(context: context, sessionKey: sessionKey)
            }
        }
    }
    
    package func didSocketFail(context: ConnectionContext, error: AuthError?) {
        Logger.session.debug("fail \(String(describing: error?.localizedDescription))")
        processLoginHandlers(context: context, error: error)
        context.changeState(
            to: ReconnectingState(
                task: task,
                loginHandlers: loginHandlers,
                reconnectedBy: reconnectedBy,
                retryCount: self.retryCount + 1
            )
        )
    }
    
    package func didReceiveLOGI(context: ConnectionContext, command: LoginEvent) {
        Logger.session.debug("received LOGI. error: \(String(describing: command.error?.localizedDescription)), hasSessionKey: \(command.sessionKey != nil)")
        
        guard command.error == nil, let sessionKey = command.sessionKey else {
            context.eventDispatcher.dispatch(command: ConnectionStateEvent.ReconnectionFailed(error: command.error))
            processLoginHandlers(context: context, error: command.error)
            
            if command.error?.shouldRevokeSession == true {
                context.changeState(
                    to: LogoutState(
                        error: command.error,
                        userId: context.userId
                    )
                )
            } else {
                context.changeState(
                    to: InternalDisconnectedState(
                        error: command.error,
                        task: task,
                        shouldRetry: false,
                        reconnectedBy: nil
                    )
                )
                
            }
            return
        }
        
        timerBoard.stopAll()

        context.changeState(
            to: ConnectedState(
                loginEvent: command,
                sessionKey: sessionKey,
                isReconnected: true,
                loginHandlers: loginHandlers,
                reconnectedBy: reconnectedBy
            )
        )
    }
    
    package func didReceiveBUSY(context: any ConnectionContext, command: BusyEvent) {
        Logger.session.debug()
        
        context.changeState(
            to: DelayedConnectingState(
                busyEvent: command,
                loginHandlers: self.loginHandlers
            )
        )
    }

    package func reconnect(context: ConnectionContext, sessionKey: String?, reconnectedBy: ReconnectingTrigger?) -> Bool {
        Logger.session.debug("reconnect by \(String(describing: reconnectedBy?.rawValue))")
        guard let sessionKey, let task = context.dataSourceForWebSocket?
                .reconnectionConfig?
                .createTask(sessionKey: sessionKey) else {
            return false
        }
        
        timerBoard.stopAll()
        
        context.changeState(
            to: ReconnectingState(
                task: task,
                loginHandlers: loginHandlers,
                reconnectedBy: reconnectedBy,
                retryCount: self.retryCount + 1
            )
        )
        return true
    }
    
    private func processLoginHandlers(context: ConnectionContext, error: AuthError?) {
        Logger.main.debug("login handlers: \(loginHandlers.count)")
        loginHandlers.removeFirstThenClear { copiedLoginHandlers in
            context.serviceForWebSocket? {
                let currentUser = error?.shouldRemoveCurrentUserCache == true ? nil : context.dataSourceForWebSocket?.currentUser
                copiedLoginHandlers.forEach { $0?(currentUser, error) }
            }
        }
    }
    
    /// - Since: [NEXT_VERSION]
    private func connect(context: ConnectionContext, loginKey: LoginKey?) {
        Logger.session.debug()
        timerBoard.stopAll()
        
        let url = context.createWebSocketURL(userId: context.userId)
        context.connectSocket(url: url, accessToken: loginKey?.authToken, sessionKey: nil)

    }
}
