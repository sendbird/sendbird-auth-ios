//
//  User.swift
//  SendbirdChat
//
//  Created by Minhyuk Kim on 2021/07/08.
//

import Foundation

package class AuthUser: NSObject, Codable, Identifiable {
    /// Identifier for the user conforming to `Identifiable`
    package var id: String { self.userId }
    
    /// User ID. This has to be unique.
    package let userId: String
    
    /// User nickname.
    package var nickname: String
    
    /// The profile image URL without the `ekey`.
    /// - Since: 3.0.194
    package var plainProfileImageURL: String?
    
    /// User connection status. This is defined in `AuthUserConnectionStatus`.
    package var connectionStatus: AuthUserConnectionStatus
    
    /// The lastest time when the user became offline.
    package var lastSeenAt: Int64
    
    /// Represents the user is activated. This property is changed by the [Platform API](https://docs.sendbird.com/platform#user_3_update_a_user)
    package let isActive: Bool
    
    /// Discovery key for friend
    package let friendDiscoveryKey: String?
    
    /// User name for friend
    package let friendName: String?
    
    /// Shows if the user is a bot or not.
    /// - Since: 4.9.4
    package let isBot: Bool
    
    /// User's preferred language. Used for translating messages.
    /// - Since: 3.0.159
    package var preferredLanguages: [String]?
    
    /// Meta data.
    package var metaData: [String: String] { self.metaDataMap.toDictionary() }
    
    package var metaDataMap: SafeDictionary<String, String>
    
    package var requireAuth: Bool
    
    /// The timestamp indicating the last update time of the user.
    /// - Note: Defaults to `-1`, representing that the user has not been updated.
    /// - Since: 4.24.1
    package private(set) var localUpdatedAt: Int64
    
    @DependencyWrapper package var dependency: Dependency?
    package var requestQueue: RequestQueue? { dependency?.requestQueue }
    private var stateData: ConnectionStateData? { dependency?.stateData }
    package var service: QueueService? { dependency?.service }
    private var eKey: String? { dependency?.commonSharedData.eKey }
    
    package init(
        dependency: Dependency?,
        userId: String = "",
        nickname: String = "",
        profileURL: String? = nil,
        connectionStatus: AuthUserConnectionStatus = .online,
        lastSeenAt: Int64 = 0,
        metaData: [String: String] = [:],
        isActive: Bool = true,
        discoveryKey: String? = nil,
        friendName: String = "",
        prefLangauges: [String] = [],
        requireAuth: Bool = false,
        isBot: Bool = false,
        localUpdatedAt: Int64 = -1
    ) {
        self.userId = userId
        self.nickname = nickname
        self.plainProfileImageURL = profileURL
        self.connectionStatus = connectionStatus
        self.lastSeenAt = lastSeenAt
        self.metaDataMap = .init(metaData)
        self.isActive = isActive
        self.friendDiscoveryKey = discoveryKey
        self.friendName = friendName
        self.preferredLanguages = prefLangauges
        self.requireAuth = requireAuth
        self.isBot = isBot
        self.localUpdatedAt = localUpdatedAt
        
        super.init()
        
        self.dependency = dependency
    }
    
    /// Default constructor.
    ///
    /// - Parameter decoder: `Decoder` instance
    required package init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodeCodingKeys.self)

        self.userId =
            (try? container.decode(String.self, forKey: .userId)) ??
            (try? container.decode(String.self, forKey: .guestId)) ?? ""
        
        self.nickname =
            (try? container.decode(String.self, forKey: .nickname)) ??
            (try? container.decode(String.self, forKey: .name)) ?? ""
        
        self.plainProfileImageURL =
            (try? container.decode(String.self, forKey: .profileURL)) ??
            (try? container.decode(String.self, forKey: .image)) ?? nil
        
        self.connectionStatus = (try? container.decode(AuthUserConnectionStatus.self, forKey: .isOnline)) ?? .nonAvailable
        self.lastSeenAt = (try? container.decode(Int64.self, forKey: .lastSeenAt)) ?? 0
        let metaData = try? container.decode([String: String].self, forKey: .metadata)
        self.metaDataMap = .init(metaData ?? [:])
        self.isActive = (try? container.decode(Bool.self, forKey: .isActive)) ?? true
        self.friendDiscoveryKey = try? container.decode(String.self, forKey: .friendDiscoveryKey)
        self.friendName = try? container.decode(String.self, forKey: .friendName)
        self.preferredLanguages = try? container.decode([String].self, forKey: .preferredLanguages)
        self.requireAuth = (try? container.decode(Bool.self, forKey: .requireAuthForProfileImage)) ?? false
        self.isBot = (try? container.decode(Bool.self, forKey: .isBot)) ?? false
        self.localUpdatedAt = (try? container.decode(Int64.self, forKey: .localUpdatedAt)) ?? -1
        
        super.init()
        
        self.dependency = decoder.extractDependency()
    }
    
    /// Encodes this object.
    ///
    /// - Parameter encoder: `Encoder` instance
    package func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodeCodingKeys.self)
        try container.encode(self.userId, forKey: .userId)
        try? container.encodeIfPresent(self.nickname, forKey: .nickname)
        try? container.encodeIfPresent(self.plainProfileImageURL, forKey: .profileURL)
        try? container.encodeIfPresent(self.connectionStatus, forKey: .isOnline)
        try container.encode(self.isActive, forKey: .isActive)
        try container.encode(self.lastSeenAt, forKey: .lastSeenAt)
        try? container.encodeIfPresent(self.metaDataMap.toDictionary(), forKey: .metadata)
        try? container.encodeIfPresent(self.friendDiscoveryKey, forKey: .friendDiscoveryKey)
        try? container.encodeIfPresent(self.friendName, forKey: .friendName)
        try? container.encodeIfPresent(self.preferredLanguages, forKey: .preferredLanguages)
        try container.encode(self.requireAuth, forKey: .requireAuthForProfileImage)
        try container.encode(self.isBot, forKey: .isBot)
        try container.encode(self.localUpdatedAt, forKey: .localUpdatedAt)
    }
    
    package func update(with user: AuthUser) {
        self.plainProfileImageURL = user.plainProfileImageURL
        self.nickname = user.nickname
        
        // Intentionally called `replaceAll(with: [Key: Value])`
        // instead of `replaceAll(with: SafeDictionary)`
        // since `replaceAll(with: SafeDictionary)` can cause deadlock
        // due to nested sync.
        let dictionary = user.metaDataMap.toDictionary()
        self.metaDataMap.replaceAll(with: dictionary)
        
        self.preferredLanguages = user.preferredLanguages
        self.requireAuth = user.requireAuth
    }
    
    package func updateIfUserIsNewer(with newUser: AuthUser) {
        if newUser.localUpdatedAt > self.localUpdatedAt {
            self.update(with: newUser)
        }
    }
    
    package func updateUserInfo(with dictionary: [String: Any]?) {
        guard let info = dictionary else { return }
        if let auth = info["require_auth_for_profile_image"] as? Bool {
            self.requireAuth = auth
        }
        
        if let nickname = info["nickname"] as? String {
            self.nickname = nickname
        }
        
        if let profileURL = info["profile_url"] as? String {
            self.plainProfileImageURL = profileURL
        }
    }
    
    /// Updates the database update timestamp (`localUpdatedAt`) for the user object.
    ///
    /// - Note: This ensures that the `localUpdatedAt` value reflects the most recent state,
    ///     allowing the system to compare and retain the latest user information.
    ///     It is recommended to call this method whenever the `User` object is initialized or updated.
    @discardableResult
    package func setLocalUpdateTimestamp(to timestamp: Int64) -> Self {
        self.localUpdatedAt = timestamp
        return self
    }
    
    package var isCurrentUser: Bool { stateData?.currentUserId == userId }
}

