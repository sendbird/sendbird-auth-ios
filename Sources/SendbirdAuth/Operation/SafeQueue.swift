//
//  SafeQueue.swift
//  SendbirdChat
//
//  Created by Minhyuk Kim on 2022/03/13.
//

import Foundation

public class SafeSerialQueue {
    private var queueKey: DispatchSpecificKey<Void>
    public var queue: DispatchQueue
    
    public init(label: String? = nil, queue: DispatchQueue? = nil) {
        self.queueKey = DispatchSpecificKey<Void>()
        self.queue = queue ?? DispatchQueue(label: label ?? "com.sendbird.chat.common.safequeue.\(UUID().uuidString)")
        
        self.queue.setSpecific(key: queueKey, value: ())
    }
    
    public func sync(block: () -> Void) {
        if DispatchQueue.getSpecific(key: queueKey) != nil {
            block()
        } else {
            queue.sync(execute: block)
        }
    }
    
    public func sync(block: () throws -> Void) rethrows {
        if DispatchQueue.getSpecific(key: queueKey) != nil {
            try block()
        } else {
            try queue.sync(execute: block)
        }
    }
    
    public func sync<T>(block: () -> T) -> T {
        if DispatchQueue.getSpecific(key: queueKey) != nil {
            return block()
        } else {
            return queue.sync(execute: block)
        }
    }
    
    public func sync<T>(block: () throws -> T) rethrows -> T {
        if DispatchQueue.getSpecific(key: queueKey) != nil {
            return try block()
        } else {
            return try queue.sync(execute: block)
        }
    }
    
    public func async(block: @escaping () -> Void) {
        queue.async(execute: block)
    }
    
    public func blockingAsync(block: @escaping () -> Void) {
        if DispatchQueue.getSpecific(key: queueKey) != nil {
            return block()
        } else {
            return queue.async(execute: block)
        }
    }
}
