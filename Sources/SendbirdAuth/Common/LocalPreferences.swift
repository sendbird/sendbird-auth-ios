//
//  PersistentStorage.swift
//  SendbirdChat
//
//  Created by Wooyoung Chung on 9/22/21.
//

import Foundation

@_spi(SendbirdInternal) public final class LocalPreferences {
    
    private let suiteName: String
    private let userDefault: UserDefaults?
    
    @_spi(SendbirdInternal) public init(suiteName: String) {
        self.suiteName = suiteName
        self.userDefault = UserDefaults(suiteName: suiteName)
        assert(userDefault != nil, "UserDefaults(suiteName: \(suiteName)) must not be nil")
    }
    
    @_spi(SendbirdInternal) public func set<T: Encodable>(value: T?, forKey key: CustomStringConvertible) {
        if let encoded = try? JSONEncoder().encode(value) {
            userDefault?.set(encoded, forKey: key.description)
        } else {
            userDefault?.set(value, forKey: key.description)
        }
    }
    
    @_spi(SendbirdInternal) public func value<T: Decodable>(forKey key: CustomStringConvertible) -> T? {
        if let result = userDefault?.data(forKey: key.description),
           let decoded = try? SendbirdAuth.authDecoder.decode(T.self, from: result) {
            return decoded
        } else {
            return userDefault?.value(forKey: key.description) as? T
        }
    }
    
    @_spi(SendbirdInternal) public func set<T>(value: T?, forKey key: CustomStringConvertible) {
        userDefault?.set(value, forKey: key.description)
    }
    
    @_spi(SendbirdInternal) public func value<T>(forKey key: CustomStringConvertible) -> T? {
        return userDefault?.value(forKey: key.description) as? T
    }
    
    @_spi(SendbirdInternal) public func remove(forKey key: CustomStringConvertible) {
        userDefault?.removeObject(forKey: key.description)
    }
    
    @_spi(SendbirdInternal) public func removeAll() {
        userDefault?.removePersistentDomain(forName: suiteName)
    }
}

@_spi(SendbirdInternal) public enum PreferenceKey: String, CustomStringConvertible {
    @_spi(SendbirdInternal) public var description: String { rawValue }
    
    case useNativeWS = "KEY_USE_NATIVE_WS"
    case configApiTs = "KEY_CONFIG_API_TS"
    
    @available(*, deprecated, message: "This case value has been deprecated since [NEXT_VERSION]")
    case customAPIHost = "KEY_CUSTOM_API_HOST"
    @available(*, deprecated, message: "This case value has been deprecated since [NEXT_VERSION]")
    case customWsHost = "KEY_CUSTOM_WS_HOST"
}

@_spi(SendbirdInternal) public enum LocalCachePreferenceKey: String, CustomStringConvertible {
    @_spi(SendbirdInternal) public var description: String { rawValue }
    
    case currentUser = "KEY_CURRENT_USER"
    case currentAppInfo = "KEY_CURRENT_APP_INFO"
    case currentAppId = "KEY_CURRENT_APPID"
    case reconnectConfig = "KEY_CONNECTION_CONFIG"
    case notificationEnabled = "KEY_NOTIFICATION_ENABLED"
    
    @_spi(SendbirdInternal) public enum Channel: String, CustomStringConvertible {
        @_spi(SendbirdInternal) public var description: String { rawValue }
        
        case syncTokenFromLastMsg = "KEY_LAST_CHANNEL_SYNCED_TOKEN_FROM_LASTMESSAGE"
        case syncTokenFromChronological = "KEY_LAST_CHANNEL_SYNCED_TOKEN_FROM_CHRONOLOGICAL"
        case syncTokenFromAlphabetical = "KEY_LAST_CHANNEL_SYNCED_TOKEN_FROM_ALPHABETICAL"
        
        case syncChannelUrlsByLastMsg = "KEY_SYNCED_CHANNEL_URLS_BY_LASTMESSAGE"
        case syncChannelUrlsByChronological = "KEY_SYNCED_CHANNEL_URLS_BY_CHRONOLOGICAL"
        case syncChannelUrlsByAlphabetical = "KEY_SYNCED_CHANNEL_URLS_BY_ALPHABETICAL"
        
        case syncCompleted = "KEY_CHANNEL_SYNC_COMPLETE"
        case msgStartingPoint = "KEY_MESSAGE_STARTING_POINT"
        case fastestCompletedOrder = "KEY_WHICH_ORDER_DID_COMPLETE"
        
        @_spi(SendbirdInternal) public enum ChangeLogs: String, CustomStringConvertible {
            @_spi(SendbirdInternal) public var description: String { rawValue }
            
            case syncTokenByLastMsg = "KEY_LAST_CHANNEL_CHANGELOGS_SYNC_TOKEN_BY_LASTMESSAGE"
            case syncTokenByChronological = "KEY_LAST_CHANNEL_CHANGELOGS_SYNC_TOKEN_BY_CHRONOLOGICAL"
            case syncTokenByAlphabetical = "KEY_LAST_CHANNEL_CHANGELOGS_SYNC_TOKEN_BY_ALPHABETICAL"
            case syncToken = "KEY_LAST_CHANNEL_CHANGELOGS_SYNC_TOKEN"
            case syncTimestamp = "KEY_LAST_CHANNEL_CHANGELOGS_SYNC_TS"
        }
    }
}
