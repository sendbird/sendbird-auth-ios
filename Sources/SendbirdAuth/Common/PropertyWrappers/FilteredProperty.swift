//
//  FilteredProperty.swift
//  SendBirdCalls
//
//  Created by Damon Park on 2020/02/10.
//  Copyright © 2020 SendBird Inc. All rights reserved.
//

import Foundation

public class FilteredProperty<Element: Equatable> {
    public typealias Filtered = ((Element) -> Bool)
    
    private var element: Element?
    private var filter: Filtered?
    
    public init(type: Element.Type = Element.self, value: Element? = nil, filter: Filtered? = nil) {
        self.element = value
        self.filter = filter
    }
}
 
extension FilteredProperty {
    public var value: Element? { self.element }
    
    @discardableResult
    public func update(_ element: Element?) -> Element? {
        guard let element = element else { return nil }
        if let filter = self.filter, filter(element) == false { return nil }
        self.element = element
        return self.element
    }
    
    public func remove(_ element: Element?) {
        guard self.value == element else { return }
        self.element = nil
    }
    
    public func clear() { self.element = nil }
}
