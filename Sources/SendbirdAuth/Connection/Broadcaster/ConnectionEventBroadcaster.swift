//
//  ConnectionEventBroadcaster.swift
//  SendbirdChat
//
//  Created by Wooyoung Chung on 7/27/21.
//

import Foundation

public class ConnectionEventBroadcaster: EventBroadcaster {
    public let service: QueueService
    public let delegates: NSMapTable<NSString, AuthConnectionDelegate>
    public let delegateLock: NSLock

    required public init(_ service: QueueService, mapTableValueOption: NSPointerFunctions.Options) {
        self.delegates = NSMapTable(keyOptions: .strongMemory, valueOptions: mapTableValueOption)
        self.service = service
        self.delegateLock = NSLock()
    }
    
    public func startedReconnection() {
        broadcast { $0.didStartReconnection?() }
    }
    
    public func succeededReconnection() {
        broadcast { $0.didSucceedReconnection?() }
    }
    
    public func failedReconnection() {
        broadcast { $0.didFailReconnection?() }
    }
    
    public func connected(userId: String) {
        broadcast { $0.didConnect?(userId: userId) }
    }
    
    public func disconnected(userId: String) {
        broadcast { $0.didDisconnect?(userId: userId) }
    }
    
    /// - Since: 4.34.0
    public func delayedConnection(retryAfter: UInt) {
        broadcast { $0.didDelayConnection?(retryAfter: retryAfter) }
    }
}

public class NetworkEventBroadcaster: EventBroadcaster {
    public let service: QueueService
    public let delegates: NSMapTable<NSString, NetworkDelegate>
    public let delegateLock: NSLock

    required public init(_ service: QueueService) {
        self.delegates = NSMapTable(keyOptions: .strongMemory, valueOptions: .weakMemory)
        self.service = service
        self.delegateLock = NSLock()
    }
    
    public func reconnected() {
        self.broadcast { $0.didReconnect() }
    }
}

public class InternalConnectionEventBroadcaster: EventBroadcaster {
    public let service: QueueService
    public let delegates: NSMapTable<NSString, InternalConnectionDelegate>
    public let delegateLock: NSLock

    required public init(_ service: QueueService) {
        self.delegates = NSMapTable(keyOptions: .strongMemory, valueOptions: .weakMemory)
        self.service = service
        self.delegateLock = NSLock()
    }
    
    public func internalDisconnected() {
        broadcast { $0.didInternalDisconnect() }
    }
    
    public func externalDisconnected() {
        broadcast { $0.didExternalDisconnect() }
    }
}
