//
//  SortedArray.swift
//  SendbirdChat
//
//  Created by Wooyoung Chung on 9/27/21.
//

// swiftlint:disable all

import Foundation

public protocol SortableElement: Codable, AnyObject {
    var uniqueKey: AnyHashable? { get }
}
/// An array that keeps its elements sorted at all times.
public struct SortedArray<T: SortableElement> {
    /// The backing store
    public var elements: [T]

    public typealias Comparator<A> = (A, A) -> Bool

    public let queue = SafeSerialQueue(label: "com.sendbird.core.SortedArray_\(UUID().uuidString)")
    
    /// The predicate that determines the array's sort order.
    fileprivate let areInIncreasingOrder: Comparator<T>

    public init(areInIncreasingOrder: @escaping Comparator<T>) {
        self.elements = []
        self.areInIncreasingOrder = areInIncreasingOrder
    }

    public init<S: Sequence>(unsorted: S, areInIncreasingOrder: @escaping Comparator<T>) where S.Element == T {
        let sorted = unsorted.sorted(by: areInIncreasingOrder)
        self.elements = sorted
        self.areInIncreasingOrder = areInIncreasingOrder
    }

    public init<S: Sequence>(sorted: S, areInIncreasingOrder: @escaping Comparator<T>) where S.Element == T {
        self.elements = Array(sorted)
        self.areInIncreasingOrder = areInIncreasingOrder
    }

    /// Inserts a new element into the array, preserving the sort order.
    ///
    /// - Returns: the index where the new element was inserted.
    /// - Complexity: O(_n_) where _n_ is the size of the array. O(_log n_) if the new
    /// element can be appended, i.e. if it is ordered last in the resulting array.
    @discardableResult
    public mutating func insert(_ newElement: T) -> Index {
        let index = insertionIndex(for: newElement)
        // This should be O(1) if the element is to be inserted at the end,
        // O(_n) in the worst case (inserted at the front).
        queue.sync {
            elements.insert(newElement, at: index)
        }
        
        return index
    }

    /// Inserts all elements from `elements` into `self`, preserving the sort order.
    ///
    /// This can be faster than inserting the individual elements one after another because
    /// we only need to re-sort once.
    ///
    /// - Complexity: O(_n * log(n)_) where _n_ is the size of the resulting array.
    public mutating func insert<S: Sequence>(contentsOf newElements: S) where S.Element == T {
        queue.sync {
            elements.append(contentsOf: newElements)
            elements.sort(by: areInIncreasingOrder)
        }
    }
}

extension SortedArray {
    @discardableResult
    public mutating func insertIfNotExist(elements: [T]) -> [T] {
        queue.sync {
            let existingKeys = Set(self.elements.compactMap { $0.uniqueKey })
            var insertedElementKeys = Set<AnyHashable>()

            var nonIntersections: [T] = []
            for element in elements {
                guard let key = element.uniqueKey else { continue }
                
                if existingKeys.contains(key) == false &&
                    insertedElementKeys.contains(key) == false {
                    insertedElementKeys.insert(key)
                    
                    nonIntersections.append(element)
                }
            }
            
            insert(contentsOf: nonIntersections)

            return nonIntersections
        }
    }

    /// Updated a message.
    /// - Parameter message Message to be updated.
    /// - Returns `true` if the message is updated.
    public mutating func updateIfExist(_ element: T) -> Bool {
        queue.sync {
            let index = self.elements.firstIndex(where: { $0.uniqueKey == element.uniqueKey })
            if let index = index {
                self.elements[index] = element
                return true
            }
            return false
        }
    }
    
    public mutating func updateIfExist(elements: [T]) -> Bool {
        var updated = false
        for element in elements {
            updated = updated || self.updateIfExist(element)
        }
        
        return updated
    }
}

public extension SortedArray where T: Comparable {
    init() {
        self.init(areInIncreasingOrder: <)
    }

    /// Initializes the array with a sequence of unsorted elements. Uses `<` as the comparison predicate.
    init<S: Sequence>(unsorted: S) where S.Element == T {
        self.init(unsorted: unsorted, areInIncreasingOrder: <)
    }

    /// Initializes the array with a sequence that is already sorted according to the `<` comparison predicate. Uses `<` as the comparison predicate.
    ///
    /// This is faster than `init(unsorted:)` because the elements don't have to sorted again.
    ///
    /// - Precondition: `sorted` is sorted according to the `<` predicate. If you violate this condition, the behavior is undefined.
    init<S: Sequence>(sorted: S) where S.Element == T {
        self.init(sorted: sorted, areInIncreasingOrder: <)
    }
}

