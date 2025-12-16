//
//  DependencyWrapper.swift
//  SendbirdChat
//
//  Created by Kai Lee on 6/16/25.
//

@propertyWrapper
@_spi(SendbirdInternal) public struct DependencyWrapper<T> {
    @_spi(SendbirdInternal) public var isResolved: Bool = false

    private final class WeakBox {
        weak var object: AnyObject?
    }

    private let box = WeakBox()

    @_spi(SendbirdInternal) public var wrappedValue: T? {
        get {
            if isResolved == false {
                assertionFailure("The object is not resolved.")
            }
            return box.object as? T
        }
        set {
            if let object = newValue as? AnyObject {
                self.isResolved = true
                box.object = object
            }
        }
    }

    @_spi(SendbirdInternal) public init() {
        self.isResolved = false
        self.box.object = nil
    }
}
