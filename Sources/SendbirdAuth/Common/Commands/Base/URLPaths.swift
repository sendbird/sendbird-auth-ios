///
///  URLPaths.swift
///  SendbirdChatSDK
///
///  Created by Minhyuk Kim on 2024", "02", "16.
///

import Foundation

@_spi(SendbirdInternal) public enum URLPaths {

    /// Secret Application Settings
    case secretApplicationAttrsReactions(applicationId: String)
    case secretApplicationAttrs(applicationId: String)
    case secretApplicationPlan(applicationId: String)
    case secretApplicationUiKitConfiguration(applicationId: String)
    case secretApplicationNotificationChannels(applicationId: String)
    case applicationsSettingsGlobal

    /// User Auth Related (Auth-specific)
    case usersToken(userId: String)
    case usersLogin(userId: String)
    case usersSessionKey(userId: String)
    case usersPush(userId: String)

    /// Group Channels (Auth-specific)
    case groupChannelsTyping(channelURL: String)
    case groupChannelsMessagesInReviewTransitions(channelURL: String, messageId: Int64)
    case groupChannelsDistinctMessage

    /// Channel Operations (Auth-specific)
    case channelMessagesSortedMetaArray(channelType: AuthChannelType, channelURL: String, messageId: Int64)

    /// Notifications (Auth-specific)
    case notificationsChannels(channelKey: String)
    case notificationsChannelsCategories(channelKey: String, categoryId: String)

    /// Bots (Auth-specific)
    case botsSend(botUserId: String)

    /// Custom Responses
    case customResponses

    /// Polls (Auth-specific)
    case pollsVote(pollId: Int64)

    /// SDK API endpoints (Auth-specific)
    case sdkStatistics
    case notificationStatistics
    case authenticate(userId: String)

    @_spi(SendbirdInternal) public var splitPath: [CustomStringConvertible] {
        switch self {
            /// Secret Application Settings
        case .secretApplicationAttrsReactions(let applicationId):
            return ["secret", applicationId, "attrs", "reactions"]
        case .secretApplicationAttrs(let applicationId), .secretApplicationPlan(let applicationId):
            return ["secret", applicationId, "attrs"]
        case .secretApplicationUiKitConfiguration(let applicationId):
            return ["secret", applicationId, "ui_kit", "configuration"]
        case .secretApplicationNotificationChannels(let applicationId):
            return ["secret", applicationId, "notification_channels"]
        case .applicationsSettingsGlobal:
            return ["applications", "settings_global"]

            /// User Auth Related
        case .usersLogin(let userId):
            return ["users", userId]
        case .usersToken(let userId):
            return ["users", userId, "token"]
        case .usersSessionKey(let userId):
            return ["users", userId, "session_key"]
        case .usersPush(let userId):
            return ["users", userId, "push"]

            /// Group Channels
        case .groupChannelsTyping(let channelURL):
            return ["group_channels", channelURL, "typing"]
        case .groupChannelsMessagesInReviewTransitions(let channelURL, let messageId):
            return ["group_channels", channelURL, "messages_in_review", messageId, "transitions"]
        case .groupChannelsDistinctMessage:
            return ["group_channels", "distinct_message"]

            /// Channel Operations
        case .channelMessagesSortedMetaArray(let channelType, let channelURL, let messageId):
            return [channelType.urlString, channelURL, "messages", messageId, "sorted_metaarray"]

            /// Notifications
        case .notificationsChannels(let channelKey):
            return ["notifications", "channels", channelKey]
        case .notificationsChannelsCategories(let channelKey, let categoryId):
            return ["notifications", "channels", "\(channelKey.urlEncoded)", "categories", "\(categoryId.urlEncoded)"]

            /// Bots
        case .botsSend(let botUserId):
            return ["bots", "\(botUserId.urlEncoded)", "send"]

            /// Custom Responses
        case .customResponses:
            return ["custom_responses"]

            /// Polls
        case .pollsVote(let pollId):
            return ["polls", "\(pollId)", "vote"]

            /// SDK API Endpoints
        case .sdkStatistics:
            return ["sdk", "statistics"]
        case .notificationStatistics:
            return ["sdk", "notification_statistics"]
        case .authenticate(let userId):
            return ["sdk", "users", userId, "authentication"]
        }
    }
}

// MARK: - URLPathConvertible Conformance

extension URLPaths: URLPathConvertible {
    @_spi(SendbirdInternal) public var urlPath: URLPath {
        URLPath(array: self.splitPath)
    }
}
