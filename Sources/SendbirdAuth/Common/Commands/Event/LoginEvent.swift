//
//  LoginEvent.swift
//  SendbirdChat
//
//  Created by Minhyuk Kim on 2021/07/29.
//

import Foundation

public struct LoginEvent: Decodable, SBCommand {
    // Default value to conform SBCommand
    public var requestId = ""
    public var uniqueId = nil as String?
    
    public struct Constants {
        static public let defaultDedupIntervalMs: Int64 = 0
        static public let minDedupIntervalMs: Int64 = 50
    }
    
    public let cmd: CommandType = .login
    
    public let loginTimestamp: Int64
    public let maxUnreadCountOnSuperGroup: Int?
    
    public let reconnectConfiguration: ReconnectionConfiguration?
    public let messageSyncConfiguration: MessageSyncConfiguration

    public let pingInterval: Double
    public let watchdogInterval: Double
    
    public let appInfo: AuthAppInfo?
    public let user: AuthUser?

    public let sessionKey: String?
    public let eKey: String?
    
    public let configSyncNeeded: Bool

    public private(set) var deviceTokenLastDeletedAt: Int64?
    
    public let requestDedupIntervalMs: Int64

    public var isUsingDeviceTokenCaching: Bool {
        if appInfo?.typedApplicationAttributes.contains(.sdkDeviceTokenCache) == true {
            return true
        }
        
        return tempUsingDeviceTokenCaching ?? false
    }
    
    /// There was an error mapping the feature flag incorrectly, but the value is temporarily maintained to maintain the lower version.
    private var tempUsingDeviceTokenCaching: Bool?
    
    public let hasError: Bool?
    public let errorCode: Int?
    public let errorMessage: String?
    public var reqId: String?

    public var error: AuthError? {
        guard hasError == true else { return nil }
        if let errorMessage = errorMessage, let errorCode = errorCode {
            return AuthError(domain: errorMessage, code: errorCode)
        }
        return nil
    }
    
    /// Determines whether to send the stats log to the server
    public var isStatsUploadAllowed: Bool {
        appInfo?.isStatsUploadAllowed ?? false
    }
    
    /// Determines whether to collect the stats log
    public var isStatsCollectAllowed: Bool {
        appInfo?.isStatsCollectAllowed ?? false
    }
    
    public var services: [Session.Service]?
    public let expiresAt: Int64? // seconds (not millis)
    public let unreadCountInfo: UnreadCountInfo?
        
    public init(
        loginTimestamp: Int64,
        maxUnreadCountOnSuperGroup: Int?,
        reconnectConfiguration: ReconnectionConfiguration,
        pingInterval: Double,
        watchdogInterval: Double,
        appInfo: AuthAppInfo,
        user: AuthUser,
        sessionKey: String?,
        eKey: String?,
        hasError: Bool?,
        errorCode: Int?,
        errorMessage: String?,
        reqId: String?,
        allowSDKRequestLogPublish: Bool,
        deviceTokenLastDeletedAt: Int64?,
        notificationInfo: AuthNotificationInfo,
        services: [Session.Service]?,
        expiresAt: Int64?,
        unreadCountInfo: UnreadCountInfo?,
        messageSyncConfiguration: MessageSyncConfiguration,
        configSyncNeeded: Bool,
        requestDedupIntervalMs: Int64
    ) {
        self.loginTimestamp = loginTimestamp
        self.maxUnreadCountOnSuperGroup = maxUnreadCountOnSuperGroup
        self.reconnectConfiguration = reconnectConfiguration
        self.pingInterval = pingInterval
        self.watchdogInterval = watchdogInterval
        self.appInfo = appInfo
        self.user = user
        self.sessionKey = sessionKey
        self.eKey = eKey
        self.hasError = hasError
        self.errorCode = errorCode
        self.errorMessage = errorMessage
        self.reqId = reqId
        self.deviceTokenLastDeletedAt = deviceTokenLastDeletedAt
        
        self.services = services
        self.expiresAt = expiresAt
        self.unreadCountInfo = unreadCountInfo
        self.messageSyncConfiguration = messageSyncConfiguration
        self.configSyncNeeded = configSyncNeeded
        self.requestDedupIntervalMs = max(requestDedupIntervalMs, Constants.minDedupIntervalMs)
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodeCodingKeys.self)
        
