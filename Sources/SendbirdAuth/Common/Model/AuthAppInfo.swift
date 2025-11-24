//
//  AuthAppInfo.swift
//  SendbirdChat
//
//  Created by Minhyuk Kim on 2021/07/09.
//

import Foundation

/// An object contains application information
public final class AuthAppInfo: NSObject, Codable {
    /// This is the latest hash value for Emoji.
    /// Default value is empty string.
    /// - Since: 3.0.180
    public var emojiHash: String

    /// This is the uploadable file size limit. (When receiving this value from the server, the unit is bytes.)
    /// - Since: 3.0.180
    public var uploadSizeLimit: Int64 {
        if uploadSizeLimitInMB == .max { return .max }
        
        return uploadSizeLimitInMB * 1024 * 1024
    }
    
    /// This is the original uploadable file size limit. (The unit is mega bytes.)
    /// - Since: 4.9.5
    public var uploadSizeLimitInMB: Int64 = 0

    /// This is the premium feature list using on your Application ID.
    /// - Since: 3.0.180
    public var premiumFeatureList: [String]?

    /// This is the state of using the reaction feature.
    /// - Since: 3.0.180
    public var useReaction: Bool

    /// This is the application attributes list using on your Application ID.
    /// - Since: 3.0.198
    public var applicationAttributes: [String]?

    /// This is the application attribute to tell SDK use native websocket
    /// - Since: 3.0.222
    public var useNativeWS: Bool = false

    ///
    /// - Since: 3.0.231
    public var concurrentCallLimit: Int = 0

    ///
    /// - Since: 3.0.231
    public var backOffDelay: TimeInterval = 0.0
    
    /// A getter for the `disableSupergroupMACK` property.
    /// - Since: 3.0.230
    public var disableSuperGroupMACK: Bool
    
    /// Determines whether to send the stats log to the server
    public var isStatsUploadAllowed: Bool
    
    /// Determines whether to collect the stats log
    public var isStatsCollectAllowed: Bool {
        typedApplicationAttributes.contains { $0.isRelatedToStat }
    }
    
    public var typedApplicationAttributes: Set<ApplicationAttribute> {
        Set(applicationAttributes?.compactMap { ApplicationAttribute(rawValue: $0) } ?? [])
    }
    
    /// - Since: 4.6.0
    @InternalAtomic public var notificationInfo: AuthNotificationInfo?
    
    /// - Since: 4.17.0
    @InternalAtomic public var messageTemplateInfo: AuthMessageTemplateInfo?
    
    /// - Since: 4.26.0
    @InternalAtomic public var aiAgentInfo: AuthAIAgent.Info
    
    /// - Since: 4.8.4
    public let uikitConfigInfo: AuthUIKitConfigInfo
    
    /// The maximum number of files that can be sent in a `MultipleFilesMessage`.
    /// - Since: 4.9.1
    public let multipleFilesMessageFileCountLimit: Int

    /// - Since: 4.17.0
    public var isChannelMembershipHistoryEnabled: Bool {
        guard let applicationAttributes else { return false }
        return applicationAttributes.contains("channel_membership_history")
    }
    
    /// - Since: 4.17.0
    public var isLeftUserViewSupportEnabled: Bool {
        guard let applicationAttributes else { return false }
        return applicationAttributes.contains("left_user_view_support")
    }
    
    /// - Since: 4.18.0
    public let statsConfig: SafeDictionary<String, StatConfig>?
    
    /// StatConfig가 도입되기 전에 하드코딩 되어있던 설정
    /// - Since: 4.18.0
    public var defaultConfig: StatConfig? {
        statsConfig?[StatConfigKeys.default.rawValue]
    }
    
    /// Notification 로그를 위한 설정
    /// - Since: 4.18.0
    public var notificationConfig: StatConfig? {
        statsConfig?[StatConfigKeys.notification.rawValue]
    }
    
    public init(
        emojiHash: String,
        uploadSizeLimit: Int64,
        premiumFeatureList: [String]? = nil,
        useReaction: Bool,
        applicationAttributes: [String]? = nil,
        concurrentCallLimit: Int = 1,
        backOffDelay: TimeInterval = 0.5,
        useNativeWS: Bool = false,
        disableSuperGroupMACK: Bool,
        isStatsUploadAllowed: Bool = true,
        notificationInfo: AuthNotificationInfo? = nil,
        messageTemplateInfo: AuthMessageTemplateInfo? = nil,
        aiAgentInfo: AuthAIAgent.Info = .init(),
        uikitConfigInfo: AuthUIKitConfigInfo = .init(),
        multipleFilesMessageFileCountLimit: Int = 30,
        statsConfig: SafeDictionary<String, StatConfig>? = nil
    ) {
        self.emojiHash = emojiHash
        self.uploadSizeLimitInMB = uploadSizeLimit
        self.premiumFeatureList = premiumFeatureList
        self.useReaction = useReaction
        self.applicationAttributes = applicationAttributes
        self.concurrentCallLimit = concurrentCallLimit
        self.backOffDelay = backOffDelay
        self.useNativeWS = useNativeWS
        self.disableSuperGroupMACK = disableSuperGroupMACK
        self.isStatsUploadAllowed = isStatsUploadAllowed
        self.notificationInfo = notificationInfo
        self.messageTemplateInfo = messageTemplateInfo
        self.aiAgentInfo = aiAgentInfo
        self.uikitConfigInfo = uikitConfigInfo
        self.multipleFilesMessageFileCountLimit = multipleFilesMessageFileCountLimit
        self.statsConfig = statsConfig
    }
    
