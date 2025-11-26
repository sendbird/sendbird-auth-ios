//
//  URLPath.swift
//  SendbirdChat
//
//  Created by Kai Lee on 6/12/25.
//

import Foundation

@_spi(SendbirdInternal) public struct URLPath: ExpressibleByStringLiteral, ExpressibleByArrayLiteral {
    @_spi(SendbirdInternal) public typealias ArrayLiteralElement = CustomStringConvertible

    @_spi(SendbirdInternal) public var urlPaths: [String]
    
    @_spi(SendbirdInternal) public var encodedPath: String {
        "/" + urlPaths.map { $0.urlEncoded }.joined(separator: "/")
    }
    
    @_spi(SendbirdInternal) public var asPath: String { self.encodedPath }
    
    @_spi(SendbirdInternal) public init(stringLiteral value: String) {
        self.urlPaths = [value]
    }
 
    @_spi(SendbirdInternal) public init(arrayLiteral elements: CustomStringConvertible...) {
        self.urlPaths = elements.map(\.description)
    }
    
    @_spi(SendbirdInternal) public init(array elements: [CustomStringConvertible]) {
        self.urlPaths = elements.map(\.description)
    }
    @_spi(SendbirdInternal) public mutating func append(_ element: String) {
        urlPaths.append(element)
    }
    
    @_spi(SendbirdInternal) public func appending(_ element: String) -> URLPath {
        var urlPath = self
        urlPath.append(element)
        return urlPath
    }
}
