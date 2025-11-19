//
//  InternalAtomic.swift
//  SendbirdChat
//
//  Created by Kai Lee on 7/13/25.
//

import Foundation

@propertyWrapper
package class InternalAtomic<T> {
    private var internalValue: T
    
    /// Actual value
    package var wrappedValue: T {
        get {
            lock.sync {
                return internalValue
            }
        }
        set {
            lock.sync {
                self.internalValue = newValue
            }
        }
    }
    
    package var projectedValue: InternalAtomic<T> { self }
    
    private let lock: DispatchQueue = {
        var name = "AtomicProperty_\(UUID().uuidString)_\(String(describing: T.self))"
        return DispatchQueue(label: name)
    }()
    
    /// Constructor
    package init(wrappedValue: T) {
        self.internalValue = wrappedValue
    }
    
    package func atomicMutate(_ mutation: (inout T) -> Void) {
        lock.sync {
            mutation(&internalValue)
        }
    }
}
