//
//  ImmutableDependencyWrapper.swift
//  SendbirdChat
//
//  Created by Kai Lee on 7/11/25.
//

@propertyWrapper
package struct ImmutableDependencyWrapper<T> {
    @DependencyWrapper private var value: T?
    
    package init() {
        self._value = DependencyWrapper<T>()
    }

    package var wrappedValue: T? {
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
