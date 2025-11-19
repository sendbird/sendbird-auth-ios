//
//  StatCodableWrapper.swift
//  SendbirdChatSDK
//
//  Created by Ernest Hong on 2022/12/14.
//

import Foundation

package struct StatCodableWrapper<StatType: BaseStatType>: Codable {
    package let baseStat: StatType
        
    package init(baseStat: StatType) {
        self.baseStat = baseStat
    }
    
    package init(from decoder: Decoder) throws {
        baseStat = try StatType.init(from: decoder)
    }
    
    package func encode(to encoder: Encoder) throws {
        try baseStat.encode(to: encoder)
    }
}
