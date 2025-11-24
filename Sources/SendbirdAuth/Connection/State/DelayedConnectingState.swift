//
//  DelayedConnectingState.swift
//  SendbirdAuth
//
//  Created by Celine Moon on 9/2/25.
//

import Foundation

/// The connection state is transitioned to DelayedConnectingState when the SDK receives the `BUSY` command from server.
/// The state in which the connection is being delayed.
/// This state automatically retries connection after `retryAfter` seconds.
/// - Since: 4.34.0
public class DelayedConnectingState: ConnectionStatable {
    let busyEvent: BusyEvent
    var loginHandlers: [AuthUserHandler?]
    
    public let timerBoard: SBTimerBoard = SBTimerBoard(capacity: 1)
    private var timerStartTime: TimeInterval
    
    public init(busyEvent: BusyEvent, loginHandlers: [AuthUserHandler?]) {
        self.busyEvent = busyEvent
        self.loginHandlers = loginHandlers
        self.timerStartTime = Date().timeIntervalSince1970
    }
    
    public func process(context: any ConnectionContext) {
        Logger.session.debug("userId: \(context.userId), busyEvent: \(busyEvent)")
        
        // disconnect websocket
        context.disconnectSocket()
        
        // Dispatch connectionDelayed event
        context.eventDispatcher.dispatch(
            command: ConnectionStateEvent.ConnectionDelayed(
                retryAfter: busyEvent.retryAfter
            )
        )
        
        // Start timer for retryAfter seconds.
        // When time is up, change to ReconnectingState
        
        // Record timer start time
        timerStartTime = Date().timeIntervalSince1970
        Logger.session.debug("timerStartTime=\(String(describing: timerStartTime))")
        
        // debugging current time
        debugPrintCurrentTime()
        
        _ = SBTimer(
            timeInterval: TimeInterval(busyEvent.retryAfter),
            userInfo: nil,
            onBoard: timerBoard,
            identifier: "delayed connection",
            repeats: false
        ) { [weak self] in
            guard let self else { return }
            
            // debugging timer end time
            debugPrintCurrentTime()
            
            Logger.session.info("Attempting to retry connect after retryAfter=\(busyEvent.retryAfter) seconds")
            
            if let sessionKey = context.dataSourceForWebSocket?.sessionKey,
               let task = context.dataSourceForWebSocket?.reconnectionConfig?.createTask(sessionKey: sessionKey) {
                Logger.session.debug("Reconnect with sessionKey")
                context.changeState(
                    to: ReconnectingState(
                        task: task,
                        loginHandlers: self.loginHandlers,
                        reconnectedBy: .busyServer,
                        retryCount: 0
                    )
                )
            } else {
                Logger.session.debug("Connect with userId & authToken")
                context.changeState(
                    to: ReconnectingState(
                        task: nil,
                        loginHandlers: self.loginHandlers,
                        reconnectedBy: .busyServer,
                        retryCount: 0
                    )
                )
            }
        }
    }
    
    public func connect(context: any ConnectionContext, loginKey: LoginKey, sessionKey: String?, userHandler: AuthUserHandler?) {
        Logger.session.debug()
        loginHandlers.append(userHandler)
        
        // Calculate elapsed time and remaining time
        let remainingRetryAfter = getRemainingRetryAfter(startTime: timerStartTime)
        
        // process loginHandler
        let busyError = AuthClientError.serverOverloaded.asAuthError(
            message: nil,
            extraUserInfo: [
                "retry_after": remainingRetryAfter,
                "reason_code": busyEvent.reasonCode,
                "message": busyEvent.message
            ]
        )
        processLoginHandlers(context: context, error: busyError)
        
        // dispatch ConnectionDelayed with remaining time
        context.eventDispatcher.dispatch(
            command: ConnectionStateEvent.ConnectionDelayed(
                retryAfter: remainingRetryAfter
            )
        )
    }
    
