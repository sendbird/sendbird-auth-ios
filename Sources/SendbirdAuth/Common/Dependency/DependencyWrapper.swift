//
//  DependencyWrapper.swift
//  SendbirdChat
//
//  Created by Kai Lee on 6/16/25.
//

@propertyWrapper
@_spi(SendbirdInternal) public struct DependencyWrapper<T> {
    @_spi(SendbirdInternal) public var isResolved: Bool = false
    private var value: T?
    
    @_spi(SendbirdInternal) public var wrappedValue: T? {
        get {
            if isResolved == false {
                assertionFailure("The object is not resolved.")
            }
            return value
        }
        set {
            self.isResolved = true
            value = newValue
        }
    }
    
    @_spi(SendbirdInternal) public init() {
        self.isResolved = false
        self.value = nil
    }
}
