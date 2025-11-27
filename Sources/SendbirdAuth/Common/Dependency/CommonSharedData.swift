//
//  CommonSharedData.swift
//  SendbirdChat
//
//  Created by Kai Lee on 6/13/25.
//

import Foundation

@_spi(SendbirdInternal) public class CommonSharedData {
    @_spi(SendbirdInternal) public private(set) var eKey: String?

    @_spi(SendbirdInternal) public init(eKey: String?) {
        self.eKey = eKey
    }
    
    @_spi(SendbirdInternal) public func update(eKey: String?) {
        self.eKey = eKey
    }
}
