//
//  SetOnce.swift
//  SendBirdCalls
//
//  Created by Minhyuk Kim on 2020/12/29.
//  Copyright © 2020 SendBird Inc. All rights reserved.
//

import Foundation

struct SetOnce<T> {
    enum SetOnceValue<U> {
        case initial(U, ((U) -> Void)? = nil)
        case set(U)
    }

    private var wrappedValue: SetOnceValue<T>
    
    init(_ value: T, onChanged: ((T) -> Void)?) {
        self.wrappedValue = SetOnceValue.initial(value, onChanged)
    }
    
    var value: T {
        switch self.wrappedValue {
        case .initial(let value, _): return value
        case .set(let value): return value
        }
    }
    
    mutating func setValue(_ newValue: T) {
        guard case .initial(_, let onChanged) = self.wrappedValue else { return }
        
        self.wrappedValue = .set(newValue)
        onChanged?(newValue)
    }
    
    var isInitial: Bool {
        if case .initial = self.wrappedValue { return true }
        return false
    }
}
