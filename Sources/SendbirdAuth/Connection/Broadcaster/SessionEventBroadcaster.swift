//
//  SessionEventBroadcaster.swift
//  SendbirdChat
//
//  Created by Wooyoung Chung on 7/27/21.
//

import Foundation

package class SessionEventBroadcaster: EventBroadcaster {
    package let service: QueueService
    package let delegates: NSMapTable<NSString, AuthSessionDelegate>
    
    package init(_ service: QueueService, mapTableValueOption: NSPointerFunctions.Options) {
        self.delegates = NSMapTable(keyOptions: .strongMemory, valueOptions: mapTableValueOption)
        self.service = service
    }
    
    package func didTokenRequire(
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

    package func wasClosed() {
        self.broadcast { $0.sessionWasClosed() }
    }
    
    package func wasRefreshed() {
        self.broadcast { $0.sessionWasRefreshed?() }
    }
    
    package func didHaveError(_ error: NSError) {
        self.broadcast { $0.sessionDidHaveError?(error) }
    }
}
