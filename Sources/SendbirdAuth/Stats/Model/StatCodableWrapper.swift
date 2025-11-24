//
//  StatCodableWrapper.swift
//  SendbirdChatSDK
//
//  Created by Ernest Hong on 2022/12/14.
//

import Foundation

public struct StatCodableWrapper<StatType: BaseStatType>: Codable {
    public let baseStat: StatType
        
    public init(baseStat: StatType) {
        self.baseStat = baseStat
    }
    
    public init(from decoder: Decoder) throws {
        baseStat = try StatType.init(from: decoder)
    }
    
    public func encode(to encoder: Encoder) throws {
        try baseStat.encode(to: encoder)
    }
}
