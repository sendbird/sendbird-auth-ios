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
package final class SafeDictionary<Key: Hashable & Codable, Value> {
    
    private let queue = SafeSerialQueue(label: "com.sendbird.chat.common.safe_dictionary.\(UUID().uuidString)")
    private var dictionary: [Key: Value] = [:]
    
    package var count: Int {
        queue.sync { dictionary.count }
    }
    
    package var values: [Value] {
        queue.sync { Array(dictionary.values) }
    }
    
    package var keys: [Key] {
        queue.sync { Array(dictionary.keys) }
    }
    
    package subscript(key: Key) -> Value? {
        get {
            queue.sync { dictionary[key] }
        }
        set {
            queue.sync { dictionary[key] = newValue }
        }
    }
    
    package init() { }
    
    package init<S: Sequence>(_ sequence: S) where S.Iterator.Element == (key: Key, value: Value) {
        for (key, value) in sequence {
            add(value, forKey: key)
        }
    }
    
    package func replaceAll(with other: SafeDictionary) {
        queue.sync {
            dictionary = other.toDictionary()
        }
    }
    
    package func replaceAll(with other: [Key: Value]) {
        queue.sync {
            dictionary = other
        }
    }
    
    package func add(_ object: Value, forKey key: Key) {
        queue.sync {
            dictionary[key] = object
        }
    }
    
    package func add<S: Sequence>(_ sequence: S) where S.Iterator.Element == (key: Key, value: Value) {
        for (key, value) in sequence {
            add(value, forKey: key)
        }
    }
    
    package func mergingOverwrite(_ other: [Key: Value]) {
        queue.sync {
            let result = other.merging(self.toDictionary(), uniquingKeysWith: { lhs, _ in return lhs })
            dictionary = result
        }
    }
    
    package func replace(_ object: Value, forKey key: Key) {
        queue.sync {
            guard dictionary[key] != nil else { return }
            dictionary[key] = object
        }
    }
    
    @discardableResult
    package func remove(forKey key: Key) -> Value? {
        return queue.sync {
            return dictionary.removeValue(forKey: key)
        }
    }
    
    package func remove(forKeys keys: [Key]) {
        return queue.sync {
            keys.forEach {
                dictionary.removeValue(forKey: $0)
            }
        }
    }
    
    package func remove(condition: (_ key: Key, _ value: Value?) -> Bool) {
        return queue.sync {
            let keys = Array(dictionary.keys)
            keys.forEach {
                if condition($0, dictionary[$0]) {
                    dictionary.removeValue(forKey: $0)
                }
            }
        }
    }
    
    package func removeAll() {
        queue.sync {
            dictionary = [:]
        }
    }
    
    package func toDictionary() -> [Key: Value] {
        queue.sync {
            dictionary
        }
    }
    
    package func map<T>(_ transform: ((Key, Value)) -> T) -> [T] {
        queue.sync {
            dictionary.map(transform)
        }
    }
    
    package func forEach(_ body: ((key: Key, value: Value)) -> Void) {
        queue.sync {
            dictionary.forEach(body)
        }
    }
}

extension SafeDictionary: CustomStringConvertible {
    package var description: String {
        String(describing: toDictionary())
    }
}

extension SafeDictionary: ExpressibleByDictionaryLiteral {
    package convenience init(dictionaryLiteral elements: (Key, Value)...) {
        self.init(elements.map { (key: $0.0, value: $0.1) })
    }
}

extension SafeDictionary : Encodable where Key : Encodable, Value : Encodable {
    package func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(toDictionary())
    }
}

extension SafeDictionary : Decodable where Key : Decodable, Value : Decodable {
    package convenience init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let dictionary = try container.decode([Key: Value].self)

        self.init(dictionary)
    }
}

extension SafeDictionary: Equatable where Value: Equatable {
    package static func == (lhs: SafeDictionary<Key, Value>, rhs: SafeDictionary<Key, Value>) -> Bool {
        let lhsDictionary = lhs.toDictionary()
        let rhsDictionary = rhs.toDictionary()
        return lhsDictionary == rhsDictionary
    }
}

// swiftlint:enable all
