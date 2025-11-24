//
//  CachedData.swift
//  SendbirdChat
//
//  Created by Wooyoung Chung on 8/11/21.
//

import Foundation

public class CachedData<T> {
    public var value: T
    public var updatedAt: Int64

    public var removed: Bool = false
    
    public init(value: T, updatedAt: Int64 = 0) {
        self.value = value
        self.updatedAt = updatedAt
    }
}
