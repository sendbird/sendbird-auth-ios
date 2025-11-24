//
//  URLPath.swift
//  SendbirdChat
//
//  Created by Kai Lee on 6/12/25.
//

import Foundation

public struct URLPath: ExpressibleByStringLiteral, ExpressibleByArrayLiteral {
    public typealias ArrayLiteralElement = CustomStringConvertible

    public var urlPaths: [String]
    
    public var encodedPath: String {
        "/" + urlPaths.map { $0.urlEncoded }.joined(separator: "/")
    }
    
    public var asPath: String { self.encodedPath }
    
    public init(stringLiteral value: String) {
        self.urlPaths = [value]
    }
 
    public init(arrayLiteral elements: CustomStringConvertible...) {
        self.urlPaths = elements.map(\.description)
    }
    
    public init(array elements: [CustomStringConvertible]) {
        self.urlPaths = elements.map(\.description)
    }
    public mutating func append(_ element: String) {
        urlPaths.append(element)
    }
    
    public func appending(_ element: String) -> URLPath {
        var urlPath = self
        urlPath.append(element)
        return urlPath
    }
}
