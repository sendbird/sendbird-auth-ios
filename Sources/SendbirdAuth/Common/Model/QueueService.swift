//
//  QueueService.swift
//  SendbirdChat
//
//  Created by Minhyuk Kim on 2021/08/26.
//

import Foundation

public class QueueService {
    @InternalAtomic public var completionQueue: DispatchQueue
    
    public init(name: String? = nil) {
        completionQueue = name != nil
            ? DispatchQueue(label: name!)
            : DispatchQueue.main
    }
     
    public func callAsFunction(task: VoidHandler?) {
        self.performOnCompletionQueue(task)
    }
    
    public func performOnCompletionQueue(_ block: (() -> Void)?) {
        completionQueue.async { block?() }
    }
}

// MARK: - CustomDebugStringConvertible

extension QueueService: CustomDebugStringConvertible {
    public var debugDescription: String {
        "QueueService(\(completionQueue))"
    }
}

// MARK: - QueueServiceUsable

public protocol QueueServiceUsable {
    func callAsFunction(task: VoidHandler?)
}

extension QueueService: QueueServiceUsable { }

extension DispatchQueue: QueueServiceUsable {
    public func callAsFunction(task: VoidHandler?) {
        async {
            task?()
        }
    }
}

extension Optional where Wrapped: QueueServiceUsable {
    public func orMain() -> QueueServiceUsable {
        switch self {
        case .some(let queue):
            return queue
        case .none:
            return DispatchQueue.main
        }
    }
}
