//
//  ConnectionEventBroadcaster.swift
//  SendbirdChat
//
//  Created by Wooyoung Chung on 7/27/21.
//

import Foundation

package class ConnectionEventBroadcaster: EventBroadcaster {
    package let service: QueueService
    package let delegates: NSMapTable<NSString, AuthConnectionDelegate>
    
    required package init(_ service: QueueService, mapTableValueOption: NSPointerFunctions.Options) {
        self.delegates = NSMapTable(keyOptions: .strongMemory, valueOptions: mapTableValueOption)
        self.service = service
    }
    
    package func startedReconnection() {
        broadcast { $0.didStartReconnection?() }
    }
    
    package func succeededReconnection() {
        broadcast { $0.didSucceedReconnection?() }
    }
    
    package func failedReconnection() {
        broadcast { $0.didFailReconnection?() }
    }
    
    package func connected(userId: String) {
        broadcast { $0.didConnect?(userId: userId) }
    }
    
    package func disconnected(userId: String) {
        broadcast { $0.didDisconnect?(userId: userId) }
    }
    
    /// - Since: [NEXT_VERSION]
    package func delayedConnection(retryAfter: UInt) {
        broadcast { $0.didDelayConnection?(retryAfter: retryAfter) }
    }
}

package class NetworkEventBroadcaster: EventBroadcaster {
    package let service: QueueService
    package let delegates: NSMapTable<NSString, NetworkDelegate>
    
    required package init(_ service: QueueService) {
        self.delegates = NSMapTable(keyOptions: .strongMemory, valueOptions: .weakMemory)
        self.service = service
    }
    
    package func reconnected() {
        self.broadcast { $0.didReconnect() }
    }
}

package class InternalConnectionEventBroadcaster {
    let service: QueueService
    let delegates: [NSString: InternalConnectionDelegate]
    
    required package init(_ service: QueueService) {
        self.delegates = [:]
//        NSMapTable(keyOptions: .strongMemory, valueOptions: .weakMemory)
        self.service = service
    }
    
    func internalDisconnected() {
        service { [weak self] in
            guard let self else {
                return
            }
            
            self.delegates
                .values
                .forEach {
                    $0.didInternalDisconnect()
                }
        }
    }
    
    func externalDisconnected() {
        service { [weak self] in
            guard let self else {
                return
            }
            
            self.delegates
                .values
                .forEach {
                    $0.didExternalDisconnect()
                }
        }
    }
}
