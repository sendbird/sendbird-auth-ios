//
//  ConnectionDelegate.swift
//  SendbirdChat
//
//  Created by Minhyuk Kim on 2021/07/14.
//

import Foundation

@objc(SBDInternalConnectionDelegate)
@_spi(SendbirdInternal) public protocol InternalConnectionDelegate {
    func didInternalDisconnect()
    
    func didExternalDisconnect()
}

@objc(SBDAuthConnectionDelegate)
@_spi(SendbirdInternal) public protocol AuthConnectionDelegate {
    @objc
    optional func didStartReconnection()

    @objc
    optional func didSucceedReconnection()

    @objc
    optional func didFailReconnection()
    
    @objc
    optional func didConnect(userId: String)
    
    @objc
    optional func didDisconnect(userId: String)
    
    /// Invoked when the connecting is delayed. The connection will be automatically retried after `retryAfter` seconds.
    /// This happens when the server is busy due to being overloaded.
    /// - Since: 4.34.0
    @objc
    optional func didDelayConnection(retryAfter: UInt)
}