extension SortedArray: RandomAccessCollection {
    public typealias Index = Int

    public var startIndex: Index { return elements.startIndex }
    public var endIndex: Index { return elements.endIndex }

    public func index(after i: Index) -> Index {
        queue.sync {
            return elements.index(after: i)
        }
    }

    public func index(before i: Index) -> Index {
        queue.sync {
            return elements.index(before: i)
        }
    }

    public subscript(position: Index) -> T {
        queue.sync {
            return elements[position]
        }
    }
}

public extension SortedArray {
    /// Like `Sequence.filter(_:)`, but returns a `SortedArray` instead of an `Array`.
    /// We can do this efficiently because filtering doesn't change the sort order.
    func filter(_ isIncluded: (T) throws -> Bool) rethrows -> SortedArray {
        let newElements: [T] = try queue.sync {
            return try elements.filter(isIncluded)
        }
        return SortedArray(sorted: newElements, areInIncreasingOrder: areInIncreasingOrder)
    }
}

extension SortedArray: CustomStringConvertible, CustomDebugStringConvertible {
    public var description: String {
        return "\(String(describing: elements)) (sorted)"
    }

    public var debugDescription: String {
        return "<SortedArray> \(String(reflecting: elements))"
    }
}

// MARK: - Removing elements. This is mostly a reimplementation of part `RangeReplaceableCollection`'s interface. `SortedArray` can't conform to `RangeReplaceableCollection` because some of that protocol's semantics (e.g. `append(_:)` don't fit `SortedArray`'s semantics.
public extension SortedArray {
    /// Removes and returns the element at the specified position.
    ///
    /// - Parameter index: The position of the element to remove. `index` must be a valid index of the array.
    /// - Returns: The element at the specified index.
    /// - Complexity: O(_n_), where _n_ is the length of the array.
    @discardableResult
    mutating func remove(at index: Int) -> T {
        queue.sync {
            return elements.remove(at: index)
        }
    }

    /// Removes the elements in the specified subrange from the array.
    ///
    /// - Parameter bounds: The range of the array to be removed. The
    ///   bounds of the range must be valid indices of the array.
    ///
    /// - Complexity: O(_n_), where _n_ is the length of the array.
    mutating func removeSubrange(_ bounds: Range<Int>) {
        queue.sync {
            elements.removeSubrange(bounds)
        }
    }

    /// Removes the elements in the specified subrange from the array.
    ///
    /// - Parameter bounds: The range of the array to be removed. The
    ///   bounds of the range must be valid indices of the array.
    ///
    /// - Complexity: O(_n_), where _n_ is the length of the array.
    mutating func removeSubrange(_ bounds: ClosedRange<Int>) {
        queue.sync {
            elements.removeSubrange(bounds)
        }
    }

    /// Removes the specified number of elements from the beginning of the
    /// array.
    ///
    /// - Parameter n: The number of elements to remove from the array.
    ///   `n` must be greater than or equal to zero and must not exceed the
    ///   number of elements in the array.
    ///
    /// - Complexity: O(_n_), where _n_ is the length of the array.
    mutating func removeFirst(_ n: Int) {
        queue.sync {
            elements.removeFirst(n)
        }
    }

    /// Removes and returns the first element of the array.
    ///
    /// - Precondition: The array must not be empty.
    /// - Returns: The removed element.
    /// - Complexity: O(_n_), where _n_ is the length of the collection.
    @discardableResult
    mutating func removeFirst() -> T {
        queue.sync {
            return elements.removeFirst()
        }
    }

    /// Removes and returns the last element of the array.
    ///
    /// - Precondition: The collection must not be empty.
    /// - Returns: The last element of the collection.
    /// - Complexity: O(1)
    @discardableResult
    mutating func removeLast() -> T {
        queue.sync {
            return elements.removeLast()
        }
    }

    /// Removes the given number of elements from the end of the array.
    ///
    /// - Parameter n: The number of elements to remove. `n` must be greater
    ///   than or equal to zero, and must be less than or equal to the number of
    ///   elements in the array.
    /// - Complexity: O(1).
    mutating func removeLast(_ n: Int) {
        queue.sync {
            elements.removeLast(n)
        }
    }

    /// Removes all elements from the array.
    ///
    /// - Parameter keepCapacity: Pass `true` to keep the existing capacity of
    ///   the array after removing its elements. The default value is `false`.
    ///
    /// - Complexity: O(_n_), where _n_ is the length of the array.
    mutating func removeAll(keepingCapacity keepCapacity: Bool = true) {
        queue.sync {
            elements.removeAll(keepingCapacity: keepCapacity)
        }
    }

