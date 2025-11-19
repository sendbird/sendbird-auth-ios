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
package final class SafeOrderedDictionary<Key: Hashable & Codable, Value: Equatable> {
    
    private let queue = SafeSerialQueue(label: "com.sendbird.chat.common.safe_ordered_dictionary.\(UUID().uuidString)")
    private var orderedSet: [Key] = []
    private var dictionary: [Key: Value] = [:]
    
    package init() { }
    
    package init<S: Sequence>(_ sequence: S) where S.Iterator.Element == (key: Key, value: Value) {
        for (key, value) in sequence {
            add(value, forKey: key)
        }
    }
    
    private init(orderedSet: [Key], dictionary: [Key: Value]) {
        self.orderedSet = orderedSet
        self.dictionary = dictionary
    }
    
    package subscript(key: Key) -> Value? {
        get {
            queue.sync { return dictionary[key] }
        }
        set {
            queue.sync { dictionary[key] = newValue }
        }
    }
    
    package func add(_ object: Value, forKey key: Key) {
        queue.sync {
            if dictionary[key] == nil {
                orderedSet.append(key)
                dictionary[key] = object
            } else {
                dictionary[key] = object
            }
        }
    }
    
    package func add<S: Sequence>(_ sequence: S) where S.Iterator.Element == (key: Key, value: Value) {
        for (key, value) in sequence {
            add(value, forKey: key)
        }
    }
    
    package func insert(_ object: Value, forKey key: Key, at index: Int) {
        precondition(index < orderedSet.count, "out of bound")
        
        queue.sync {
            orderedSet.insert(key, at: index)
            dictionary[key] = object
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
            guard let index = orderedSet.firstIndex(where: { $0 == key }) else {
                return nil // key not found
            }
            
            orderedSet.remove(at: index)
            return dictionary.removeValue(forKey: key)
        }
    }
    
    package func removeAll() {
        queue.sync {
            orderedSet = []
            dictionary = [:]
        }
    }
    
    package func popFirst() -> (key: Key, value: Value)? {
        return queue.sync {
            guard let key = orderedSet.first, let value = dictionary[key] else {
                return nil
            }
            
            remove(forKey: key)
            return (key: key, value: value)
        }
    }
    
    package func popLast() -> (key: Key, value: Value)? {
        return queue.sync {
            guard let key = orderedSet.last, let value = dictionary[key] else {
                return nil
            }
            
            remove(forKey: key)
            return (key: key, value: value)
        }
    }
    
    package func contains(key: Key) -> Bool {
        queue.sync {
            orderedSet.contains(key) && dictionary[key] != nil
        }
    }
    
    package func toDictionary() -> [Key: Value] {
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
    package var description: String { String(describing: toDictionary()) }
}

extension SafeOrderedDictionary: ExpressibleByDictionaryLiteral {
    package convenience init(dictionaryLiteral elements: (Key, Value)...) {
        self.init(elements.map { (key: $0.0, value: $0.1) })
    }
}

extension SafeOrderedDictionary : Codable where Key: Codable, Value: Codable {
    package func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        let wrapper = OrderedDictionaryCodingWrapper(orderedSet: orderedSet, dictionary: dictionary)
        try container.encode(wrapper)
    }
    
    package convenience init(from decoder: Decoder) throws {
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
    package typealias Index = OrderedDictionaryIndex

    package var startIndex: Index { Index(position: orderedSet.startIndex) }
    
    package var endIndex: Index { Index(position: orderedSet.endIndex) }
    
    package subscript (position: Index) -> Iterator.Element {
        precondition(position.position < orderedSet.count, "out of bounds")
        let key = orderedSet[position.position]
        guard let value = dictionary[key] else {
            fatalError("Inconsistent state: Key exists in orderedSet but not in dictionary")
        }
        return (key, value)
    }

    package func index(after i: Index) -> Index {
        return Index(position: i.position + 1)
    }
    
    package var values: [Value] {
        queue.sync {
            orderedSet.compactMap { key in
                dictionary[key]
            }
        }
    }
    
    package var keys: [Key] {
        queue.sync {
            return orderedSet
        }
    }
}

extension SafeOrderedDictionary: Equatable {
    package static func == (lhs: SafeOrderedDictionary<Key, Value>, rhs: SafeOrderedDictionary<Key, Value>) -> Bool {
        lhs.orderedSet == rhs.orderedSet && lhs.dictionary == rhs.dictionary
    }
}

extension SafeOrderedDictionary: Sequence {
    package typealias Iterator = OrderedDictionaryIterator<Key, Value>

    package func makeIterator() -> OrderedDictionaryIterator<Key, Value> {
        return OrderedDictionaryIterator(orderedSet, values: dictionary)
    }
}

package struct OrderedDictionaryIterator<Key: Hashable, Value>: IteratorProtocol {
    private let values: [Key: Value]
    private let ordered: [Key]
    private var index: Int

    package init(_ ordered: [Key], values: [Key: Value]) {
        self.ordered = ordered
        self.values = values
        self.index = -1  // -1에서 시작하여 next()에서 증가
    }
    
    package mutating func next() -> (Key, Value)? {
        index += 1
        guard index < ordered.count else { return nil }
        
        let key = ordered[index]
        return values[key].map { (key, $0) }
    }
}

package struct OrderedDictionaryIndex {
    fileprivate let position: Int
}

extension OrderedDictionaryIndex: Comparable {
    package static func == (lhs: OrderedDictionaryIndex, rhs: OrderedDictionaryIndex) -> Bool {
        return lhs.position == rhs.position
    }
    
    package static func < (lhs: OrderedDictionaryIndex, rhs: OrderedDictionaryIndex) -> Bool {
        return lhs.position < rhs.position
    }
}

// swiftlint:enable all
