//
//  BoundedRange.swift
//  SendbirdChat
//
//  Created by Minhyuk Kim on 2022/02/18.
//

import Foundation

/// A property wrapper that bounds a constant value to a fixed set of range.
/// - Properties:
///     - `propertyName`: if non-nil, a warning log is printed indicating that the value is changed when it is out of bounded range.
///     - `defaultValue`: if non-nil, the default value is static. Otherwise, default value is either min or max.
///     - `projectedValue`:  Mutable tuple that designates the minimum and maximum bound of the property. Used for testing purposes.
@propertyWrapper
@_spi(SendbirdInternal) public struct BoundedRange<T: AdditiveArithmetic & Comparable> {
    let propertyName: String?
    var max: T
    var min: T
    let defaultValue: T?
    
    var internalValue: T
    @_spi(SendbirdInternal) public var wrappedValue: T {
        get { internalValue }
        set {
            if isFromDecodable {
                internalValue = newValue
            } else {
                if newValue < min || newValue > max {
                    let enforcedValue = defaultValue != nil ? defaultValue! : (newValue < min ? min : max)
                    internalValue = enforcedValue
                    
                    // Optionally print debug log indicating the change.
//                    if let propertyName = propertyName {
//                        let enforcedTo: String = defaultValue != nil ? "default" : (newValue < min ? "min" : "max")
//                        Logger.external.warning(
//                            """
//                            `\(propertyName)` value is bounded by the range [\(min), \(max)].
//                            Setting `\(propertyName)` to \(enforcedTo) value \(enforcedValue).
//                            """
//                        )
//                    }
                } else {
                    internalValue = newValue
                }
            }
        }
    }
    
    var isFromDecodable: Bool = false

    @_spi(SendbirdInternal) public var projectedValue: (T, T) {
        get {
            (min, max)
        }
        set {
            self.min = newValue.0
            self.max = newValue.1
        }
    }
    
    @_spi(SendbirdInternal) public init(wrappedValue: T, propertyName: String? = nil, min: T = .zero, max: T, defaultValue: T? = nil) {
        self.propertyName = propertyName
        self.max = max
        self.min = min
        self.defaultValue = defaultValue
        self.internalValue = wrappedValue
    }
}

extension BoundedRange: Codable where T: Codable {
    @_spi(SendbirdInternal) public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(internalValue)
    }
    
    @_spi(SendbirdInternal) public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let value = try container.decode(T.self)
        
        self.init(wrappedValue: value, min: .zero, max: .zero, defaultValue: .zero)
        self.isFromDecodable = true
    }
}
