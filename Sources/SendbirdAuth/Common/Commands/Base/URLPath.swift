//
//  URLPath.swift
//  SendbirdChat
//
//  Created by Kai Lee on 6/12/25.
//

import Foundation

package struct URLPath: ExpressibleByStringLiteral, ExpressibleByArrayLiteral {
    package typealias ArrayLiteralElement = CustomStringConvertible

    package var urlPaths: [String]
    
    package var encodedPath: String {
        "/" + urlPaths.map { $0.urlEncoded }.joined(separator: "/")
    }
    
    package var asPath: String { self.encodedPath }
    
    package init(stringLiteral value: String) {
        self.urlPaths = [value]
    }
 
    package init(arrayLiteral elements: CustomStringConvertible...) {
        self.urlPaths = elements.map(\.description)
    }
    
    package init(array elements: [CustomStringConvertible]) {
        self.urlPaths = elements.map(\.description)
    }
    package mutating func append(_ element: String) {
        urlPaths.append(element)
    }
    
    package func appending(_ element: String) -> URLPath {
        var urlPath = self
        urlPath.append(element)
        return urlPath
    }
}
