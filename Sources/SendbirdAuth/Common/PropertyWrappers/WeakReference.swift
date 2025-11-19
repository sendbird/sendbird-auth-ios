//
//  WeakReference.swift
//  SendBirdCalls
//
//  Created by Minhyuk Kim on 2020/12/28.
//  Copyright © 2020 SendBird Inc. All rights reserved.
//

import Foundation

class WeakReference<T: AnyObject>: Hashable {
    private(set) weak var value: T?
    
    func hash(into hasher: inout Hasher) {
        if let hashableValue = self.value as? AnyHashable {
            hasher.combine(hashableValue.hashValue)
        } else if let value = self.value {
            hasher.combine(ObjectIdentifier(value))
        }
    }

    init(value: T?) {
        self.value = value
    }
}

extension WeakReference: Equatable {
    static func == (lhs: WeakReference<T>, rhs: WeakReference<T>) -> Bool {
        return lhs.value === rhs.value
    }
}
