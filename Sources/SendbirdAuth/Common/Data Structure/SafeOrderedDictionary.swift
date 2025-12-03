//
//  SafeOrderedDictionary.swift
//  SendbirdChat
//
//  Created by Wooyoung Chung on 9/24/21.
//

import Foundation

// swiftlint:disable all

// @since 3.0.231
// Ordered thread safe dictionary
@_spi(SendbirdInternal) public final class SafeOrderedDictionary<Key: Hashable & Codable, Value: Equatable> {
    
    private let queue = SafeSerialQueue(label: "com.sendbird.chat.common.safe_ordered_dictionary.\(UUID().uuidString)")
    private var orderedSet: [Key] = []
    private var dictionary: [Key: Value] = [:]
    
    @_spi(SendbirdInternal) public init() { }
    
    @_spi(SendbirdInternal) public init<S: Sequence>(_ sequence: S) where S.Iterator.Element == (key: Key, value: Value) {
        for (key, value) in sequence {
            add(value, forKey: key)
        }
    }
    
    private init(orderedSet: [Key], dictionary: [Key: Value]) {
        self.orderedSet = orderedSet
        self.dictionary = dictionary
    }
    
    @_spi(SendbirdInternal) public subscript(key: Key) -> Value? {
        get {
            queue.sync { return dictionary[key] }
        }
        set {
            queue.sync { dictionary[key] = newValue }
        }
    }
    
    @_spi(SendbirdInternal) public func add(_ object: Value, forKey key: Key) {
        queue.sync {
            if dictionary[key] == nil {
                orderedSet.append(key)
                dictionary[key] = object
            } else {
                dictionary[key] = object
            }
        }
    }
    
    @_spi(SendbirdInternal) public func add<S: Sequence>(_ sequence: S) where S.Iterator.Element == (key: Key, value: Value) {
        for (key, value) in sequence {
            add(value, forKey: key)
        }
    }
    
    @_spi(SendbirdInternal) public func insert(_ object: Value, forKey key: Key, at index: Int) {
        precondition(index < orderedSet.count, "out of bound")
        
        queue.sync {
            orderedSet.insert(key, at: index)
            dictionary[key] = object
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
            guard let index = orderedSet.firstIndex(where: { $0 == key }) else {
                return nil // key not found
            }
            
            orderedSet.remove(at: index)
            return dictionary.removeValue(forKey: key)
        }
    }
    
    @_spi(SendbirdInternal) public func removeAll() {
        queue.sync {
            orderedSet = []
            dictionary = [:]
        }
    }
    
    @_spi(SendbirdInternal) public func popFirst() -> (key: Key, value: Value)? {
        return queue.sync {
            guard let key = orderedSet.first, let value = dictionary[key] else {
                return nil
            }
            
            remove(forKey: key)
            return (key: key, value: value)
        }
    }
    
    @_spi(SendbirdInternal) public func popLast() -> (key: Key, value: Value)? {
        return queue.sync {
            guard let key = orderedSet.last, let value = dictionary[key] else {
                return nil
            }
            
            remove(forKey: key)
            return (key: key, value: value)
        }
    }
    
    @_spi(SendbirdInternal) public func contains(key: Key) -> Bool {
        queue.sync {
            orderedSet.contains(key) && dictionary[key] != nil
        }
    }
    
    @_spi(SendbirdInternal) public func toDictionary() -> [Key: Value] {
        queue.sync {
            Dictionary(
                uniqueKeysWithValues: orderedSet.compactMap { key in
                    dictionary[key].map { (key, $0) }
                }
            )
        }
    }
}

extension SafeOrderedDictionary: CustomStringConvertible {
    @_spi(SendbirdInternal) public var description: String { String(describing: toDictionary()) }
}

extension SafeOrderedDictionary: ExpressibleByDictionaryLiteral {
    @_spi(SendbirdInternal) public convenience init(dictionaryLiteral elements: (Key, Value)...) {
        self.init(elements.map { (key: $0.0, value: $0.1) })
    }
}

