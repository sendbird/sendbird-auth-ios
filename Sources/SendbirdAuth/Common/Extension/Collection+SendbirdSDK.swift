//
//  Collection+SendbirdSDK.swift
//  SendbirdChat
//
//  Created by Kai Lee on 6/16/25.
//

extension Collection {
    @_spi(SendbirdInternal) public var hasElements: Bool { isEmpty == false }
}
