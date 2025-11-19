//
//  DefaultRecordStatStorage.swift
//  SendbirdChatSDK
//
//  Created by Jed Gyeong on 3/6/24.
//

import Foundation

package final class DefaultRecordStatStorage: StatStorage {
    package let storageHelper: StatStorageHelper<String, DefaultRecordStat>
    
    package init(userDefaults: UserDefaults) {
        self.storageHelper = StatStorageHelper(
            statStorageKey: StorageKey(),
            userDefaults: userDefaults,
            statKeyGenerator: { $0.statId })
    }
}

extension DefaultRecordStatStorage {
    package struct StorageKey: StatStorageKeyType {
        package let lastSentAt = "com.sendbird.sdk.chat.stat.default.oldest_stat_timestamp"
        package let wrapper = "com.sendbird.sdk.chat.stat.default_record.stats.wrapper"
        package let queue = "com.sendbird.sdk.chat.stat.default_record.stats.queue"
    }
}
