//
//  OrderedSet.swift
//  SendbirdChat
//
//  Created by Wooyoung Chung on 10/20/21.
//

// swiftlint:disable all

import Foundation

package struct OrderedSet<Element: Hashable> {
    private var elements: [Element] = []
    private var set: Set<Element> = []

    package init() { }
}

package extension OrderedSet {
    init<S>(distinctElements elements: S) where S : Sequence, S.Element == Element {
        self.elements = Array(elements)
        self.set = Set(elements)
        precondition(self.elements.count == self.set.count, "Elements must be distinct")
    }
}

extension OrderedSet: SetAlgebra {
    package func contains(_ member: Element) -> Bool {
        set.contains(member)
    }

    @discardableResult
    package mutating func insert(_ newMember: Element) -> (inserted: Bool, memberAfterInsert: Element) {
        let insertion = set.insert(newMember)
        if insertion.inserted { elements.append(newMember) }
        return insertion
    }

    @discardableResult
    package mutating func remove(_ member: Element) -> Element? {
        if let oldMember = set.remove(member) {
            let index = elements.firstIndex(of: member)!
            elements.remove(at: index)
            return oldMember
        } else {
            return nil
        }
    }

    @discardableResult
    package mutating func update(with newMember: Element) -> Element? {
        if let member = set.update(with: newMember) {
            return member
        } else {
            elements.append(newMember)
            return nil
        }
    }

    package mutating func formUnion(_ other: Self) {
        other.elements.forEach { self.insert($0) }
    }

    package mutating func formIntersection(_ other: Self) {
        for element in elements {
            if !other.contains(element) {
                remove(element)
            }
        }
    }

    package mutating func formSymmetricDifference(_ other: Self) {
        for member in other.elements {
            if set.contains(member) {
                remove(member)
            } else {
                insert(member)
            }
        }
    }

    package func union(_ other: Self) -> Self {
        var orderedSet = self
        orderedSet.formUnion(other)
        return orderedSet
    }

    package func intersection(_ other: Self) -> Self {
        var orderedSet = self
        orderedSet.formIntersection(other)
        return orderedSet
    }

    package func symmetricDifference(_ other: Self) -> Self {
        var orderedSet = self
        orderedSet.formSymmetricDifference(other)
        return orderedSet
    }

    package init<S>(_ elements: S) where S : Sequence, S.Element == Element {
        elements.forEach { insert($0) }
    }
}

extension OrderedSet: CustomStringConvertible {
    package var description: String { elements.description }
}

extension OrderedSet: MutableCollection, RandomAccessCollection {
    package typealias Index = Int
    package typealias SubSequence = OrderedSet

    package subscript(index: Index) -> Element {
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

    package subscript(bounds: Range<Index>) -> SubSequence {
        get {
            return OrderedSet(distinctElements: elements[bounds])
        }
        set {
            replaceSubrange(bounds, with: newValue.elements)
        }

    }
    package var startIndex: Index { elements.startIndex }
    package var endIndex:   Index { elements.endIndex }

    package var isEmpty: Bool { elements.isEmpty }
}

package extension OrderedSet {
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

package extension OrderedSet where Element : Comparable {
    mutating func sort() {
        elements.sort()
    }
}

extension OrderedSet: RangeReplaceableCollection {
    package mutating func replaceSubrange<C>(_ subrange: Range<Index>, with newElements: C) where C : Collection, C.Element == Element {
        set.subtract(elements[subrange])
        let insertedElements = newElements.filter {
            set.insert($0).inserted
        }
        elements.replaceSubrange(subrange, with: insertedElements)
    }
}

// swiftlint:enable all
