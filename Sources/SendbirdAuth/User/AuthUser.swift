//
//  User.swift
//  SendbirdChat
//
//  Created by Minhyuk Kim on 2021/07/08.
//

import Foundation

@_spi(SendbirdInternal) public class AuthUser: NSObject, Codable, Identifiable {

    // MARK: - Mutable State (Thread-safe)

    private struct MutableState: Equatable {
        var nickname: String
        var plainProfileImageURL: String?
        var connectionStatus: AuthUserConnectionStatus
        var lastSeenAt: Int64
        var preferredLanguages: [String]?
        var requireAuth: Bool
        var localUpdatedAt: Int64
    }

    private let lock = NSLock()
    private var state: MutableState

    private func stateSnapshot() -> MutableState {
        lock.withLock { state }
    }

    // MARK: - Immutable Properties

    /// Identifier for the user conforming to `Identifiable`
    @_spi(SendbirdInternal) public var id: String { self.userId }

    /// User ID. This has to be unique.
    @_spi(SendbirdInternal) public let userId: String

    /// Represents the user is activated. This property is changed by the [Platform API](https://docs.sendbird.com/platform#user_3_update_a_user)
    @_spi(SendbirdInternal) public let isActive: Bool

    /// Discovery key for friend
    @_spi(SendbirdInternal) public let friendDiscoveryKey: String?

    /// User name for friend
    @_spi(SendbirdInternal) public let friendName: String?

    /// Shows if the user is a bot or not.
    /// - Since: 4.9.4
    @_spi(SendbirdInternal) public let isBot: Bool

    /// Meta data.
    @_spi(SendbirdInternal) public var metaData: [String: String] { self.metaDataMap.toDictionary() }

    @_spi(SendbirdInternal) public var metaDataMap: SafeDictionary<String, String>

    // MARK: - Thread-safe Accessors

    /// User nickname.
    @_spi(SendbirdInternal) public var nickname: String {
        get { lock.withLock { state.nickname } }
        set { lock.withLock { state.nickname = newValue } }
    }

    /// The profile image URL without the `ekey`.
    /// - Since: 3.0.194
    @_spi(SendbirdInternal) public var plainProfileImageURL: String? {
        get { lock.withLock { state.plainProfileImageURL } }
        set { lock.withLock { state.plainProfileImageURL = newValue } }
    }

    /// User connection status. This is defined in `AuthUserConnectionStatus`.
    @_spi(SendbirdInternal) public var connectionStatus: AuthUserConnectionStatus {
        get { lock.withLock { state.connectionStatus } }
        set { lock.withLock { state.connectionStatus = newValue } }
    }

    /// The lastest time when the user became offline.
    @_spi(SendbirdInternal) public var lastSeenAt: Int64 {
        get { lock.withLock { state.lastSeenAt } }
        set { lock.withLock { state.lastSeenAt = newValue } }
    }

    /// User's preferred language. Used for translating messages.
    /// - Since: 3.0.159
    @_spi(SendbirdInternal) public var preferredLanguages: [String]? {
        get { lock.withLock { state.preferredLanguages } }
        set { lock.withLock { state.preferredLanguages = newValue } }
    }

    @_spi(SendbirdInternal) public var requireAuth: Bool {
        get { lock.withLock { state.requireAuth } }
        set { lock.withLock { state.requireAuth = newValue } }
    }

    /// The timestamp indicating the last update time of the user.
    /// - Note: Defaults to `-1`, representing that the user has not been updated.
    /// - Since: 4.24.1
    @_spi(SendbirdInternal) public private(set) var localUpdatedAt: Int64 {
        get { lock.withLock { state.localUpdatedAt } }
        set { lock.withLock { state.localUpdatedAt = newValue } }
    }

    // MARK: - Dependencies

    @DependencyWrapper @_spi(SendbirdInternal) public var dependency: Dependency?
    @_spi(SendbirdInternal) public var requestQueue: RequestQueue? { dependency?.requestQueue }
    private var stateData: ConnectionStateData? { dependency?.stateData }
    @_spi(SendbirdInternal) public var service: QueueService? { dependency?.service }
    private var eKey: String? { dependency?.commonSharedData.eKey }

    // MARK: - Initializers

