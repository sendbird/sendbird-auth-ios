//
//  QueueService.swift
//  SendbirdChat
//
//  Created by Minhyuk Kim on 2021/08/26.
//

import Foundation

@_spi(SendbirdInternal) public class QueueService {
    @InternalAtomic @_spi(SendbirdInternal) public var completionQueue: DispatchQueue
    
    @_spi(SendbirdInternal) public init(name: String? = nil) {
        completionQueue = name != nil
            ? DispatchQueue(label: name!)
            : DispatchQueue.main
    }
     
    @_spi(SendbirdInternal) public func callAsFunction(task: VoidHandler?) {
        self.performOnCompletionQueue(task)
    }
    
    @_spi(SendbirdInternal) public func performOnCompletionQueue(_ block: (() -> Void)?) {
        completionQueue.async { block?() }
    }
}

// MARK: - CustomDebugStringConvertible

extension QueueService: CustomDebugStringConvertible {
    @_spi(SendbirdInternal) public var debugDescription: String {
        "QueueService(\(completionQueue))"
    }
}

// MARK: - QueueServiceUsable

@_spi(SendbirdInternal) public protocol QueueServiceUsable {
    func callAsFunction(task: VoidHandler?)
}

@_spi(SendbirdInternal) extension QueueService: QueueServiceUsable { }

@_spi(SendbirdInternal) extension DispatchQueue: QueueServiceUsable {
    @_spi(SendbirdInternal) public func callAsFunction(task: VoidHandler?) {
        async {
            task?()
        }
    }
}

@_spi(SendbirdInternal) extension Optional where Wrapped: QueueServiceUsable {
    @_spi(SendbirdInternal) public func orMain() -> QueueServiceUsable {
        switch self {
        case .some(let queue):
            return queue
        case .none:
            return DispatchQueue.main
        }
    }
}
