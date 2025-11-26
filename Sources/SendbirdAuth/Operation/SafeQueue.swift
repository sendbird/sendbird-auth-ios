//
//  SafeQueue.swift
//  SendbirdChat
//
//  Created by Minhyuk Kim on 2022/03/13.
//

import Foundation

@_spi(SendbirdInternal) public class SafeSerialQueue {
    private var queueKey: DispatchSpecificKey<Void>
    @_spi(SendbirdInternal) public var queue: DispatchQueue
    
    @_spi(SendbirdInternal) public init(label: String? = nil, queue: DispatchQueue? = nil) {
        self.queueKey = DispatchSpecificKey<Void>()
        self.queue = queue ?? DispatchQueue(label: label ?? "com.sendbird.chat.common.safequeue.\(UUID().uuidString)")
        
        self.queue.setSpecific(key: queueKey, value: ())
    }
    
    @_spi(SendbirdInternal) public func sync(block: () -> Void) {
        if DispatchQueue.getSpecific(key: queueKey) != nil {
            block()
        } else {
            queue.sync(execute: block)
        }
    }
    
    @_spi(SendbirdInternal) public func sync(block: () throws -> Void) rethrows {
        if DispatchQueue.getSpecific(key: queueKey) != nil {
            try block()
        } else {
            try queue.sync(execute: block)
        }
    }
    
    @_spi(SendbirdInternal) public func sync<T>(block: () -> T) -> T {
        if DispatchQueue.getSpecific(key: queueKey) != nil {
            return block()
        } else {
            return queue.sync(execute: block)
        }
    }
    
    @_spi(SendbirdInternal) public func sync<T>(block: () throws -> T) rethrows -> T {
        if DispatchQueue.getSpecific(key: queueKey) != nil {
            return try block()
        } else {
            return try queue.sync(execute: block)
        }
    }
    
    @_spi(SendbirdInternal) public func async(block: @escaping () -> Void) {
        queue.async(execute: block)
    }
    
    @_spi(SendbirdInternal) public func blockingAsync(block: @escaping () -> Void) {
        if DispatchQueue.getSpecific(key: queueKey) != nil {
            return block()
        } else {
            return queue.async(execute: block)
        }
    }
}
