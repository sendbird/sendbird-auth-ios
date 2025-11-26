//
//  ImmutableDependencyWrapper.swift
//  SendbirdChat
//
//  Created by Kai Lee on 7/11/25.
//

@propertyWrapper
@_spi(SendbirdInternal) public struct ImmutableDependencyWrapper<T> {
    @DependencyWrapper private var value: T?
    
    @_spi(SendbirdInternal) public init() {
        self._value = DependencyWrapper<T>()
    }

    @_spi(SendbirdInternal) public var wrappedValue: T? {
        get {
            value
        }
        set {
            if _value.isResolved {
                assertionFailure("The object is already resolved.")
            } else {
                value = newValue
            }
        }
    }
}
