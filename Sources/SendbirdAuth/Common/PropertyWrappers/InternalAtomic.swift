//
//  InternalAtomic.swift
//  SendbirdChat
//
//  Created by Kai Lee on 7/13/25.
//

import Foundation

@propertyWrapper
@_spi(SendbirdInternal) public class InternalAtomic<T> {
    private var internalValue: T
    
    /// Actual value
    @_spi(SendbirdInternal) public var wrappedValue: T {
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
    
    @_spi(SendbirdInternal) public var projectedValue: InternalAtomic<T> { self }
    
    private let lock: DispatchQueue = {
        var name = "AtomicProperty_\(UUID().uuidString)_\(String(describing: T.self))"
        return DispatchQueue(label: name)
    }()
    
    /// Constructor
    @_spi(SendbirdInternal) public init(wrappedValue: T) {
        self.internalValue = wrappedValue
    }
    
    @_spi(SendbirdInternal) public func atomicMutate(_ mutation: (inout T) -> Void) {
        lock.sync {
            mutation(&internalValue)
        }
    }
}
