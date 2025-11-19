//
//  DependencyWrapper.swift
//  SendbirdChat
//
//  Created by Kai Lee on 6/16/25.
//

@propertyWrapper
package struct DependencyWrapper<T> {
    package var isResolved: Bool = false
    private var value: T?
    
    package var wrappedValue: T? {
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
    
    package init() {
        self.isResolved = false
        self.value = nil
    }
}