    /// Removes an element from the array. If the array contains multiple
    /// instances of `element`, this method only removes the first one.
    ///
    /// - Complexity: O(_n_), where _n_ is the size of the array.
    mutating func remove(_ element: T) {
        guard let index = index(of: element) else { return }
        queue.sync {
            _ = elements.remove(at: index)
        }
    }
    
    func toCopyList() -> [T] {
        var copied: [T] = []
        queue.sync {
            copied = Array(elements)
        }
        return copied
    }
    
    func toList() -> [T] {
        queue.sync {
            return elements
        }
    }
}

// MARK: - More efficient variants of default implementations or implementations that need fewer constraints than the default implementations.
public extension SortedArray {
    /// Returns the first index where the specified value appears in the collection.
    ///
    /// - Complexity: O(_log(n)_), where _n_ is the size of the array.
    func firstIndex(of element: T) -> Index? {
        queue.sync {
            var range: Range<Index> = startIndex ..< endIndex
            var match: Index? = nil
            while case let .found(m) = search(for: element, in: range) {
                // We found a matching element
                // Check if its predecessor also matches
                if let predecessor = index(m, offsetBy: -1, limitedBy: range.lowerBound),
                   compare(self[predecessor], element) == .orderedSame
                {
                    // Predecessor matches => continue searching using binary search
                    match = predecessor
                    range = range.lowerBound ..< predecessor
                }
                else {
                    // We're done
                    match = m
                    break
                }
            }
            return match
        }
    }
    
    /// Returns the first index in which an element of the collection satisfies the given predicate.
    ///
    /// - Requires: The `predicate` must return `false` for elements of the array up to a given point, and `true` for
    ///   all elements after that point _(the opposite of `lastIndex(where:)`)_.
    ///   The given point may be before the first element or after the last element; i.e. it is valid to return `true`
    ///   for all elements or `false` for all elements.
    ///   For most use-cases, the `predicate` closure will use the form `{ $0 > … }` or `{ $0 >= … }` _(or equivalent,
    ///   if the SortedArray was initialized with a custom Comparator)_.
    ///
    /// - Complexity: O(_log(n)_), where _n_ is the size of the array.
    func firstIndex(where predicate: (T) throws -> Bool) rethrows -> Index? {
        var match: Index? = nil
        if case let .found(m) = try searchFirst(where: predicate) {
            match = m
        }
        return match
    }
    
    /// Returns the first element of the sequence that satisfies the given predicate.
    ///
    /// - Requires: The `predicate` must return `false` for elements of the array up to a given point, and `true` for
    ///   all elements after that point _(the opposite of `last(where:)`)_.
    ///   The given point may be before the first element or after the last element; i.e. it is valid to return `true`
    ///   for all elements or `false` for all elements.
    ///   For most use-cases, the `predicate` closure will use the form `{ $0 > … }` or `{ $0 >= … }` _(or equivalent,
    ///   if the SortedArray was initialized with a custom Comparator)_.
    ///
    /// - Complexity: O(_log(n)_), where _n_ is the size of the array.
    func first(where predicate: (T) throws -> Bool) rethrows -> T? {
        guard let index = try firstIndex(where: predicate) else { return nil }
        return self[index]
    }

    /// Returns the first index where the specified value appears in the collection.
    /// Old name for `firstIndex(of:)`.
    /// - Seealso: `firstIndex(of:)`
    func index(of element: T) -> Index? {
        return firstIndex(of: element)
    }

    /// Returns a Boolean value indicating whether the sequence contains the given element.
    ///
    /// - Complexity: O(_log(n)_), where _n_ is the size of the array.
    func contains(_ element: T) -> Bool {
        queue.sync {
            return anyIndex(of: element) != nil
        }
    }

    /// Returns the minimum element in the sequence.
    ///
    /// - Complexity: O(1).
    @warn_unqualified_access
    func min() -> T? {
        var retVal: T?
        queue.sync {
            retVal = first
        }
        return retVal
    }

    /// Returns the maximum element in the sequence.
    ///
    /// - Complexity: O(1).
    @warn_unqualified_access
    func max() -> T? {
        var retVal: T?
        queue.sync {
            retVal = last
        }
        return retVal
    }
}

// MARK: - APIs that go beyond what's in the stdlib
public extension SortedArray {
    /// Returns an arbitrary index where the specified value appears in the collection.
    /// Like `index(of:)`, but without the guarantee to return the *first* index
    /// if the array contains duplicates of the searched element.
    ///
    /// Can be slightly faster than `index(of:)`.
    func anyIndex(of element: T) -> Index? {
        switch search(for: element) {
        case let .found(at: index): return index
        case .notFound(insertAt: _): return nil
        }
    }

