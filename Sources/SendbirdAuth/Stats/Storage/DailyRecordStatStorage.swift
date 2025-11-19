//
//  DailyRecordStatStorage.swift
//  SendbirdChatSDK
//
//  Created by Ernest Hong on 2022/12/14.
//

import Foundation

package class DailyRecordStatStorage: StatStorage {
    package let storageHelper: StatStorageHelper<DailyRecordKey, DailyRecordStat>
    
    package init(userDefaults: UserDefaults) {
        storageHelper = StatStorageHelper(
            statStorageKey: StorageKey(),
            userDefaults: userDefaults,
            statKeyGenerator: { $0.key })
    }
    
    // MARK: - For convenience
    package var uploadCandidateDailyRecordStats: [DailyRecordStat] {
        loadUnuploadedStats()
            .filter { $0.key.isSameDate(with: Date.now) == false }
    }

    package var dailyRecordStats: [DailyRecordStat] {
        loadStats()
    }
    
    package var unuploadedDailyRecordStats: [DailyRecordStat] {
        loadUnuploadedStats()
    }
    
    package func upsert(stat: DailyRecordStat) throws {
        let previousStat = storageHelper.loadStat(for: stat.key)
        let isUploaded = previousStat?.isUploaded ?? false
        
        guard isUploaded == false else { return }
        
        if let previousStat {
            let newStat = (previousStat.updated(with: stat))
            saveStats([newStat])
        } else {
            saveStats([stat])
        }
    }
    
    package func markAsUploaded(stats: [DailyRecordStat]) {
        stats.forEach {
            $0.markAsUploaded()
            saveStats([$0])
        }
    }
    
    package func getDailyRecordStat(timestamp: Int64, statType: StatType) -> DailyRecordStat? {
        let key = DailyRecordKey(date: Date(milliSeconds: timestamp), statType: statType)
        
        return storageHelper.loadStat(for: key)
    }
}

extension DailyRecordStatStorage {
    package struct StorageKey: StatStorageKeyType {
        package let lastSentAt = "com.sendbird.sdk.chat.stat.daily_record.oldest_stat_timestamp"
        package let wrapper = "com.sendbird.sdk.chat.stat.daily_record.stats.wrapper"
        package let queue = "com.sendbird.sdk.chat.stat.daily_record.stats.queue"
    }
}
