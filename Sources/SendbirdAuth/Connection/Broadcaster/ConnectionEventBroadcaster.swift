//
//  ConnectionEventBroadcaster.swift
//  SendbirdChat
//
//  Created by Wooyoung Chung on 7/27/21.
//

import Foundation

@_spi(SendbirdInternal) public class ConnectionEventBroadcaster: EventBroadcaster {
    @_spi(SendbirdInternal) public let service: QueueService
    @_spi(SendbirdInternal) public let delegates: NSMapTable<NSString, AuthConnectionDelegate>
    @_spi(SendbirdInternal) public let delegateLock: NSLock

    @_spi(SendbirdInternal) required public init(_ service: QueueService, mapTableValueOption: NSPointerFunctions.Options) {
        self.delegates = NSMapTable(keyOptions: .strongMemory, valueOptions: mapTableValueOption)
        self.service = service
        self.delegateLock = NSLock()
    }
    
    @_spi(SendbirdInternal) public func startedReconnection() {
        broadcast { $0.didStartReconnection?() }
    }
    
    @_spi(SendbirdInternal) public func succeededReconnection() {
        broadcast { $0.didSucceedReconnection?() }
    }
    
    @_spi(SendbirdInternal) public func failedReconnection() {
        broadcast { $0.didFailReconnection?() }
    }
    
    @_spi(SendbirdInternal) public func connected(userId: String) {
        broadcast { $0.didConnect?(userId: userId) }
    }
    
    @_spi(SendbirdInternal) public func disconnected(userId: String) {
        broadcast { $0.didDisconnect?(userId: userId) }
    }
    
    /// - Since: 4.34.0
    @_spi(SendbirdInternal) public func delayedConnection(retryAfter: UInt) {
        broadcast { $0.didDelayConnection?(retryAfter: retryAfter) }
    }
}

@_spi(SendbirdInternal) public class NetworkEventBroadcaster: EventBroadcaster {
    @_spi(SendbirdInternal) public let service: QueueService
    @_spi(SendbirdInternal) public let delegates: NSMapTable<NSString, NetworkDelegate>
    @_spi(SendbirdInternal) public let delegateLock: NSLock

    @_spi(SendbirdInternal) required public init(_ service: QueueService) {
        self.delegates = NSMapTable(keyOptions: .strongMemory, valueOptions: .weakMemory)
        self.service = service
        self.delegateLock = NSLock()
    }
    
    @_spi(SendbirdInternal) public func reconnected() {
        self.broadcast { $0.didReconnect() }
    }
}

@_spi(SendbirdInternal) public class InternalConnectionEventBroadcaster: EventBroadcaster {
    @_spi(SendbirdInternal) public let service: QueueService
    @_spi(SendbirdInternal) public let delegates: NSMapTable<NSString, InternalConnectionDelegate>
    @_spi(SendbirdInternal) public let delegateLock: NSLock

    @_spi(SendbirdInternal) required public init(_ service: QueueService) {
        self.delegates = NSMapTable(keyOptions: .strongMemory, valueOptions: .weakMemory)
        self.service = service
        self.delegateLock = NSLock()
    }
    
    @_spi(SendbirdInternal) public func internalDisconnected() {
        broadcast { $0.didInternalDisconnect() }
    }
    
    @_spi(SendbirdInternal) public func externalDisconnected() {
        broadcast { $0.didExternalDisconnect() }
    }
}
