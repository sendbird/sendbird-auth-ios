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

    /// User Auth Related
    case usersToken(userId: String)
    case usersLogin(userId: String)
    case usersSessionKey(userId: String)
    case usersPush(userId: String)

    /// SDK API endpoints
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
