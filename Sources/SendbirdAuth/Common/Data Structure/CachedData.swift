//
//  CachedData.swift
//  SendbirdChat
//
//  Created by Wooyoung Chung on 8/11/21.
//

import Foundation

@_spi(SendbirdInternal) public class CachedData<T> {
    @_spi(SendbirdInternal) public var value: T
    @_spi(SendbirdInternal) public var updatedAt: Int64

    @_spi(SendbirdInternal) public var removed: Bool = false
    
    @_spi(SendbirdInternal) public init(value: T, updatedAt: Int64 = 0) {
        self.value = value
        self.updatedAt = updatedAt
    }
}