    public enum ApplicationAttribute: String {
        case allowSDKRequestLogPublish = "allow_sdk_request_log_publish"
        case allowSDKFeatureLocalCacheLogPublish = "allow_sdk_feature_local_cache_log_publish"
        case allowSDKNotiStatsLogPublish = "allow_sdk_noti_stats_log_publish"
        case sdkDeviceTokenCache = "sdk_device_token_cache"
        
        public var isRelatedToStat: Bool {
            switch self {
            case .allowSDKRequestLogPublish,
                    .allowSDKFeatureLocalCacheLogPublish,
                    .allowSDKNotiStatsLogPublish:
                return true
            case .sdkDeviceTokenCache:
                return false
            }
        }
    }
    
    public enum StatConfigKeys: String {
        case `default` = "default"
        
        /// INFO: The configuration endpoint related to realtime stats has been changed in the TBD version due to rate limiting.
        /// Since realtime was only being used in Notifications, all naming related to realtime stats has been changed to Notifications.
        /// However, to maintain backward compatibility with older versions, the key values coming down as "realtime" will be retained.
        case notification = "realtime"
    }
    
    /**
     This function can check if Emoji information needs to be updated to date.
     - Parameters:
        - prevEmojiHash: Emoji hash value in use
     - Since: 3.0.180
     */
    @objc
    public func isEmojiUpdateNeeded(prevEmojiHash: String) -> Bool {
        return emojiHash != prevEmojiHash
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodeCodingKeys.self)

        try container.encodeIfPresent(emojiHash, forKey: .emojiHash)
        try container.encodeIfPresent(uploadSizeLimitInMB, forKey: .fileUploadSizeLimit)
        try container.encodeIfPresent(premiumFeatureList, forKey: .premiumFeatureList)
        try container.encodeIfPresent(useReaction, forKey: .useReaction)
        try container.encodeIfPresent(applicationAttributes, forKey: .applicationAttributes)
        try container.encodeIfPresent(useNativeWS, forKey: .useNativeWS)
        try container.encodeIfPresent(disableSuperGroupMACK, forKey: .disableSuperGroupMACK)
        try container.encodeIfPresent(concurrentCallLimit, forKey: .concurrentCallLimit)
        try container.encodeIfPresent(backOffDelay, forKey: .backOffDelay)
        try container.encodeIfPresent(isStatsUploadAllowed, forKey: .allowSDKLogIngestion)
        try container.encodeIfPresent(notificationInfo, forKey: .notifications)
        try container.encodeIfPresent(messageTemplateInfo, forKey: .messageTemplate)
        try container.encodeIfPresent(aiAgentInfo, forKey: .aiAgent)
        try container.encodeIfPresent(uikitConfigInfo, forKey: .uikitConfig)
        
        try container.encodeIfPresent(multipleFilesMessageFileCountLimit, forKey: .multipleFileSendMaxSize)
        
        try container.encodeIfPresent(statsConfig, forKey: .logPublishConfig)
    }
    
    /// Default constructor.
    ///
    /// - Parameter decoder: `Decoder` instance
    public required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodeCodingKeys.self)
        
        self.premiumFeatureList = try container.decodeIfPresent([String].self, forKey: .premiumFeatureList)
        self.emojiHash = try container.decodeIfPresent(String.self, forKey: .emojiHash) ?? ""
        if let limit = try? container.decode(Int64.self, forKey: .fileUploadSizeLimit) {
            self.uploadSizeLimitInMB = limit
        } else {
            self.uploadSizeLimitInMB = .max
        }
        self.useReaction = try container.decodeIfPresent(Bool.self, forKey: .useReaction) ?? true
        self.applicationAttributes = try? container.decodeIfPresent([String].self, forKey: .applicationAttributes)
        self.concurrentCallLimit = try container.decodeIfPresent(Int.self, forKey: .concurrentCallLimit) ?? 1
        self.backOffDelay = try container.decodeIfPresent(TimeInterval.self, forKey: .backOffDelay) ?? 0.5
        self.useNativeWS = try container.decodeIfPresent(Bool.self, forKey: .useNativeWS) ?? false
        self.disableSuperGroupMACK = try container.decodeIfPresent(Bool.self, forKey: .disableSuperGroupMACK) ?? false
        self.isStatsUploadAllowed = (try? container.decodeIfPresent(Bool.self, forKey: .allowSDKLogIngestion)) ?? true
        
        self.notificationInfo = try? container.decodeIfPresent(AuthNotificationInfo.self, forKey: .notifications)
        
        self.messageTemplateInfo = try? container.decodeIfPresent(AuthMessageTemplateInfo.self, forKey: .messageTemplate)
        
        self.aiAgentInfo = try container.decodeIfPresent(AuthAIAgent.Info.self, forKey: .aiAgent) ?? .init()
        
        self.uikitConfigInfo = try container.decodeIfPresent(AuthUIKitConfigInfo.self, forKey: .uikitConfig) ?? AuthUIKitConfigInfo()
       
        self.multipleFilesMessageFileCountLimit = try container.decodeIfPresent(Int.self, forKey: .multipleFileSendMaxSize) ?? 30
        
        self.statsConfig = try? container.decodeIfPresent(SafeDictionary<String, StatConfig>.self, forKey: .logPublishConfig)
    }
}
