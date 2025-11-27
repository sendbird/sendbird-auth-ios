//
//  ExternalDisconnectedState.swift
//  SendbirdChatSDK
//
//  Created by Jed Gyeong on 2/13/23.
//

import Foundation

@_spi(SendbirdInternal) public class ExternalDisconnectedState: ConnectionStatable {
    // For disconnect completion
    @_spi(SendbirdInternal) public var completionHandler: VoidHandler?

    @_spi(SendbirdInternal) public init(completionHandler: VoidHandler? = nil) {
        self.completionHandler = completionHandler
    }

    @_spi(SendbirdInternal) public func process(context: ConnectionContext) {
        Logger.main.debug()
        context.disconnectSocket()

        context.eventDispatcher.dispatch(
            command: ConnectionStateEvent.ExternalDisconnected()
        )

        context.serviceForWebSocket? {
            self.completionHandler?()
            self.completionHandler = nil
        }
    }

    @_spi(SendbirdInternal) public func connect(context: ConnectionContext, loginKey: LoginKey, sessionKey: String?, userHandler: AuthUserHandler?) {
        Logger.session.debug()
        // NOTE: this is problem removing existing delegates
        // context.delegate?.onRelease()
        
        context.changeState(
            to: ConnectingState(
                loginKey: loginKey,
                sessionKey: sessionKey,
                loginHandlers: [userHandler]
            )
        )
    }

    @_spi(SendbirdInternal) public func disconnect(context: ConnectionContext, completionHandler: VoidHandler? = nil) {
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
        context.serviceForWebSocket? {
            completionHandler?()
        }
    }
    
    @_spi(SendbirdInternal) public func reconnect(context: ConnectionContext, sessionKey: String?, reconnectedBy: ReconnectingTrigger?) -> Bool {
        Logger.session.debug("reconnect by \(String(describing: reconnectedBy?.rawValue))")
        
        if let sessionKey, reconnectedBy == .manual {
            if let task = context.dataSourceForWebSocket?.reconnectionConfig?.createTask(sessionKey: sessionKey) {
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

        return false
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
