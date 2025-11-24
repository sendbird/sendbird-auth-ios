//
//  SessionEventBroadcaster.swift
//  SendbirdChat
//
//  Created by Wooyoung Chung on 7/27/21.
//

import Foundation

public class SessionEventBroadcaster: EventBroadcaster {
    public let service: QueueService
    public let delegates: NSMapTable<NSString, AuthSessionDelegate>
    public let delegateLock: NSLock

    public init(_ service: QueueService, mapTableValueOption: NSPointerFunctions.Options) {
        self.delegates = NSMapTable(keyOptions: .strongMemory, valueOptions: mapTableValueOption)
        self.service = service
        self.delegateLock = NSLock()
    }
    
    public func didTokenRequire(
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

    public func wasClosed() {
        self.broadcast { $0.sessionWasClosed() }
    }
    
    public func wasRefreshed() {
        self.broadcast { $0.sessionWasRefreshed?() }
    }
    
    public func didHaveError(_ error: NSError) {
        self.broadcast { $0.sessionDidHaveError?(error) }
    }
}