    /// Returns the last index where the specified value appears in the collection.
    ///
    /// - Complexity: O(_log(n)_), where _n_ is the size of the array.
    func lastIndex(of element: T) -> Index? {
        var range: Range<Index> = startIndex ..< endIndex
        var match: Index? = nil
        while case let .found(m) = search(for: element, in: range) {
            // We found a matching element
            // Check if its successor also matches
            let lastValidIndex = index(before: range.upperBound)
            if let successor = index(m, offsetBy: 1, limitedBy: lastValidIndex),
                compare(self[successor], element) == .orderedSame
            {
                // Successor matches => continue searching using binary search
                match = successor
                guard let afterSuccessor = index(successor, offsetBy: 1, limitedBy: lastValidIndex) else {
                    break
                }
                range =  afterSuccessor ..< range.upperBound
            }
            else {
                // We're done
                match = m
                break
            }
        }
        return match
    }
    
    /// Returns the index of the last element in the collection that matches the given predicate.
    ///
    /// - Requires: The `predicate` must return `true` for elements of the array up to a given point, and `false` for
    ///   all elements after that point _(the opposite of `firstIndex(where:)`)_.
    ///   The given point may be before the first element or after the last element; i.e. it is valid to return `true`
    ///   for all elements or `false` for all elements.
    ///   For most use-cases, the `predicate` closure will use the form `{ $0 < … }` or `{ $0 <= … }` _(or equivalent,
    ///   if the SortedArray was initialized with a custom Comparator)_.
    ///
    /// - Complexity: O(_log(n)_), where _n_ is the size of the array.
    func lastIndex(where predicate: (T) throws -> Bool) rethrows -> Index? {
        var match: Index? = nil
        if case let .found(m) = try searchLast(where: predicate) {
            match = m
        }
        return match
    }
    
    /// Returns the last element of the sequence that satisfies the given predicate.
    ///
    /// - Requires: The `predicate` must return `true` for elements of the array up to a given point, and `false` for
    ///   all elements after that point _(the opposite of `first(where:)`)_.
    ///   The given point may be before the first element or after the last element; i.e. it is valid to return `true`
    ///   for all elements or `false` for all elements.
    ///   For most use-cases, the `predicate` closure will use the form `{ $0 < … }` or `{ $0 <= … }` _(or equivalent,
    ///   if the SortedArray was initialized with a custom Comparator)_.
    ///
    /// - Complexity: O(_log(n)_), where _n_ is the size of the array.
    func last(where predicate: (T) throws -> Bool) rethrows -> T? {
        guard let index = try firstIndex(where: predicate) else { return nil }
        return self[index]
    }
}

// MARK: - Converting between a stdlib comparator function and Foundation.ComparisonResult
public extension SortedArray {
    fileprivate func compare(_ lhs: T, _ rhs: T) -> Foundation.ComparisonResult {
        if areInIncreasingOrder(lhs, rhs) {
            return .orderedAscending
        } else if areInIncreasingOrder(rhs, lhs) {
            return .orderedDescending
        } else {
            // If neither element comes before the other, they _must_ be
            // equal, per the strict ordering requirement of `areInIncreasingOrder`.
            return .orderedSame
        }
    }
}

// MARK: - Binary search
public extension SortedArray {
    /// The index where `newElement` should be inserted to preserve the array's sort order.
    fileprivate func insertionIndex(for newElement: T) -> Index {
        switch search(for: newElement) {
        case let .found(at: index): return index
        case let .notFound(insertAt: index): return index
        }
    }
}

fileprivate enum Match<Index: Comparable> {
    case found(at: Index)
    case notFound(insertAt: Index)
}

public extension Range where Bound == Int {
    var middle: Int? {
        guard !isEmpty else { return nil }
        return lowerBound + count / 2
    }
}

public extension SortedArray {
    /// Searches the array for `element` using binary search.
    ///
    /// - Returns: If `element` is in the array, Returns `.found(at: index)`
    ///   where `index` is the index of the element in the array.
    ///   If `element` is not in the array, Returns `.notFound(insertAt: index)`
    ///   where `index` is the index where the element should be inserted to
    ///   preserve the sort order.
    ///   If the array contains multiple elements that are equal to `element`,
    ///   there is no guarantee which of these is found.
    ///
    /// - Complexity: O(_log(n)_), where _n_ is the size of the array.
    fileprivate func search(for element: T) -> Match<Index> {
        return search(for: element, in: startIndex ..< endIndex)
    }

