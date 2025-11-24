//
//  DependencyWrapper.swift
//  SendbirdChat
//
//  Created by Kai Lee on 6/16/25.
//

@propertyWrapper
public struct DependencyWrapper<T> {
    public var isResolved: Bool = false
    private var value: T?
    
    public var wrappedValue: T? {
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
    
    public init() {
        self.isResolved = false
        self.value = nil
    }
}
