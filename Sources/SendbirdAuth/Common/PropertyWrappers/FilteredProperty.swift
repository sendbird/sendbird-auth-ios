//
//  FilteredProperty.swift
//  SendBirdCalls
//
//  Created by Damon Park on 2020/02/10.
//  Copyright © 2020 SendBird Inc. All rights reserved.
//

import Foundation

package class FilteredProperty<Element: Equatable> {
    package typealias Filtered = ((Element) -> Bool)
    
    private var element: Element?
    private var filter: Filtered?
    
    package init(type: Element.Type = Element.self, value: Element? = nil, filter: Filtered? = nil) {
        self.element = value
        self.filter = filter
    }
}
 
extension FilteredProperty {
    package var value: Element? { self.element }
    
    @discardableResult
    package func update(_ element: Element?) -> Element? {
        guard let element = element else { return nil }
        if let filter = self.filter, filter(element) == false { return nil }
        self.element = element
        return self.element
    }
    
    package func remove(_ element: Element?) {
        guard self.value == element else { return }
        self.element = nil
    }
    
    package func clear() { self.element = nil }
}
