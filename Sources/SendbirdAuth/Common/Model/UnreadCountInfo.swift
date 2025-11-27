//
//  UnreadCountInfo.swift
//  SendbirdChat
//
//  Created by Wooyoung Chung on 9/14/21.
//

import Foundation

@_spi(SendbirdInternal) public struct UnreadCountInfo: Codable, CustomStringConvertible {
    @_spi(SendbirdInternal) public let timestamp: Int64
    @_spi(SendbirdInternal) public let customTypes: [String: Int]
    @_spi(SendbirdInternal) public var feedChannelCount: Int?
    @_spi(SendbirdInternal) public let groupChannelCount: Int
    @_spi(SendbirdInternal) public let allUnreadCount: Int  // deprecated since 4.6.0
    
    @_spi(SendbirdInternal) public init(timestamp: Int64, customTypes: [String: Int], feedChannelCount: Int?, groupChannelCount: Int, allUnreadCount: Int) {
        self.timestamp = timestamp
        self.customTypes = customTypes
        self.feedChannelCount = feedChannelCount
        self.groupChannelCount = groupChannelCount
        self.allUnreadCount = allUnreadCount
    }
    
    @_spi(SendbirdInternal) public init(from decoder: Decoder) throws {
        let rootContainer = try decoder.container(keyedBy: CodeCodingKeys.self)
        let container = (try? rootContainer.nestedContainer(keyedBy: CodeCodingKeys.self, forKey: .unreadCnt))
            ?? (try? rootContainer.nestedContainer(keyedBy: CodeCodingKeys.self, forKey: .totalUnreadCount))
            ?? rootContainer
        
        self.timestamp = (try? container.decodeIfPresent(Int64.self, forKey: .ts)) ?? 0
        self.customTypes = (try? container.decodeIfPresent([String: Int].self, forKey: .customTypes)) ?? [:]
        self.groupChannelCount = (try? container.decodeIfPresent(Int.self, forKey: .all)) ?? 0
        self.feedChannelCount = (try? container.decodeIfPresent(Int.self, forKey: .feed))
        self.allUnreadCount = (try? container.decodeIfPresent(Int.self, forKey: .all)) ?? 0
    }
    
    @_spi(SendbirdInternal) public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodeCodingKeys.self)
        var unreadContainer = container
            .nestedContainer(keyedBy: CodeCodingKeys.self, forKey: .unreadCnt)
        
        try unreadContainer.encode(timestamp, forKey: .ts)
        try unreadContainer.encode(customTypes, forKey: .customTypes)
        try unreadContainer.encode(groupChannelCount, forKey: .all)
        try unreadContainer.encodeIfPresent(feedChannelCount, forKey: .feed)
        try unreadContainer.encode(allUnreadCount, forKey: .all)
    }
    
    @_spi(SendbirdInternal) public var description: String { toDictionary()?.description ?? "" }
    
    @_spi(SendbirdInternal) public func merge(info: UnreadCountInfo) -> (hasChanged: Bool, newInfo: UnreadCountInfo) {
        var hasChanged = false
        
        let merged = customTypes.merging(
            info.customTypes,
            uniquingKeysWith: { (prev, new) -> Int in
                hasChanged = prev != new
                return new
            }
        )

        if info.groupChannelCount != groupChannelCount || (info.feedChannelCount != nil && info.feedChannelCount != feedChannelCount) {
            hasChanged = true
        }
        let allUnreadCount = info.allUnreadCount

        let newInfo = UnreadCountInfo(
            timestamp: info.timestamp,
            customTypes: merged,
            feedChannelCount: info.feedChannelCount ?? feedChannelCount,
            groupChannelCount: info.groupChannelCount,
            allUnreadCount: allUnreadCount
        )
        
        return (hasChanged, newInfo)
    }
}
