//
//  ConnectionState.swift
//  SendbirdChat
//
//  Created by Minhyuk Kim on 2021/08/25.
//

import Foundation

@_spi(SendbirdInternal) public protocol ConnectionStatable {
    var reconnectedBy: ReconnectingTrigger? { get }
    /**
     Responsible to do state job when it is first initialize and set to current state
     */
    func process(context: ConnectionContext)
    
    /**
     Attempts to move state to connecting state with given parameters
     */
    func connect(context: ConnectionContext, loginKey: LoginKey, sessionKey: String?, userHandler: AuthUserHandler?)
    
    /**
     Attempts to move state to disconnected state
     */
    func disconnect(context: ConnectionContext, completionHandler: VoidHandler?)
    
    func disconnectWebSocket(context: ConnectionContext, completionHandler: VoidHandler?)
    
    /**
     Notifies state that the application has entered background
     */
    func didEnterBackground(context: ConnectionContext)

    /**
     Attempts to move state to reconnecting state
     */
    func reconnect(context: ConnectionContext, sessionKey: String?, reconnectedBy: ReconnectingTrigger?) -> Bool
    
    /**
     Notifies state that socket connection is now opend
     */
    func didSocketOpen(context: ConnectionContext)
    
    /**
     Notifies state that socket connection is now closed with given parameters
     */
    func didSocketClose(context: ConnectionContext, code: ChatWebSocketStatusCode)
    
    /**
     Notifies state that socket connection has been failed with error
     */
    func didSocketFail(context: ConnectionContext, error: AuthError?)
    
    /**
     Notifies state that socket receives login payload from remote server
     */
    func didReceiveLOGI(context: ConnectionContext, command: LoginEvent)
    
    func didReceiveBUSY(context: ConnectionContext, command: BusyEvent)
}

extension ConnectionStatable {
    @_spi(SendbirdInternal) public var reconnectedBy: ReconnectingTrigger? { nil }
    
    @_spi(SendbirdInternal) public func reconnect(context: ConnectionContext, sessionKey: String?, reconnectedBy: ReconnectingTrigger?) -> Bool { return false }
    
    @_spi(SendbirdInternal) public func didSocketOpen(context: ConnectionContext) { }
    
    @_spi(SendbirdInternal) public func didSocketClose(context: ConnectionContext, code: ChatWebSocketStatusCode) { }
    
    @_spi(SendbirdInternal) public func didReceiveLOGI(context: ConnectionContext, command: LoginEvent) { }
    
    /// - Since: 4.34.0
    @_spi(SendbirdInternal) public func didReceiveBUSY(context: ConnectionContext, command: BusyEvent) { }
    
    @_spi(SendbirdInternal) public func didSocketFail(context: ConnectionContext, error: AuthError?) { }
    
    @_spi(SendbirdInternal) public func didEnterBackground(context: ConnectionContext) { }
}
