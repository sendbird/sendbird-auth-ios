//
//  StatType.swift
//  SendbirdChatSDK
//
//  Created by Ernest Hong on 2022/06/03.
//

import Foundation

package enum StatType: String, Codable, CaseIterable {
    // Default stats
    case webSocketConnect = "ws:connect"
    case webSocketDisconnect = "ws:disconnect"
    case featureLocalCacheEvent = "feature:local_cache_event" // localCaching 켜져있을때만
    case apiResult = "api:result"

    // Daily stats
    case featureLocalCache = "feature:local_cache" // localCaching 과 상관없이 무조건 전송

    // Notification stats
    case notificationStats = "noti:stats"

    package var isExternal: Bool {
        switch self {
        case .apiResult, .webSocketConnect, .webSocketDisconnect, .featureLocalCache, .featureLocalCacheEvent:
            return false
        case .notificationStats:
            return true
        }
    }
    
    package var applicationAttributeAllowUse: AuthAppInfo.ApplicationAttribute {
        switch self {
        case .apiResult, .webSocketConnect, .webSocketDisconnect:
            return .allowSDKRequestLogPublish
        case .featureLocalCache, .featureLocalCacheEvent:
            return .allowSDKFeatureLocalCacheLogPublish
        case .notificationStats:
            return .allowSDKNotiStatsLogPublish
        }
    }
}
