//
//  NotificationRecordStatStorage.swift
//  SendbirdChatSDK
//
//  Created by Jed Gyeong on 2/28/24.
//

import Foundation

@_spi(SendbirdInternal) public final class NotificationRecordStatStorage: StatStorage {
    @_spi(SendbirdInternal) public let storageHelper: StatStorageHelper<String, NotificationStat>
    
    @_spi(SendbirdInternal) public init(userDefaults: UserDefaults) {
        self.storageHelper = StatStorageHelper(
            statStorageKey: StorageKey(),
            userDefaults: userDefaults,
            statKeyGenerator: { $0.statId })
    }
}

extension NotificationRecordStatStorage {
    /// INFO: The configuration endpoint related to realtime stats has been changed in the TBD version due to rate limiting.
    /// Since realtime was only being used in Notifications, all naming related to realtime stats has been changed to Notifications.
    /// However, to maintain backward compatibility with older versions, the key values coming down as "realtime" will be retained.
    @_spi(SendbirdInternal) public struct StorageKey: StatStorageKeyType {
        @_spi(SendbirdInternal) public let lastSentAt = "com.sendbird.sdk.chat.stat.realtime.oldest_stat_timestamp"
        @_spi(SendbirdInternal) public let wrapper = "com.sendbird.sdk.chat.stat.realtime_record.stats.storage"
        @_spi(SendbirdInternal) public let queue  = "com.sendbird.sdk.chat.stat.realtime_record.stats.queue"
    }
}
