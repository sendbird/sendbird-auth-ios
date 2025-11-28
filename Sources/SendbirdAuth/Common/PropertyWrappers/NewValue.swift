//
//  ExchangeValue.swift
//  SendBirdCalls
//
//  Created by Damon Park on 2020/11/16.
//  Copyright © 2020 SendBird Inc. All rights reserved.
//

import Foundation

@propertyWrapper
class NewValue<Element: NewValuable> {
    var wrappedValue: Element {
        willSet {
            newValue.status = .active
            newValue.willSetNewValue(with: self.wrappedValue)
        }
        
        didSet {
            oldValue.status = .inactive
            self.wrappedValue.didSetNewValue(with: oldValue)
            #if !RELEASE
            self.delegate?.didSetNewValue(self.wrappedValue)
            #endif
        }
    }
    
    var preparing: Element? { caches.values.first(where: { $0.status == .preparing }) }
    
    private(set) var caches = [Element.Identifier: Element]()
    
    #if !RELEASE
    private weak var delegate: NewValueDelegate?
    #endif
    
    init(wrappedValue: Element, newValue: Element? = nil) {
        wrappedValue.status = .active
        self.wrappedValue = wrappedValue
        self.caches[wrappedValue.identifier] = wrappedValue
        if let value = newValue { self.prepare(with: value) }
    }
    
    func prepare(with value: Element) {
        self.failed()
        value.status = .preparing
        value.prepareNewValue()
        self.caches[value.identifier] = value
    }
    
    func complete() {
        guard let value = self.preparing else { return }
        self.wrappedValue = value
    }
    
    func failed() {
        self.caches
            .values
            .filter({ $0.status == .preparing })
            .forEach({ value in
                value.status = .inactive
                value.failedToSetNewValue()
            })
    }
    
    #if !RELEASE
    func setDelegate(_ delegate: NewValueDelegate) {
        self.delegate = delegate
    }
    #endif
    
}

protocol NewValuable: AnyObject {
    associatedtype Identifier: Hashable
    
    var identifier: Identifier { get }
    
    var status: NewValueStatus { get set }
    
    func prepareNewValue()

    func willSetNewValue(with oldValue: Self)
    
    func didSetNewValue(with oldValue: Self)
    
    func failedToSetNewValue()
}

enum NewValueStatus: Int {
    case active
    case preparing
    case inactive
}

#if !RELEASE
protocol NewValueDelegate: AnyObject {
    func didSetNewValue(_ value: Any?)
    func failedToSetNewValue(_ value: Any?)
}
#endif
