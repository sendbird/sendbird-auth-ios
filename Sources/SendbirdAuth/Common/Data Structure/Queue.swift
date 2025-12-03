//
//  Queue.swift
//  SendBirdCalls
//
//  Created by Minhyuk Kim on 2020/09/18.
//  Copyright © 2020 SendBird Inc. All rights reserved.
//

import Foundation

@_spi(SendbirdInternal) public struct Queue<T> {
    private var elements: [T] = []
    
    @_spi(SendbirdInternal) public var head: T? { elements.first }
    @_spi(SendbirdInternal) public var tail: T? { elements.last }
    
    @_spi(SendbirdInternal) public var count: Int { elements.count }
    @_spi(SendbirdInternal) public var isEmpty: Bool { elements.isEmpty }
    @_spi(SendbirdInternal) public var hasElement: Bool { !elements.isEmpty }
    
    @_spi(SendbirdInternal) public init(contentsOf elements: [T] = []) {
        self.elements = elements
    }
    
    @_spi(SendbirdInternal) public mutating func enqueue(_ value: T) {
        elements.append(value)
    }
    
    @discardableResult
    @_spi(SendbirdInternal) public mutating func dequeue() -> T? {
        guard !elements.isEmpty else {
            return nil
        }
        
        return elements.removeFirst()
    }
}
