//
//  CodingKeys.swift
//  SendbirdChatSDK
//
//  Created by Minhyuk Kim on 2024/02/16.
//
import Foundation

// MARK: - RequestCodingKey Protocol

/// Protocol for CodingKeys used in API requests.
/// Both `CodeCodingKeys` (Auth) and `ChatCodingKeys` (Chat) conform to this protocol.
@_spi(SendbirdInternal) public protocol RequestCodingKey: CodingKey, Hashable, CustomStringConvertible {
    static var reqId: Self { get }
}

// swiftlint:disable identifier_name
enum CodeCodingKeys: String, CodingKey, Codable, CustomStringConvertible, RequestCodingKey {
    var description: String { rawValue }

    case action
    case aiAgent = "ai_agent"
    case all
    case allowSDKLogIngestion = "allow_sdk_log_ingestion"
    case applicationAttributes = "application_attributes"
    case backOffDelay = "back_off_delay"
    case channelURL = "channel_url"
    case code
    case concurrentCallLimit = "concurrent_call_limit"
    case configSyncNeeded = "config_sync_needed"
    case customTypes = "custom_types"
    case data
    case deviceId = "device_id"
    case deviceTokenLastDeletedAt = "device_token_last_deleted_at"
    case disableSuperGroupMACK = "disable_supergroup_mack"
    case ekey
    case emojiHash = "emoji_hash"
    case enabled
    case endpoint
    case error
    case errorCode = "error_code"
    case errorDescription = "error_description"
    case expiresAt = "expires_at"
    case expiresIn = "expires_in"
    case expiringSession = "expiring_session"
    case feed
    case feedChannels = "feed_channels"
    case fileUploadSizeLimit = "file_upload_size_limit"
    case friendDiscoveryKey = "friend_discovery_key"
    case friendName = "friend_name"
    case groupChannelCount = "group_channel_count"
    case guestId = "guest_id"
    case hostURL = "host_url"
    case id
    case image
    case interval
    case isActive = "is_active"
    case isBot = "is_bot"
    case isOnline = "is_online"
    case isUploaded
    case key
    case lastSeenAt = "last_seen_at"
    case lastUpdatedAt = "last_updated_at"
    case latency
    case localUpdatedAt = "local_updated_at"
    case logEntries = "log_entries"
    case logPublishConfig = "log_publish_config"
    case loginTimestamp = "login_ts"
    case maxInterval = "max_interval"
    case maxUnreadCountOnSuperGroup = "max_unread_cnt_on_super_group"
    case message
    case messageId = "message_id"
    case messageTemplate = "message_template"
    case messageTs = "message_ts"
    case metadata
    case method
    case multipleFileSendMaxSize = "multiple_file_send_max_size"
    case multiplier = "mul"
    case name
    case newKey = "new_key"
    case nickname
    case notificationEventDeadline = "notification_event_deadline"
    case notifications
    case pingInterval = "ping_interval"
    case pongTimeout = "pong_timeout"
    case preferredLanguages = "preferred_languages"
    case premiumFeatureList = "premium_feature_list"
    case profileURL = "profile_url"
    case reason
    case reasonCode = "reason_code"
    case reconnect = "reconnect"
    case reqId = "req_id"
    case requestDedupIntervalMs = "request_dedup_interval_ms"
    case requireAuth = "require_auth"
    case requireAuthForProfileImage = "require_auth_for_profile_image"
    case retryAfter = "retry_after"
    case retryCount = "retry_cnt"
    case sdkDeviceTokenCache = "sdk_device_token_cache"
    case services
    case settingsUpdatedAt = "settings_updated_at"
    case source
    case statId = "stat_id"
    case statType = "stat_type"
    case success
    case tags
    case templateKey = "template_key"
    case templateListToken = "template_list_token"
    case timestamp
    case token
    case topic
    case totalUnreadCount = "total_unread_count"
    case ts
    case uikitConfig = "uikit_config"
    case unreadCnt = "unread_cnt"
    case useNativeWS = "ios_native_ws"
    case useReaction = "use_reaction"
    case userId = "user_id"
}
// swiftlint:enable identifier_name

// MARK: - Dictionary Extension for CodingKey Conversion

@_spi(SendbirdInternal)
public extension Dictionary where Key: RequestCodingKey {
    /// Converts dictionary keys from RequestCodingKey to String using their description (rawValue).
    func mapKeysToString() -> [String: Value] {
        Dictionary<String, Value>(uniqueKeysWithValues: map { 
            ($0.key.description, $0.value) 
        })
    }
}