    @_spi(SendbirdInternal) public init(
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
        self.isActive = isActive
        self.friendDiscoveryKey = discoveryKey
        self.friendName = friendName
        self.isBot = isBot
        self.metaDataMap = .init(metaData)

        self.state = MutableState(
            nickname: nickname,
            plainProfileImageURL: profileURL,
            connectionStatus: connectionStatus,
            lastSeenAt: lastSeenAt,
            preferredLanguages: prefLangauges,
            requireAuth: requireAuth,
            localUpdatedAt: localUpdatedAt
        )

        super.init()

        self.dependency = dependency
    }

    /// Default constructor.
    ///
    /// - Parameter decoder: `Decoder` instance
    @_spi(SendbirdInternal) required public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodeCodingKeys.self)

        self.userId =
            (try? container.decode(String.self, forKey: .userId)) ??
            (try? container.decode(String.self, forKey: .guestId)) ?? ""

        self.isActive = (try? container.decode(Bool.self, forKey: .isActive)) ?? true
        self.friendDiscoveryKey = try? container.decode(String.self, forKey: .friendDiscoveryKey)
        self.friendName = try? container.decode(String.self, forKey: .friendName)
        self.isBot = (try? container.decode(Bool.self, forKey: .isBot)) ?? false

        let metaData = try? container.decode([String: String].self, forKey: .metadata)
        self.metaDataMap = .init(metaData ?? [:])

        let nickname =
            (try? container.decode(String.self, forKey: .nickname)) ??
            (try? container.decode(String.self, forKey: .name)) ?? ""

        let plainProfileImageURL =
            (try? container.decode(String.self, forKey: .profileURL)) ??
            (try? container.decode(String.self, forKey: .image)) ?? nil

        let connectionStatus = (try? container.decode(AuthUserConnectionStatus.self, forKey: .isOnline)) ?? .nonAvailable
        let lastSeenAt = (try? container.decode(Int64.self, forKey: .lastSeenAt)) ?? 0
        let preferredLanguages = try? container.decode([String].self, forKey: .preferredLanguages)
        let requireAuth = (try? container.decode(Bool.self, forKey: .requireAuthForProfileImage)) ?? false
        let localUpdatedAt = (try? container.decode(Int64.self, forKey: .localUpdatedAt)) ?? -1

        self.state = MutableState(
            nickname: nickname,
            plainProfileImageURL: plainProfileImageURL,
            connectionStatus: connectionStatus,
            lastSeenAt: lastSeenAt,
            preferredLanguages: preferredLanguages,
            requireAuth: requireAuth,
            localUpdatedAt: localUpdatedAt
        )

        super.init()

        self.dependency = decoder.extractDependency()
    }

    /// Encodes this object.
    ///
    /// - Parameter encoder: `Encoder` instance
    @_spi(SendbirdInternal) public func encode(to encoder: Encoder) throws {
        let snapshot = stateSnapshot()
        var container = encoder.container(keyedBy: CodeCodingKeys.self)

        // Immutable properties
        try container.encode(self.userId, forKey: .userId)
        try container.encode(self.isActive, forKey: .isActive)
        try? container.encodeIfPresent(self.friendDiscoveryKey, forKey: .friendDiscoveryKey)
        try? container.encodeIfPresent(self.friendName, forKey: .friendName)
        try container.encode(self.isBot, forKey: .isBot)
        try? container.encodeIfPresent(self.metaDataMap.toDictionary(), forKey: .metadata)

        // Mutable properties (from snapshot)
        try? container.encodeIfPresent(snapshot.nickname, forKey: .nickname)
        try? container.encodeIfPresent(snapshot.plainProfileImageURL, forKey: .profileURL)
        try? container.encodeIfPresent(snapshot.connectionStatus, forKey: .isOnline)
        try container.encode(snapshot.lastSeenAt, forKey: .lastSeenAt)
        try? container.encodeIfPresent(snapshot.preferredLanguages, forKey: .preferredLanguages)
        try container.encode(snapshot.requireAuth, forKey: .requireAuthForProfileImage)
        try container.encode(snapshot.localUpdatedAt, forKey: .localUpdatedAt)
    }

    // MARK: - Update Methods

    @_spi(SendbirdInternal) public func update(with user: AuthUser) {
        // Take snapshot first to avoid deadlock
        let userState = user.stateSnapshot()

        lock.withLock {
            state.plainProfileImageURL = userState.plainProfileImageURL
            state.nickname = userState.nickname
            state.preferredLanguages = userState.preferredLanguages
            state.requireAuth = userState.requireAuth
        }

        // Intentionally called `replaceAll(with: [Key: Value])`
        // instead of `replaceAll(with: SafeDictionary)`
        // since `replaceAll(with: SafeDictionary)` can cause deadlock
        // due to nested sync.
        let dictionary = user.metaDataMap.toDictionary()
        self.metaDataMap.replaceAll(with: dictionary)
    }

    @_spi(SendbirdInternal) public func updateIfUserIsNewer(with newUser: AuthUser) {
        // Take snapshot first to avoid deadlock
        let newUserLocalUpdatedAt = newUser.localUpdatedAt

        let shouldUpdate = lock.withLock {
            newUserLocalUpdatedAt > state.localUpdatedAt
        }

        if shouldUpdate {
            self.update(with: newUser)
        }
    }

    @_spi(SendbirdInternal) public func updateUserInfo(with dictionary: [String: Any]?) {
        guard let info = dictionary else { return }

        lock.withLock {
            if let auth = info["require_auth_for_profile_image"] as? Bool {
                state.requireAuth = auth
            }

            if let nickname = info["nickname"] as? String {
                state.nickname = nickname
            }

            if let profileURL = info["profile_url"] as? String {
                state.plainProfileImageURL = profileURL
            }
        }
    }

    /// Updates the database update timestamp (`localUpdatedAt`) for the user object.
    ///
    /// - Note: This ensures that the `localUpdatedAt` value reflects the most recent state,
    ///     allowing the system to compare and retain the latest user information.
    ///     It is recommended to call this method whenever the `User` object is initialized or updated.
    @discardableResult
    @_spi(SendbirdInternal) public func setLocalUpdateTimestamp(to timestamp: Int64) -> Self {
        lock.withLock {
            state.localUpdatedAt = timestamp
        }
        return self
    }

    @_spi(SendbirdInternal) public var isCurrentUser: Bool { stateData?.currentUserId == userId }
}

