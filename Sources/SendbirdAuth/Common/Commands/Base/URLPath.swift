//
//  URLPath.swift
//  SendbirdChat
//
//  Created by Kai Lee on 6/12/25.
//

import Foundation

// MARK: - URLPathConvertible Protocol

/// A protocol that allows external modules to define custom API endpoints.
///
/// Conform to this protocol to create custom URL paths that can be used with the SDK's request system.
///
/// Example:
/// ```swift
/// enum MyCustomPaths: URLPathConvertible {
///     case customEndpoint(id: String)
///
///     var urlPath: URLPath {
///         switch self {
///         case .customEndpoint(let id):
///             return ["custom", "endpoint", id]
///         }
///     }
/// }
/// ```
@_spi(SendbirdInternal) public protocol URLPathConvertible {
    var urlPath: URLPath { get }
}

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

// MARK: - URLPathConvertible Conformance

extension URLPath: URLPathConvertible {
    @_spi(SendbirdInternal) public var urlPath: URLPath { self }
}