    fileprivate func search(for element: T, in range: Range<Index>) -> Match<Index> {
        guard let middle = range.middle else { return .notFound(insertAt: range.upperBound) }
        switch compare(element, self[middle]) {
        case .orderedDescending:
            return search(for: element, in: index(after: middle)..<range.upperBound)
        case .orderedAscending:
            return search(for: element, in: range.lowerBound..<middle)
        case .orderedSame:
            return .found(at: middle)
        }
    }
    
    /// Searches the array for the first element matching the `predicate` using binary search.
    ///
    /// - Requires: The `predicate` must return `false` for elements of the array up to a given point, and `true` for
    ///   all elements after that point _(the opposite of `searchLast(where:)`)_.
    ///   The given point may be before the first element or after the last element; i.e. it is valid to return `true`
    ///   for all elements or `false` for all elements.
    ///   For most use-cases, the `predicate` closure will use the form `{ $0 > … }` or `{ $0 >= … }` _(or equivalent,
    ///   if the SortedArray was initialized with a custom Comparator)_.
    ///
    /// - Parameter predicate: A closure that Returns `false` for elements up to a point; and `true` for all after.
    /// - Returns: If `element` is in the array, Returns `.found(at: index)`
    ///   where `index` is the index of the element in the array.
    ///   If `element` is not in the array, Returns `.notFound(insertAt: index)`
    ///   where `index` is the index where the element should be inserted to
    ///   preserve the sort order.
    ///   If the array contains multiple elements that are equal to `element`,
    ///   there is no guarantee which of these is found.
    ///
    /// - Complexity: O(_log(n)_), where _n_ is the size of the array.
    /// - SeeAlso: http://ruby-doc.org/core-2.6.3/Array.html#method-i-bsearch_index
    fileprivate func searchFirst(where predicate: (T) throws -> Bool) rethrows -> Match<Index> {
        return try searchFirst(where: predicate, in: startIndex ..< endIndex)
    }

    fileprivate func searchFirst(where predicate: (T) throws -> Bool, in range: Range<Index>) rethrows -> Match<Index> {
        guard let middle = range.middle else { return .notFound(insertAt: range.upperBound) }
        if try predicate(self[middle]) {
            if middle == 0 {
                return .found(at: middle)
            } else if !(try predicate(self[index(before: middle)])) {
                return .found(at: middle)
            } else {
                return try searchFirst(where: predicate, in: range.lowerBound ..< middle)
            }
        } else {
            return try searchFirst(where: predicate, in: index(after: middle) ..< range.upperBound)
        }
    }
    
    /// Searches the array for the last element matching the `predicate` using binary search.
    ///
    /// - Requires: The `predicate` must return `true` for elements of the array up to a given point, and `false` for
    ///   all elements after that point _(the opposite of `searchFirst(where:)`)_.
    ///   The given point may be before the first element or after the last element; i.e. it is valid to return `true`
    ///   for all elements or `false` for all elements.
    ///   For most use-cases, the `predicate` closure will use the form `{ $0 < … }` or `{ $0 <= … }` _(or equivalent,
    ///   if the SortedArray was initialized with a custom Comparator)_.
    ///
    /// - Parameter predicate: A closure that Returns `false` for elements up to a point; and `true` for all after.
    /// - Returns: If `element` is in the array, Returns `.found(at: index)`
    ///   where `index` is the index of the element in the array.
    ///   If `element` is not in the array, Returns `.notFound(insertAt: index)`
    ///   where `index` is the index where the element should be inserted to
    ///   preserve the sort order.
    ///   If the array contains multiple elements that are equal to `element`,
    ///   there is no guarantee which of these is found.
    ///
    /// - Complexity: O(_log(n)_), where _n_ is the size of the array.
    /// - SeeAlso: http://ruby-doc.org/core-2.6.3/Array.html#method-i-bsearch_index
    fileprivate func searchLast(where predicate: (T) throws -> Bool) rethrows -> Match<Index> {
        return try searchLast(where: predicate, in: startIndex ..< endIndex)
    }

    fileprivate func searchLast(where predicate: (T) throws -> Bool, in range: Range<Index>) rethrows -> Match<Index> {
        guard let middle = range.middle else { return .notFound(insertAt: range.upperBound) }
        if try predicate(self[middle]) {
            if middle == range.upperBound - 1 {
            return .found(at: middle)
            } else if !(try predicate(self[index(after: middle)])) {
                return .found(at: middle)
            } else {
                return try searchLast(where: predicate, in: index(after: middle) ..< range.upperBound)
            }
        } else {
            return try searchLast(where: predicate, in: range.lowerBound ..< middle)
        }
    }
}

// swiftlint:enable all
