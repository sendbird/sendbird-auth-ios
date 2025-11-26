//
//  SessionEventBroadcaster.swift
//  SendbirdChat
//
//  Created by Wooyoung Chung on 7/27/21.
//

import Foundation

@_spi(SendbirdInternal) public class SessionEventBroadcaster: EventBroadcaster {
    @_spi(SendbirdInternal) public let service: QueueService
    @_spi(SendbirdInternal) public let delegates: NSMapTable<NSString, AuthSessionDelegate>
    @_spi(SendbirdInternal) public let delegateLock: NSLock

    @_spi(SendbirdInternal) public init(_ service: QueueService, mapTableValueOption: NSPointerFunctions.Options) {
        self.delegates = NSMapTable(keyOptions: .strongMemory, valueOptions: mapTableValueOption)
        self.service = service
        self.delegateLock = NSLock()
    }
    
    @_spi(SendbirdInternal) public func didTokenRequire(
        successCompletion: @escaping (String?) -> Void,
        failCompletion: @escaping () -> Void
    ) {
        self.broadcast {
            $0.sessionTokenDidRequire(
                successCompletion: successCompletion,
                failCompletion: failCompletion
            )
        }
    }

    @_spi(SendbirdInternal) public func wasClosed() {
        self.broadcast { $0.sessionWasClosed() }
    }
    
    @_spi(SendbirdInternal) public func wasRefreshed() {
        self.broadcast { $0.sessionWasRefreshed?() }
    }
    
    @_spi(SendbirdInternal) public func didHaveError(_ error: NSError) {
        self.broadcast { $0.sessionDidHaveError?(error) }
    }
}