    public func reconnect(context: any ConnectionContext, sessionKey: String?, reconnectedBy: ReconnectingTrigger?) -> Bool {
        Logger.session.debug("sessionKey=\(sessionKey ?? "nil"), reconnectedBy=\(String(describing: reconnectedBy))")
        
        let remainingRetryAfter = getRemainingRetryAfter(startTime: timerStartTime)
        
        // process loginHandler
        let busyError = AuthClientError.serverOverloaded.asAuthError(
            message: nil,
            extraUserInfo: [
                "retry_after": remainingRetryAfter,
                "reason_code": busyEvent.reasonCode,
                "message": busyEvent.message
            ]
        )
        processLoginHandlers(context: context, error: busyError)
        
        // dispatch ConnectionDelayed with remaining time
        context.eventDispatcher.dispatch(
            command: ConnectionStateEvent.ConnectionDelayed(
                retryAfter: remainingRetryAfter
            )
        )
        
        return false
    }
    
    public func disconnect(context: any ConnectionContext, completionHandler: VoidHandler?) {
        timerBoard.stopAll()
        Logger.session.debug()
        // logout state
        processLoginHandlers(context: context, error: AuthClientError.connectionCanceled.asAuthError)
        context.changeState(
            to: LogoutState(
                userId: context.userId,
                disconnectHandler: completionHandler
            )
        )
    }
    
    public func disconnectWebSocket(context: any ConnectionContext, completionHandler: VoidHandler?) {
        timerBoard.stopAll()
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
    
    public func didEnterBackground(context: any ConnectionContext) {
        Logger.session.debug()
        
        processLoginHandlers(context: context, error: AuthClientError.connectionCanceled.asAuthError)
        
        var reconnectionTask: ReconnectionTask?
        if let sessionKey = context.dataSourceForWebSocket?.sessionKey,
           let task = context.dataSourceForWebSocket?.reconnectionConfig?.createTask(sessionKey: sessionKey) {
            reconnectionTask = task
        }
        Logger.session.debug("reconnectionTask=\(String(describing: reconnectionTask))")
        let busyEventWrapper = BusyEventWrapper(
            busyEvent: self.busyEvent,
            timerStartTime: self.timerStartTime
        )
        context.changeState(
            to: InternalDisconnectedState(
                error: nil,
                task: reconnectionTask,
                shouldRetry: false,
                reconnectedBy: nil,
                busyEventWrapper: busyEventWrapper
            )
        )
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
    
    public func didSocketClose(context: any ConnectionContext, code: ChatWebSocketStatusCode) {
        Logger.session.debug()
    }
    public func didSocketFail(context: any ConnectionContext, error: AuthError?) {
        Logger.session.debug()
    }
}

extension DelayedConnectingState {
    private func getRemainingRetryAfter(startTime: TimeInterval) -> UInt {
        let currentTime = Date().timeIntervalSince1970
        let elapsedTimeSeconds = currentTime - startTime
        let remainingTimeSeconds = max(0, TimeInterval(busyEvent.retryAfter) - elapsedTimeSeconds)
        
        let remainingRetryAfter = UInt(remainingTimeSeconds.rounded(.up))
        Logger.session.debug("remainingRetryAfter=\(remainingRetryAfter)")
        
        return remainingRetryAfter
    }
    
    private func debugPrintCurrentTime() {
        let now = Date()
        let calendar = Calendar.current

        let hour = calendar.component(.hour, from: now)
        let minute = calendar.component(.minute, from: now)
        let second = calendar.component(.second, from: now)
        let nanosecond = calendar.component(.nanosecond, from: now)
        let millisecond = nanosecond / 1_000_000

        let currentTime = String(format: "%02d, %02d, %02d, %03d", hour, minute, second, millisecond)
        Logger.session.debug("retryAFter=\(busyEvent.retryAfter), currentTime=\(currentTime)")
    }
}
