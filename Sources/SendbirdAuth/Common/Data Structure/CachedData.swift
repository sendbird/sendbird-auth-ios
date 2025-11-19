//
//  CachedData.swift
//  SendbirdChat
//
//  Created by Wooyoung Chung on 8/11/21.
//

import Foundation

package class CachedData<T> {
    package var value: T
    package var updatedAt: Int64

    package var removed: Bool = false
    
    package init(value: T, updatedAt: Int64 = 0) {
        self.value = value
        self.updatedAt = updatedAt
    }
}
