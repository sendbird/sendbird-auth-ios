//
//  ExternalStatMapper.swift
//  SendbirdChatSDK
//
//  Created by Ernest Hong on 2023/04/07.
//

import Foundation

@_spi(SendbirdInternal) public struct ExternalStatMapper {

    @_spi(SendbirdInternal) public static func map(
        type: String,
        data: [String: Any],
        timestamp: Int64,
        statId: String? = nil,
        includeRuntimeId: Bool = false
    ) -> BaseStat? {
        guard let statType = StatType(rawValue: type) else {
            Logger.external.error("Invalid stat type", type)
            return nil
        }

        guard statType.isExternal else {
            Logger.external.error("This stat type is not external stat", type)
            return nil
        }

        return BaseStat(
            statType: statType,
            timestamp: timestamp,
            statId: statId,
            data: data.anyCodable,
            includeRuntimeId: includeRuntimeId
        )
    }
}