// MARK: - NSCopying

extension AuthUser: NSCopying {
    /// Compares this object with given other object.
    ///
    /// - Parameter object: `Any` instance
    /// - Returns: `true` if same otherwise `false`
    @_spi(SendbirdInternal) public override func isEqual(_ object: Any?) -> Bool {
        guard let otherUser = object as? AuthUser else { return false }

        // Take snapshots first to avoid deadlock when comparing two AuthUser objects
        let selfState = self.stateSnapshot()
        let otherState = otherUser.stateSnapshot()

        // Immutable properties
        guard userId == otherUser.userId &&
              isActive == otherUser.isActive &&
              friendDiscoveryKey == otherUser.friendDiscoveryKey &&
              friendName == otherUser.friendName &&
              isBot == otherUser.isBot &&
              metaData == otherUser.metaData
        else { return false }

        // Mutable properties (from snapshot)
        return selfState.nickname == otherState.nickname &&
            selfState.plainProfileImageURL == otherState.plainProfileImageURL &&
            selfState.connectionStatus == otherState.connectionStatus &&
            selfState.lastSeenAt == otherState.lastSeenAt &&
            selfState.preferredLanguages == otherState.preferredLanguages &&
            selfState.requireAuth == otherState.requireAuth
    }

    /// Copies this object
    ///
    /// - Parameter zone: optional `NSZone`
    /// - Returns: `User` instance
    @objc
    open func copy(with zone: NSZone? = nil) -> Any {
        return self.makeCodableCopy(decoder: dependency?.decoder ?? SendbirdAuth.authDecoder)
    }
}

// MARK: - Hash logic

extension AuthUser {
    @_spi(SendbirdInternal) public override var hash: Int {
        let snapshot = stateSnapshot()
        var hasher = Hasher()

        // Immutable properties
        hasher.combine(userId)
        hasher.combine(friendDiscoveryKey)
        hasher.combine(friendName)
        hasher.combine(metaData)

        // Mutable properties (from snapshot)
        hasher.combine(snapshot.nickname)
        hasher.combine(snapshot.plainProfileImageURL)
        hasher.combine(snapshot.preferredLanguages)
        hasher.combine(snapshot.requireAuth)

        return hasher.finalize()
    }
}
