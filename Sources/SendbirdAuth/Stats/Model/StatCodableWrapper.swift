//
//  StatCodableWrapper.swift
//  SendbirdChatSDK
//
//  Created by Ernest Hong on 2022/12/14.
//

import Foundation

@_spi(SendbirdInternal) public struct StatCodableWrapper<StatType: BaseStatType>: Codable {
    @_spi(SendbirdInternal) public let baseStat: StatType
        
    @_spi(SendbirdInternal) public init(baseStat: StatType) {
        self.baseStat = baseStat
    }
    
    @_spi(SendbirdInternal) public init(from decoder: Decoder) throws {
        baseStat = try StatType.init(from: decoder)
    }
    
    @_spi(SendbirdInternal) public func encode(to encoder: Encoder) throws {
        try baseStat.encode(to: encoder)
    }
}
