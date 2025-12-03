//
//  SafeDictionary.swift
//  SendbirdChat
//
//  Created by Wooyoung Chung on 9/24/21.
//

import Foundation

// swiftlint:disable all

// @since 3.0.231
// Ordered thread safe dictionary
@_spi(SendbirdInternal) public final class SafeDictionary<Key: Hashable & Codable, Value> {
    
    private let queue = SafeSerialQueue(label: "com.sendbird.chat.common.safe_dictionary.\(UUID().uuidString)")
    private var dictionary: [Key: Value] = [:]
    
    @_spi(SendbirdInternal) public var count: Int {
        queue.sync { dictionary.count }
    }
    
    @_spi(SendbirdInternal) public var values: [Value] {
        queue.sync { Array(dictionary.values) }
    }
    
    @_spi(SendbirdInternal) public var keys: [Key] {
        queue.sync { Array(dictionary.keys) }
    }
    
    @_spi(SendbirdInternal) public subscript(key: Key) -> Value? {
        get {
            queue.sync { dictionary[key] }
        }
        set {
            queue.sync { dictionary[key] = newValue }
        }
    }
    
    @_spi(SendbirdInternal) public init() { }
    
    @_spi(SendbirdInternal) public init<S: Sequence>(_ sequence: S) where S.Iterator.Element == (key: Key, value: Value) {
        for (key, value) in sequence {
            add(value, forKey: key)
        }
    }
    
    @_spi(SendbirdInternal) public func replaceAll(with other: SafeDictionary) {
        queue.sync {
            dictionary = other.toDictionary()
        }
    }
    
    @_spi(SendbirdInternal) public func replaceAll(with other: [Key: Value]) {
        queue.sync {
            dictionary = other
        }
    }
    
    @_spi(SendbirdInternal) public func add(_ object: Value, forKey key: Key) {
        queue.sync {
            dictionary[key] = object
        }
    }
    
    @_spi(SendbirdInternal) public func add<S: Sequence>(_ sequence: S) where S.Iterator.Element == (key: Key, value: Value) {
        for (key, value) in sequence {
            add(value, forKey: key)
        }
    }
    
    @_spi(SendbirdInternal) public func mergingOverwrite(_ other: [Key: Value]) {
        queue.sync {
            let result = other.merging(self.toDictionary(), uniquingKeysWith: { lhs, _ in return lhs })
            dictionary = result
        }
    }
    
    @_spi(SendbirdInternal) public func replace(_ object: Value, forKey key: Key) {
        queue.sync {
            guard dictionary[key] != nil else { return }
            dictionary[key] = object
        }
    }
    
    @discardableResult
    @_spi(SendbirdInternal) public func remove(forKey key: Key) -> Value? {
        return queue.sync {
            return dictionary.removeValue(forKey: key)
        }
    }
    
    @_spi(SendbirdInternal) public func remove(forKeys keys: [Key]) {
        return queue.sync {
            keys.forEach {
                dictionary.removeValue(forKey: $0)
            }
        }
    }
    
    @_spi(SendbirdInternal) public func remove(condition: (_ key: Key, _ value: Value?) -> Bool) {
        return queue.sync {
            let keys = Array(dictionary.keys)
            keys.forEach {
                if condition($0, dictionary[$0]) {
                    dictionary.removeValue(forKey: $0)
                }
            }
        }
    }
    
    @_spi(SendbirdInternal) public func removeAll() {
        queue.sync {
            dictionary = [:]
        }
    }
    
    @_spi(SendbirdInternal) public func toDictionary() -> [Key: Value] {
        queue.sync {
            dictionary
        }
    }
    
    @_spi(SendbirdInternal) public func map<T>(_ transform: ((Key, Value)) -> T) -> [T] {
        queue.sync {
            dictionary.map(transform)
        }
    }
    
    @_spi(SendbirdInternal) public func forEach(_ body: ((key: Key, value: Value)) -> Void) {
        queue.sync {
            dictionary.forEach(body)
        }
    }
}

extension SafeDictionary: CustomStringConvertible {
    @_spi(SendbirdInternal) public var description: String {
        String(describing: toDictionary())
    }
}

extension SafeDictionary: ExpressibleByDictionaryLiteral {
    @_spi(SendbirdInternal) public convenience init(dictionaryLiteral elements: (Key, Value)...) {
        self.init(elements.map { (key: $0.0, value: $0.1) })
    }
}

extension SafeDictionary : Encodable where Key : Encodable, Value : Encodable {
    @_spi(SendbirdInternal) public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(toDictionary())
    }
}

extension SafeDictionary : Decodable where Key : Decodable, Value : Decodable {
    @_spi(SendbirdInternal) public convenience init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let dictionary = try container.decode([Key: Value].self)

        self.init(dictionary)
    }
}

extension SafeDictionary: Equatable where Value: Equatable {
    @_spi(SendbirdInternal) public static func == (lhs: SafeDictionary<Key, Value>, rhs: SafeDictionary<Key, Value>) -> Bool {
        let lhsDictionary = lhs.toDictionary()
        let rhsDictionary = rhs.toDictionary()
        return lhsDictionary == rhsDictionary
    }
}

// swiftlint:enable all
