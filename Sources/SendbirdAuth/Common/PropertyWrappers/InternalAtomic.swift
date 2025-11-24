//
//  InternalAtomic.swift
//  SendbirdChat
//
//  Created by Kai Lee on 7/13/25.
//

import Foundation

@propertyWrapper
public class InternalAtomic<T> {
    private var internalValue: T
    
    /// Actual value
    public var wrappedValue: T {
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
    
    public var projectedValue: InternalAtomic<T> { self }
    
    private let lock: DispatchQueue = {
        var name = "AtomicProperty_\(UUID().uuidString)_\(String(describing: T.self))"
        return DispatchQueue(label: name)
    }()
    
    /// Constructor
    public init(wrappedValue: T) {
        self.internalValue = wrappedValue
    }
    
    public func atomicMutate(_ mutation: (inout T) -> Void) {
        lock.sync {
            mutation(&internalValue)
        }
    }
}
