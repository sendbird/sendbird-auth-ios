//
//  NotificationRecordStatStorage.swift
//  SendbirdChatSDK
//
//  Created by Jed Gyeong on 2/28/24.
//

import Foundation

public final class NotificationRecordStatStorage: StatStorage {
    public let storageHelper: StatStorageHelper<String, NotificationStat>
    
    public init(userDefaults: UserDefaults) {
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
    public struct StorageKey: StatStorageKeyType {
        public let lastSentAt = "com.sendbird.sdk.chat.stat.realtime.oldest_stat_timestamp"
        public let wrapper = "com.sendbird.sdk.chat.stat.realtime_record.stats.storage"
        public let queue  = "com.sendbird.sdk.chat.stat.realtime_record.stats.queue"
    }
}