extension AuthUser: NSCopying {
    /// Compares this object with given other object.
    ///
    /// - Parameter object: `Any` instance
    /// - Returns: `true` if same otherwise `false`
    package override func isEqual(_ object: Any?) -> Bool {
        guard let other = object as? AuthUser else { return false }
        
        return userId == other.userId &&
            nickname == other.nickname &&
            plainProfileImageURL == other.plainProfileImageURL &&
            connectionStatus == other.connectionStatus &&
            isActive == other.isActive &&
            friendDiscoveryKey == other.friendDiscoveryKey &&
            friendName == other.friendName &&
            metaData == other.metaData &&
            preferredLanguages == other.preferredLanguages &&
            lastSeenAt == other.lastSeenAt &&
            requireAuth == other.requireAuth &&
            isBot == other.isBot
    }
    
    /// Copies this object
    ///
    /// - Parameter zone: optional `NSZone`
    /// - Returns: `User` instance
    @objc
    open func copy(with zone: NSZone? = nil) -> Any {
        return self.makeCodableCopy(decoder: SendbirdAuth.authDecoder)
    }
}

// MARK: - Hash logic
extension AuthUser {
    package override var hash: Int {
        var hasher = Hasher()
        hasher.combine(userId)
        hasher.combine(nickname)
        hasher.combine(plainProfileImageURL)
        hasher.combine(friendDiscoveryKey)
        hasher.combine(friendName)
        hasher.combine(metaData)
        hasher.combine(preferredLanguages)
        hasher.combine(requireAuth)
        return hasher.finalize()
    }
}
