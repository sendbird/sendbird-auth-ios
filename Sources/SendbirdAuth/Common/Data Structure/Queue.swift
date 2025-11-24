//
//  Queue.swift
//  SendBirdCalls
//
//  Created by Minhyuk Kim on 2020/09/18.
//  Copyright © 2020 SendBird Inc. All rights reserved.
//

import Foundation

public struct Queue<T> {
    private var elements: [T] = []
    
    public var head: T? { elements.first }
    public var tail: T? { elements.last }
    
    public var count: Int { elements.count }
    public var isEmpty: Bool { elements.isEmpty }
    public var hasElement: Bool { !elements.isEmpty }
    
    public init(contentsOf elements: [T] = []) {
        self.elements = elements
    }
    
    public mutating func enqueue(_ value: T) {
        elements.append(value)
    }
    
    @discardableResult
    public mutating func dequeue() -> T? {
        guard !elements.isEmpty else {
            return nil
        }
        
        return elements.removeFirst()
    }
}
