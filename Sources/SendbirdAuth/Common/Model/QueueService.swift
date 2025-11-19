//
//  QueueService.swift
//  SendbirdChat
//
//  Created by Minhyuk Kim on 2021/08/26.
//

import Foundation

package class QueueService {
    @InternalAtomic package var completionQueue: DispatchQueue
    
    package init(name: String? = nil) {
        completionQueue = name != nil
            ? DispatchQueue(label: name!)
            : DispatchQueue.main
    }
     
    package func callAsFunction(task: VoidHandler?) {
        self.performOnCompletionQueue(task)
    }
    
    package func performOnCompletionQueue(_ block: (() -> Void)?) {
        completionQueue.async { block?() }
    }
}

// MARK: - CustomDebugStringConvertible

extension QueueService: CustomDebugStringConvertible {
    package var debugDescription: String {
        "QueueService(\(completionQueue))"
    }
}

// MARK: - QueueServiceUsable

package protocol QueueServiceUsable {
    func callAsFunction(task: VoidHandler?)
}

extension QueueService: QueueServiceUsable { }

extension DispatchQueue: QueueServiceUsable {
    package func callAsFunction(task: VoidHandler?) {
        async {
            task?()
        }
    }
}

extension Optional where Wrapped: QueueServiceUsable {
    package func orMain() -> QueueServiceUsable {
        switch self {
        case .some(let queue):
            return queue
        case .none:
            return DispatchQueue.main
        }
    }
}
