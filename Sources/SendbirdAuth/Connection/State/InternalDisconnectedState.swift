//
//  InternalDisconnectedState.swift
//  SendbirdChat
//
//  Created by Minhyuk Kim on 2021/08/25.
//

import Foundation
import Network

@_spi(SendbirdInternal) public class InternalDisconnectedState: ConnectionStatable {
    // For retry
    @_spi(SendbirdInternal) public let error: AuthError?
    @_spi(SendbirdInternal) public let task: ReconnectionTask?
    @_spi(SendbirdInternal) public let shouldRetry: Bool
    
    // For busy state
    @_spi(SendbirdInternal) public let busyEventWrapper: BusyEventWrapper?
    
    // For disconnect completion
    @_spi(SendbirdInternal) public var completionHandler: VoidHandler?
    
    @_spi(SendbirdInternal) public var reconnectedBy: ReconnectingTrigger?

    @_spi(SendbirdInternal) public init(
        error: AuthError?,
        task: ReconnectionTask?,
        shouldRetry: Bool,
        reconnectedBy: ReconnectingTrigger?,
        busyEventWrapper: BusyEventWrapper? = nil,
        completionHandler: VoidHandler? = nil
    ) {
        self.error = error
        self.task = task
        self.shouldRetry = shouldRetry
        self.reconnectedBy = reconnectedBy
        self.busyEventWrapper = busyEventWrapper
        self.completionHandler = completionHandler
    }
    
    @_spi(SendbirdInternal) public func process(context: ConnectionContext) {
        Logger.main.debug()
        context.disconnectSocket()
        
        context.eventDispatcher.dispatch(command: ConnectionStateEvent.InternalDisconnected(error: error))
        
        // When changed state from DelayedConnectingState
        if let busyEventWrapper {
            Logger.session.debug("timerStartTime=\(String(describing: busyEventWrapper.timerStartTime))")
            return
        }
            
        if let task = task {
            if shouldRetry {
                context.changeState(
                    to: ReconnectingState(
                        task: task,
                        loginHandlers: [],
                        reconnectedBy: self.reconnectedBy,
                        retryCount: 0
                    )
                )
            }
        } else {
            context.changeState(
                to: LogoutState(
                    error: error,
                    userId: context.userId
                )
            )
        }
    }
    
    @_spi(SendbirdInternal) public func connect(context: ConnectionContext, loginKey: LoginKey, sessionKey: String?, userHandler: AuthUserHandler?) {
        Logger.session.debug()
        
        context.changeState(
            to: ConnectingState(
                loginKey: loginKey,
                sessionKey: sessionKey,
                loginHandlers: [userHandler]
            )
        )
    }
    
    @_spi(SendbirdInternal) public func disconnect(context: ConnectionContext, completionHandler: VoidHandler?) {
        Logger.session.debug()
        context.changeState(
            to: LogoutState(
                userId: context.userId,
                disconnectHandler: completionHandler
            )
        )
    }
    
    @_spi(SendbirdInternal) public func disconnectWebSocket(context: ConnectionContext, completionHandler: VoidHandler?) {
        Logger.session.debug()
        context.changeState(
            to: ExternalDisconnectedState(
                completionHandler: completionHandler
            )
        )
    }

    @_spi(SendbirdInternal) public func reconnect(context: ConnectionContext, sessionKey: String?, reconnectedBy: ReconnectingTrigger?) -> Bool {
        Logger.session.debug("reconnect by \(String(describing: reconnectedBy?.rawValue))")
        
        if let busyEventWrapper {
            let timerStartTime = busyEventWrapper.timerStartTime
            let currentTime = Date().timeIntervalSince1970
            let elapsed = currentTime - timerStartTime
            Logger.session.debug("currentTime=\(String(describing: currentTime)), startTime=\(timerStartTime), elapsed=\(elapsed)")
            
            let busyEvent = busyEventWrapper.busyEvent
            if elapsed > Double(busyEvent.retryAfter) {
                // If time is up, change to ReconnectingState
                Logger.session.debug("Elapsed time surpassed the retryAfter seconds. Transitioning to ReconnectingState.")
                
                if let sessionKey {
                    task?.sessionKey = sessionKey
                }
                
                context.changeState(
                    to: ReconnectingState(
                        task: task,
                        loginHandlers: [],
                        reconnectedBy: .busyServer,
                        retryCount: 0
                    )
                )
                return true
            } else {
                Logger.session.debug("Elapsed time remains smaller than retryAfter seconds. Transitioning to DelayedConnectingState.")
                let remainingSeconds = Double(busyEvent.retryAfter) - elapsed
                let newRetryAfter = UInt(remainingSeconds.rounded())
                let newBusyEvent = busyEvent.updateRetryAfter(newRetryAfter)
                Logger.session.debug("remainingSeconds=\(remainingSeconds), newRetryAfter=\(newRetryAfter)")
                
                context.changeState(
                    to: DelayedConnectingState(
                        busyEvent: newBusyEvent,
                        loginHandlers: []
                    )
                )
                
                return true 
            }
            
        } else {
            guard let task = task else {
                return false
            }
            if let sessionKey {
                task.sessionKey = sessionKey
            }
            
            context.changeState(
                to: ReconnectingState(
                    task: task,
                    loginHandlers: [],
                    reconnectedBy: reconnectedBy,
                    retryCount: 0
                )
            )
            return true
        }
    }
    
    @_spi(SendbirdInternal) public func didEnterBackground(context: any ConnectionContext) {
        Logger.session.debug("")
    }
    
    @_spi(SendbirdInternal) public func didSocketClose(context: ConnectionContext, code: ChatWebSocketStatusCode) {
        Logger.session.debug()
        // case. scenario when connected -> disconnected
        //
        // 1. triggered manually by calling disconnect
        //    in this case, userId is not present so its done with calling completion
        //
        // 2. triggered indirectly by calling connect with new userId
        //    in this case, socket is closed the state is changed to disconnect and
        //    onDisconnect is handled where router is get disconnected and connect
        //    with new url
        
        // case. reconnecting -> disconnected
        //
        // socket is not connected so won't be in this method
        context.serviceForWebSocket? {
            self.completionHandler?()
            self.completionHandler = nil
        }
    }
}
