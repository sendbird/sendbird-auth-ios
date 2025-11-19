//
//  ConnectionState.swift
//  SendbirdChat
//
//  Created by Minhyuk Kim on 2021/08/25.
//

import Foundation

package protocol ConnectionStatable {
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
    package var reconnectedBy: ReconnectingTrigger? { nil }
    
    package func reconnect(context: ConnectionContext, sessionKey: String?, reconnectedBy: ReconnectingTrigger?) -> Bool { return false }
    
    package func didSocketOpen(context: ConnectionContext) { }
    
    package func didSocketClose(context: ConnectionContext, code: ChatWebSocketStatusCode) { }
    
    package func didReceiveLOGI(context: ConnectionContext, command: LoginEvent) { }
    
    /// - Since: [NEXT_VERSION]
    package func didReceiveBUSY(context: ConnectionContext, command: BusyEvent) { }
    
    package func didSocketFail(context: ConnectionContext, error: AuthError?) { }
    
    package func didEnterBackground(context: ConnectionContext) { }
}
