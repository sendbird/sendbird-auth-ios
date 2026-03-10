//
//  ConnectingState.swift
//  SendbirdChat
//
//  Created by Minhyuk Kim on 2021/08/25.
//

import Foundation

@_spi(SendbirdInternal) public class ConnectingState: ConnectionStatable {
    @_spi(SendbirdInternal) public var timerBoard: SBTimerBoard = SBTimerBoard(capacity: 1) // login timer
    
    @_spi(SendbirdInternal) public let loginKey: LoginKey
    @_spi(SendbirdInternal) public let sessionKey: String?
    
    @_spi(SendbirdInternal) public var loginHandlers: [AuthUserHandler?]
    
    private let retryCount: Int
    private let defaultConnectionRetryCount = 1
    
    @_spi(SendbirdInternal) public init(
        loginKey: LoginKey,
        sessionKey: String?,
        loginHandlers: [AuthUserHandler?],
        retryCount: Int = 0
    ) {
        self.loginKey = loginKey
        self.sessionKey = sessionKey
        self.loginHandlers = loginHandlers
        self.retryCount = retryCount
    }
    
    @_spi(SendbirdInternal) public func process(context: ConnectionContext) {
        Logger.main.debug("userId: \(context.userId), hasToken: \(loginKey.authToken != nil)")
        
        if retryCount == 0 {
            context.notifyNewConnectionStarted()
        }
        context.dataSourceForWebSocket?.update(with: self.sessionKey)
        context.eventDispatcher.dispatch(
            command: ConnectionStateEvent.Connecting(
                userId: context.userId,
                accessToken: loginKey.authToken,
                sessionKey: self.sessionKey
            )
        )
        
        // Use token
        let url = context.createWebSocketURL(userId: context.userId)
        
        context.connectSocket(url: url, accessToken: loginKey.authToken, sessionKey: nil)
    }

    @_spi(SendbirdInternal) public func connect(context: ConnectionContext, loginKey: LoginKey, sessionKey: String?, userHandler: AuthUserHandler?) {
        Logger.session.debug()
        loginHandlers.append(userHandler)
    }
    
    @_spi(SendbirdInternal) public func disconnect(context: ConnectionContext, completionHandler: VoidHandler?) {
        Logger.session.debug()
        processLoginHandlers(context: context, error: AuthClientError.connectionCanceled.asAuthError)
        context.changeState(
            to: LogoutState(
                userId: context.userId,
                disconnectHandler: completionHandler
            )
        )
    }
    
    @_spi(SendbirdInternal) public func disconnectWebSocket(context: ConnectionContext, completionHandler: VoidHandler?) {
        Logger.session.debug()
        
        processLoginHandlers(context: context, error: AuthClientError.connectionCanceled.asAuthError)
        
        if context.dataSourceForWebSocket?.sessionKey == nil {
            context.changeState(
                to: LogoutState(
                    userId: context.userId,
                    disconnectHandler: completionHandler
                )
            )
        } else {
            context.changeState(
                to: ExternalDisconnectedState(
                    completionHandler: completionHandler
                )
            )
        }
    }
    
    @_spi(SendbirdInternal) public func didSocketOpen(context: ConnectionContext) {
        Logger.session.debug("socket opened. waiting for LOGI \(context.configForWebSocket?.websocketTimeout as Any)")
        
         _ = SBTimer(
            timeInterval: context.configForWebSocket?.websocketTimeout ?? SendbirdConfiguration.webSocketTimoutDefault,
            userInfo: nil,
            onBoard: timerBoard,
            identifier: "login",
            repeats: false
        ) { [weak self] in
            Logger.session.debug("LOGI timedout")
            context.eventDispatcher.dispatch(
                command: WebSocketStatEvent.WebSocketLoginTimeoutEvent(
                    hostURL: context.hostURL,
                    error: AuthClientError.loginTimeout.asAuthError,
                    retryCount: context.connectionRetryCount
                )
            )
            
            self?.processError(
                context: context,
                error: AuthClientError.loginTimeout.asAuthError
            )
        }
    }
    
    @_spi(SendbirdInternal) public func didEnterBackground(context: ConnectionContext) {
        Logger.session.verbose("called in \(Self.self) state")
        
        // INFO: (SBISSUE-14355)
        // When disconnected by moving to the background while in ConnectingState,
        // the error should have localizedFailureReason.
        let error = AuthClientError.connectionCanceled.asAuthError(
            message: nil,
            failureReason: "Moved to background when in ConnectingState."
        )
        processLoginHandlers(context: context, error: error)
       
        Logger.session.debug("has sessionKey: \(self.sessionKey != nil)")
        if let sessionKey = self.sessionKey {
            let task = ReconnectionConfiguration.default.createTask(sessionKey: sessionKey)
            context.changeState(
                to: InternalDisconnectedState(
                    error: nil,
                    task: task,
                    shouldRetry: false,
                    reconnectedBy: nil
                )
            )
        } else {
            context.changeState(
                to: LogoutState(
                    userId: context.userId,
                    disconnectHandler: nil
                )
            )
        }
    }
    