extension SafeOrderedDictionary : Codable where Key: Codable, Value: Codable {
    @_spi(SendbirdInternal) public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        let wrapper = OrderedDictionaryCodingWrapper(orderedSet: orderedSet, dictionary: dictionary)
        try container.encode(wrapper)
    }
    
    @_spi(SendbirdInternal) public convenience init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        do {
            let wrapper = try container.decode(OrderedDictionaryCodingWrapper<Key, Value>.self)
            self.init(orderedSet: wrapper.orderedSet, dictionary: wrapper.dictionary)
        } catch {
            // Fallback for backward compatibility
            let dictionary = try container.decode([Key: Value].self)
            let orderedSet = Array(dictionary.keys) // Preserve order from Dictionary.keys
            self.init(orderedSet: orderedSet, dictionary: dictionary)
        }
    }
}

/// Wrapper to encode both orderedSet and dictionary to maintain key order.
fileprivate struct OrderedDictionaryCodingWrapper<Key: Hashable & Codable, Value: Codable>: Codable {
    let orderedSet: [Key]
    let dictionary: [Key: Value]
}

extension SafeOrderedDictionary: Collection {
    @_spi(SendbirdInternal) public typealias Index = OrderedDictionaryIndex

    @_spi(SendbirdInternal) public var startIndex: Index { Index(position: orderedSet.startIndex) }
    
    @_spi(SendbirdInternal) public var endIndex: Index { Index(position: orderedSet.endIndex) }
    
    @_spi(SendbirdInternal) public subscript (position: Index) -> Iterator.Element {
        precondition(position.position < orderedSet.count, "out of bounds")
        let key = orderedSet[position.position]
        guard let value = dictionary[key] else {
            fatalError("Inconsistent state: Key exists in orderedSet but not in dictionary")
        }
        return (key, value)
    }

    @_spi(SendbirdInternal) public func index(after i: Index) -> Index {
        return Index(position: i.position + 1)
    }
    
    @_spi(SendbirdInternal) public var values: [Value] {
        queue.sync {
            orderedSet.compactMap { key in
                dictionary[key]
            }
        }
    }
    
    @_spi(SendbirdInternal) public var keys: [Key] {
        queue.sync {
            return orderedSet
        }
    }
}

extension SafeOrderedDictionary: Equatable {
    @_spi(SendbirdInternal) public static func == (lhs: SafeOrderedDictionary<Key, Value>, rhs: SafeOrderedDictionary<Key, Value>) -> Bool {
        lhs.orderedSet == rhs.orderedSet && lhs.dictionary == rhs.dictionary
    }
}

extension SafeOrderedDictionary: Sequence {
    @_spi(SendbirdInternal) public typealias Iterator = OrderedDictionaryIterator<Key, Value>

    @_spi(SendbirdInternal) public func makeIterator() -> OrderedDictionaryIterator<Key, Value> {
        return OrderedDictionaryIterator(orderedSet, values: dictionary)
    }
}

@_spi(SendbirdInternal) public struct OrderedDictionaryIterator<Key: Hashable, Value>: IteratorProtocol {
    private let values: [Key: Value]
    private let ordered: [Key]
    private var index: Int

    @_spi(SendbirdInternal) public init(_ ordered: [Key], values: [Key: Value]) {
        self.ordered = ordered
        self.values = values
        self.index = -1  // -1에서 시작하여 next()에서 증가
    }
    
    @_spi(SendbirdInternal) public mutating func next() -> (Key, Value)? {
        index += 1
        guard index < ordered.count else { return nil }
        
        let key = ordered[index]
        return values[key].map { (key, $0) }
    }
}

@_spi(SendbirdInternal) public struct OrderedDictionaryIndex {
    fileprivate let position: Int
}

extension OrderedDictionaryIndex: Comparable {
    @_spi(SendbirdInternal) public static func == (lhs: OrderedDictionaryIndex, rhs: OrderedDictionaryIndex) -> Bool {
        return lhs.position == rhs.position
    }
    
    @_spi(SendbirdInternal) public static func < (lhs: OrderedDictionaryIndex, rhs: OrderedDictionaryIndex) -> Bool {
        return lhs.position < rhs.position
    }
}

// swiftlint:enable all
