//
//  DefaultRecordStatStorage.swift
//  SendbirdChatSDK
//
//  Created by Jed Gyeong on 3/6/24.
//

import Foundation

@_spi(SendbirdInternal) public final class DefaultRecordStatStorage: StatStorage {
    @_spi(SendbirdInternal) public let storageHelper: StatStorageHelper<String, DefaultRecordStat>
    
    @_spi(SendbirdInternal) public init(userDefaults: UserDefaults) {
        self.storageHelper = StatStorageHelper(
            statStorageKey: StorageKey(),
            userDefaults: userDefaults,
            statKeyGenerator: { $0.statId })
    }
}

extension DefaultRecordStatStorage {
    @_spi(SendbirdInternal) public struct StorageKey: StatStorageKeyType {
        @_spi(SendbirdInternal) public let lastSentAt = "com.sendbird.sdk.chat.stat.default.oldest_stat_timestamp"
        @_spi(SendbirdInternal) public let wrapper = "com.sendbird.sdk.chat.stat.default_record.stats.wrapper"
        @_spi(SendbirdInternal) public let queue = "com.sendbird.sdk.chat.stat.default_record.stats.queue"
    }
}