        self.user = try? AuthUser(from: decoder)
        self.appInfo = try? AuthAppInfo(from: decoder)
        
        self.loginTimestamp = (try? container.decodeIfPresent(Int64.self, forKey: .loginTimestamp)) ?? 0
        self.maxUnreadCountOnSuperGroup = try? container.decodeIfPresent(Int.self, forKey: .maxUnreadCountOnSuperGroup)
        
        self.reconnectConfiguration = try? container.decodeIfPresent(
            ReconnectionConfiguration.self,
            forKey: .reconnect
        )
        
        self.pingInterval = (try? container.decodeIfPresent(Double.self, forKey: .pingInterval)) ?? 0
        self.watchdogInterval = (try? container.decodeIfPresent(Double.self, forKey: .pongTimeout)) ?? 0
        
        self.sessionKey = (try? container.decodeIfPresent(String.self, forKey: .key))
            ?? (try? container.decodeIfPresent(String.self, forKey: .newKey))
        self.eKey = try? container.decodeIfPresent(String.self, forKey: .ekey)
        self.deviceTokenLastDeletedAt = try? container.decodeIfPresent(Int64.self, forKey: .deviceTokenLastDeletedAt)
        self.tempUsingDeviceTokenCaching = try? container.decodeIfPresent(Bool.self, forKey: .sdkDeviceTokenCache)
        
        // TODO: All requests might have these properties.
        // Can we try group this logic together so that we don't need to do this in every events?
        // P3
        self.reqId = try? container.decodeIfPresent(String.self, forKey: .reqId)
        self.hasError = try? container.decodeIfPresent(Bool.self, forKey: .error)
        self.errorMessage = try? container.decodeIfPresent(String.self, forKey: .message)
        self.errorCode = try? container.decodeIfPresent(Int.self, forKey: .code)
        
        self.services = try? container.decodeIfPresent([Session.Service].self, forKey: .services)
        self.expiresAt = (try? container.decodeIfPresent(Int64.self, forKey: .expiresAt)) ?? 0
        self.unreadCountInfo = try? UnreadCountInfo(from: decoder)
        self.messageSyncConfiguration = (try? MessageSyncConfiguration(from: decoder)) ?? .default
        
        self.configSyncNeeded = (try? container.decodeIfPresent(Bool.self, forKey: .configSyncNeeded)) ?? false
        
        let dedupIntervalMs = (try? container.decodeIfPresent(Int64.self, forKey: .requestDedupIntervalMs)) ?? Constants.defaultDedupIntervalMs
        if dedupIntervalMs <= 0 {
            // 0보다 작은값이면 dedup 없음
            self.requestDedupIntervalMs = 0
        } else {
            // 최소 50ms
            self.requestDedupIntervalMs = max(dedupIntervalMs, Constants.minDedupIntervalMs)
        }
    }
}

#if TESTCASE
extension LoginEvent {
    public func updated(deviceTokenLastDeletedAt: Int64?, isUsingDeviceTokenCaching: Bool) -> Self {
        var mutating = self
        mutating.deviceTokenLastDeletedAt = deviceTokenLastDeletedAt
        if isUsingDeviceTokenCaching {
            mutating.appInfo?.applicationAttributes?.append(CodeCodingKeys.sdkDeviceTokenCache.rawValue)
        } else {
            if let index = mutating.appInfo?.applicationAttributes?.firstIndex(of: CodeCodingKeys.sdkDeviceTokenCache.rawValue) {
                mutating.appInfo?.applicationAttributes?.remove(at: index)
            }
        }
        return mutating
    }
}
#endif