    @_spi(SendbirdInternal) public func didSocketClose(context: ConnectionContext, code: ChatWebSocketStatusCode) {
        Logger.session.debug()
        timerBoard.stopAll()
        processError(context: context, error: AuthCoreError.networkError.asAuthError)
    }
    
    @_spi(SendbirdInternal) public func didSocketFail(context: ConnectionContext, error: AuthError?) {
        Logger.session.debug()
        timerBoard.stopAll()
        processError(context: context, error: error)
    }
    
    @_spi(SendbirdInternal) public func didReceiveLOGI(context: ConnectionContext, command: LoginEvent) {
        Logger.session.debug()
        timerBoard.stopAll()
        
        if processError(context: context, error: command.error) {
            return
        }
        
        guard let sessionKey = command.sessionKey,
              command.user?.userId == context.userId else {
            let error = command.error ?? AuthClientError.unknownError.asAuthError
            processLoginHandlers(context: context, error: error)
            
            context.changeState(
                to: InternalDisconnectedState(
                    error: error,
                    task: nil,
                    shouldRetry: false,
                    reconnectedBy: nil
                )
            )
            return
        }

        context.changeState(
            to: ConnectedState(
                loginEvent: command,
                sessionKey: sessionKey,
                isReconnected: false,
                loginHandlers: loginHandlers,
                reconnectedBy: nil
            )
        )
    }
    
    @_spi(SendbirdInternal) public func didReceiveBUSY(context: any ConnectionContext, command: BusyEvent) {
        Logger.session.debug("BusyEvent: \(command)")
        
        timerBoard.stopAll()
        
        let retryAfter = command.retryAfter
        let reasonCode = command.reasonCode
        let message = command.message
        
        // Flush loginHandler
        let busyError = AuthClientError.serverOverloaded.asAuthError(
            message: nil,
            extraUserInfo: [
                "retry_after": retryAfter,
                "reason_code": reasonCode,
                "message": message
            ]
        )
        processLoginHandlers(context: context, error: busyError)
        
        // Change state to DelayedConnectingState
        context.changeState(
            to: DelayedConnectingState(
                busyEvent: command,
                loginHandlers: self.loginHandlers
            )
        )
    }
    
    @discardableResult
    private func processError(context: ConnectionContext, error: AuthError?) -> Bool {
        guard let error = error else { return false }
        if error.shouldRemoveCurrentUserCache {
            // Connect failure with invalid user data
            processLoginHandlers(context: context, error: error)
            
            context.changeState(
                to: InternalDisconnectedState(
                    error: error,
                    task: nil,
                    shouldRetry: false,
                    reconnectedBy: nil
                )
            )
        } else if context.connectionRetryCount < defaultConnectionRetryCount,
                  context.netStatus != .unavailable,
                  error.code != AuthClientError.accessTokenNotValid.code,
                  error.code != AuthClientError.sessionTokenRevoked.code {
            // Normal connect failure
            context.notifyConnectionFailed()
            context.changeState(
                to: ConnectingState(
                    loginKey: loginKey,
                    sessionKey: sessionKey,
                    loginHandlers: loginHandlers,
                    retryCount: retryCount + 1
                )
            )
        } else if !context.userId.isEmpty && context.dataSourceForWebSocket?.sessionKey != nil {
            // Try to reconnect if the user ID exists in the connecting state.
            let reconnectionConfig = ReconnectionConfiguration(
                baseInterval: 2,
                maximumInterval: 20,
                multiplier: 2,
                maximumRetryCount: -1
            )
            let task = reconnectionConfig.createTask(sessionKey: context.dataSourceForWebSocket!.sessionKey!)
            processLoginHandlers(context: context, error: error)

            context.changeState(
                to: InternalDisconnectedState(
                    error: error,
                    task: task,
                    shouldRetry: true,
                    reconnectedBy: .cachedSessionKey
                )
            )
        } else {
            processLoginHandlers(context: context, error: error)
            
            // Offline connection if exists
            // TODO: Can this else statement be possible?
            if context.dataSourceForWebSocket?.sessionKey != nil {
                let task = context.dataSourceForWebSocket?.reconnectionConfig?.createTask(sessionKey: loginKey.authToken ?? "")
                context.changeState(
                    to: InternalDisconnectedState(
                        error: error,
                        task: task,
                        shouldRetry: false,
                        reconnectedBy: .cachedSessionKey
                    )
                )
            } else {
                context.changeState(
                    to: LogoutState(
                        error: error,
                        userId: context.userId
                    )
                )
            }
        }
        
        return true
    }
    
    private func processLoginHandlers(context: ConnectionContext, error: AuthError?) {
        Logger.main.debug("connect handlers: \(loginHandlers.count)")
        
        loginHandlers.removeFirstThenClear { copiedLoginHandlers in
            context.serviceForWebSocket? {
                let currentUser = error?.shouldRemoveCurrentUserCache == true ? nil : context.dataSourceForWebSocket?.currentUser
                copiedLoginHandlers.forEach { $0?(currentUser, error) }
            }
        }
    }
    
    @_spi(SendbirdInternal) public func reconnect(context: ConnectionContext, sessionKey: String?, reconnectedBy: ReconnectingTrigger?) -> Bool {
        return false
    }
}
