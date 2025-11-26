//
//  Array+SendbirdChat.swift
//  SendbirdChat
//
//  Created by Wooyoung Chung on 8/20/21.
//

import Foundation

@_spi(SendbirdInternal) public extension Array {
    mutating func popFirst() -> Element? {
        if isEmpty {
            return nil
        } else {
            return removeFirst()
        }
    }
    
    subscript(safe range: Range<Index>) -> ArraySlice<Element>? {
        if range.endIndex > endIndex {
            if range.startIndex >= endIndex {
                return nil
            } else {
                return self[range.startIndex..<endIndex]
            }
        } else {
            return self[range]
        }
    }
    
    subscript (safe index: Int) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
    
    mutating func removeFirstThenClear(_ clear: ([Element]) -> Void) {
        let copied = self
        self.removeAll()
        clear(copied)
    }
}

@_spi(SendbirdInternal) extension Array where Element == AnyCodable {
    @_spi(SendbirdInternal) public var anyValue: [Any] { map { $0.anyValue } }
}

extension Array where Element == Any {
    @_spi(SendbirdInternal) public var anyCodable: [AnyCodable] { map { AnyCodable($0) } }
}

extension Array where Element: Hashable {
    @_spi(SendbirdInternal) public func equalWithoutOrder(as other: [Element]?) -> Bool {
        guard let other = other else { return false }
        return self.countElements() == other.countElements()
    }

    private func countElements() -> [Element: Int] {
        self.reduce(into: [Element: Int]()) { $0[$1, default: 0] += 1 }
    }
}

@_spi(SendbirdInternal) extension Array where Element: BaseStatType {
    @_spi(SendbirdInternal) public func sbd_chunked(into size: Int) -> [[Element]] {
        return stride(from: 0, to: count, by: size).map {
            Array(self[$0 ..< Swift.min($0 + size, count)])
        }
    }
}

extension Array where Element == String {
    /// Methods that filter only strings with at least one character present
    @_spi(SendbirdInternal) public func filterNonEmptyStrings() -> [Element]? {
        self.compactMap { element in element.hasElements ? element : nil }
    }

    /// Methods to filter a string for the presence of at least one character, and return nil if the list is empty.
    @_spi(SendbirdInternal) public func filterNonEmptyStringsOrNil() -> [Element]? {
        let filtered = self.compactMap { element in element.hasElements ? element : nil }
        return filtered.hasElements ? filtered : nil
    }
}
