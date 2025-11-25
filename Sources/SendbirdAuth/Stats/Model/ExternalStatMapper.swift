//
//  ExternalStatMapper.swift
//  SendbirdChatSDK
//
//  Created by Ernest Hong on 2023/04/07.
//

import Foundation

public struct ExternalStatMapper {
    public static func map(type: String, data: [String: Any], timestamp: Int64) -> BaseStat? {
        guard let statType = StatType(rawValue: type) else {
            Logger.external.error("Invalid stat type", type)
            return nil
        }
        
        guard statType.isExternal else {
            Logger.external.error("This stat type is not external stat", type)
            return nil
        }
        
        let containerStat = BaseStat(statType: statType, timestamp: timestamp, data: data.anyCodable)
        guard let jsonDictionary = containerStat.toDictionary() else {
            Logger.external.error("Failed to convert as dictionary")
            return nil
        }
        
        return StatCodableWrapper
            ._make(from: jsonDictionary, decoder: SendbirdAuth.authDecoder)?
            .baseStat
    }
}
