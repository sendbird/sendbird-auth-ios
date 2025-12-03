//
//  FilteredProperty.swift
//  SendBirdCalls
//
//  Created by Damon Park on 2020/02/10.
//  Copyright © 2020 SendBird Inc. All rights reserved.
//

import Foundation

@_spi(SendbirdInternal) public class FilteredProperty<Element: Equatable> {
    @_spi(SendbirdInternal) public typealias Filtered = ((Element) -> Bool)
    
    private var element: Element?
    private var filter: Filtered?
    
    @_spi(SendbirdInternal) public init(type: Element.Type = Element.self, value: Element? = nil, filter: Filtered? = nil) {
        self.element = value
        self.filter = filter
    }
}
 
extension FilteredProperty {
    @_spi(SendbirdInternal) public var value: Element? { self.element }
    
    @discardableResult
    @_spi(SendbirdInternal) public func update(_ element: Element?) -> Element? {
        guard let element = element else { return nil }
        if let filter = self.filter, filter(element) == false { return nil }
        self.element = element
        return self.element
    }
    
    @_spi(SendbirdInternal) public func remove(_ element: Element?) {
        guard self.value == element else { return }
        self.element = nil
    }
    
    @_spi(SendbirdInternal) public func clear() { self.element = nil }
}
