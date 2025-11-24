//
//  DefaultRecordStatStorage.swift
//  SendbirdChatSDK
//
//  Created by Jed Gyeong on 3/6/24.
//

import Foundation

public final class DefaultRecordStatStorage: StatStorage {
    public let storageHelper: StatStorageHelper<String, DefaultRecordStat>
    
    public init(userDefaults: UserDefaults) {
        self.storageHelper = StatStorageHelper(
            statStorageKey: StorageKey(),
            userDefaults: userDefaults,
            statKeyGenerator: { $0.statId })
    }
}

extension DefaultRecordStatStorage {
    public struct StorageKey: StatStorageKeyType {
        public let lastSentAt = "com.sendbird.sdk.chat.stat.default.oldest_stat_timestamp"
        public let wrapper = "com.sendbird.sdk.chat.stat.default_record.stats.wrapper"
        public let queue = "com.sendbird.sdk.chat.stat.default_record.stats.queue"
    }
}
