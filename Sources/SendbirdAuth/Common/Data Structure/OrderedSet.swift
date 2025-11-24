//
//  OrderedSet.swift
//  SendbirdChat
//
//  Created by Wooyoung Chung on 10/20/21.
//

// swiftlint:disable all

import Foundation

public struct OrderedSet<Element: Hashable> {
    private var elements: [Element] = []
    private var set: Set<Element> = []

    public init() { }
}

public extension OrderedSet {
    init<S>(distinctElements elements: S) where S : Sequence, S.Element == Element {
        self.elements = Array(elements)
        self.set = Set(elements)
        precondition(self.elements.count == self.set.count, "Elements must be distinct")
    }
}

extension OrderedSet: SetAlgebra {
    public func contains(_ member: Element) -> Bool {
        set.contains(member)
    }

    @discardableResult
    public mutating func insert(_ newMember: Element) -> (inserted: Bool, memberAfterInsert: Element) {
        let insertion = set.insert(newMember)
        if insertion.inserted { elements.append(newMember) }
        return insertion
    }

    @discardableResult
    public mutating func remove(_ member: Element) -> Element? {
        if let oldMember = set.remove(member) {
            let index = elements.firstIndex(of: member)!
            elements.remove(at: index)
            return oldMember
        } else {
            return nil
        }
    }

    @discardableResult
    public mutating func update(with newMember: Element) -> Element? {
        if let member = set.update(with: newMember) {
            return member
        } else {
            elements.append(newMember)
            return nil
        }
    }

    public mutating func formUnion(_ other: Self) {
        other.elements.forEach { self.insert($0) }
    }

    public mutating func formIntersection(_ other: Self) {
        for element in elements {
            if !other.contains(element) {
                remove(element)
            }
        }
    }

    public mutating func formSymmetricDifference(_ other: Self) {
        for member in other.elements {
            if set.contains(member) {
                remove(member)
            } else {
                insert(member)
            }
        }
    }

    public func union(_ other: Self) -> Self {
        var orderedSet = self
        orderedSet.formUnion(other)
        return orderedSet
    }

    public func intersection(_ other: Self) -> Self {
        var orderedSet = self
        orderedSet.formIntersection(other)
        return orderedSet
    }

    public func symmetricDifference(_ other: Self) -> Self {
        var orderedSet = self
        orderedSet.formSymmetricDifference(other)
        return orderedSet
    }

    public init<S>(_ elements: S) where S : Sequence, S.Element == Element {
        elements.forEach { insert($0) }
    }
}

extension OrderedSet: CustomStringConvertible {
    public var description: String { elements.description }
}

extension OrderedSet: MutableCollection, RandomAccessCollection {
    public typealias Index = Int
    public typealias SubSequence = OrderedSet

    public subscript(index: Index) -> Element {
        get {
            elements[index]
        }
        set {
            if !set.contains(newValue) || elements[index] == newValue {
                set.remove(elements[index])
                set.insert(newValue)
                elements[index] = newValue
            }
        }
    }

    public subscript(bounds: Range<Index>) -> SubSequence {
        get {
            return OrderedSet(distinctElements: elements[bounds])
        }
        set {
            replaceSubrange(bounds, with: newValue.elements)
        }

    }
    public var startIndex: Index { elements.startIndex }
    public var endIndex:   Index { elements.endIndex }

    public var isEmpty: Bool { elements.isEmpty }
}

public extension OrderedSet {
    mutating func swapAt(_ i: Index, _ j: Index) {
        elements.swapAt(i, j)
    }

    mutating func partition(by belongsInSecondPartition: (Element) throws -> Bool) rethrows -> Index {
        try elements.partition(by: belongsInSecondPartition)
    }

    mutating func sort(by areInIncreasingOrder: (Element, Element) throws -> Bool) rethrows {
        try elements.sort(by: areInIncreasingOrder)
    }
}

public extension OrderedSet where Element : Comparable {
    mutating func sort() {
        elements.sort()
    }
}

extension OrderedSet: RangeReplaceableCollection {
    public mutating func replaceSubrange<C>(_ subrange: Range<Index>, with newElements: C) where C : Collection, C.Element == Element {
        set.subtract(elements[subrange])
        let insertedElements = newElements.filter {
            set.insert($0).inserted
        }
        elements.replaceSubrange(subrange, with: insertedElements)
    }
}

// swiftlint:enable all
