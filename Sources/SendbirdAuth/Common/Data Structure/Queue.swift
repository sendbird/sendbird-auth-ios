//
//  Queue.swift
//  SendBirdCalls
//
//  Created by Minhyuk Kim on 2020/09/18.
//  Copyright © 2020 SendBird Inc. All rights reserved.
//

import Foundation

package struct Queue<T> {
    private var elements: [T] = []
    
    package var head: T? { elements.first }
    package var tail: T? { elements.last }
    
    package var count: Int { elements.count }
    package var isEmpty: Bool { elements.isEmpty }
    package var hasElement: Bool { !elements.isEmpty }
    
    package init(contentsOf elements: [T] = []) {
        self.elements = elements
    }
    
    package mutating func enqueue(_ value: T) {
        elements.append(value)
    }
    
    @discardableResult
    package mutating func dequeue() -> T? {
        guard !elements.isEmpty else {
            return nil
        }
        
        return elements.removeFirst()
    }
}
