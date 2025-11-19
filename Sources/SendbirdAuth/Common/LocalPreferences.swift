//
//  PersistentStorage.swift
//  SendbirdChat
//
//  Created by Wooyoung Chung on 9/22/21.
//

import Foundation

package final class LocalPreferences {
    
    private let suiteName: String
    private let userDefault: UserDefaults?
    
    package init(suiteName: String) {
        self.suiteName = suiteName
        self.userDefault = UserDefaults(suiteName: suiteName)
        assert(userDefault != nil, "UserDefaults(suiteName: \(suiteName)) must not be nil")
    }
    
    package func set<T: Encodable>(value: T?, forKey key: CustomStringConvertible) {
        if let encoded = try? JSONEncoder().encode(value) {
            userDefault?.set(encoded, forKey: key.description)
        } else {
            userDefault?.set(value, forKey: key.description)
        }
    }
    
    package func value<T: Decodable>(forKey key: CustomStringConvertible) -> T? {
        if let result = userDefault?.data(forKey: key.description),
           let decoded = try? SendbirdAuth.authDecoder.decode(T.self, from: result) {
            return decoded
        } else {
            return userDefault?.value(forKey: key.description) as? T
        }
    }
    
    package func set<T>(value: T?, forKey key: CustomStringConvertible) {
        userDefault?.set(value, forKey: key.description)
    }
    
    package func value<T>(forKey key: CustomStringConvertible) -> T? {
        return userDefault?.value(forKey: key.description) as? T
    }
    
    package func remove(forKey key: CustomStringConvertible) {
        userDefault?.removeObject(forKey: key.description)
    }
    
    package func removeAll() {
        userDefault?.removePersistentDomain(forName: suiteName)
    }
}

package enum PreferenceKey: String, CustomStringConvertible {
    package var description: String { rawValue }
    
    case useNativeWS = "KEY_USE_NATIVE_WS"
    case configApiTs = "KEY_CONFIG_API_TS"
    
    case customAPIHost = "KEY_CUSTOM_API_HOST"
    case customWsHost = "KEY_CUSTOM_WS_HOST"
}

package enum LocalCachePreferenceKey: String, CustomStringConvertible {
    package var description: String { rawValue }
    
    case currentUser = "KEY_CURRENT_USER"
    case currentAppInfo = "KEY_CURRENT_APP_INFO"
    case currentAppId = "KEY_CURRENT_APPID"
    case reconnectConfig = "KEY_CONNECTION_CONFIG"
    case notificationEnabled = "KEY_NOTIFICATION_ENABLED"
    
    package enum Channel: String, CustomStringConvertible {
        package var description: String { rawValue }
        
        case syncTokenFromLastMsg = "KEY_LAST_CHANNEL_SYNCED_TOKEN_FROM_LASTMESSAGE"
        case syncTokenFromChronological = "KEY_LAST_CHANNEL_SYNCED_TOKEN_FROM_CHRONOLOGICAL"
        case syncTokenFromAlphabetical = "KEY_LAST_CHANNEL_SYNCED_TOKEN_FROM_ALPHABETICAL"
        
        case syncChannelUrlsByLastMsg = "KEY_SYNCED_CHANNEL_URLS_BY_LASTMESSAGE"
        case syncChannelUrlsByChronological = "KEY_SYNCED_CHANNEL_URLS_BY_CHRONOLOGICAL"
        case syncChannelUrlsByAlphabetical = "KEY_SYNCED_CHANNEL_URLS_BY_ALPHABETICAL"
        
        case syncCompleted = "KEY_CHANNEL_SYNC_COMPLETE"
        case msgStartingPoint = "KEY_MESSAGE_STARTING_POINT"
        case fastestCompletedOrder = "KEY_WHICH_ORDER_DID_COMPLETE"
        
        package enum ChangeLogs: String, CustomStringConvertible {
            package var description: String { rawValue }
            
            case syncTokenByLastMsg = "KEY_LAST_CHANNEL_CHANGELOGS_SYNC_TOKEN_BY_LASTMESSAGE"
            case syncTokenByChronological = "KEY_LAST_CHANNEL_CHANGELOGS_SYNC_TOKEN_BY_CHRONOLOGICAL"
            case syncTokenByAlphabetical = "KEY_LAST_CHANNEL_CHANGELOGS_SYNC_TOKEN_BY_ALPHABETICAL"
            case syncToken = "KEY_LAST_CHANNEL_CHANGELOGS_SYNC_TOKEN"
            case syncTimestamp = "KEY_LAST_CHANNEL_CHANGELOGS_SYNC_TS"
        }
    }
}
