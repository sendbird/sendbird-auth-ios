//
//  DailyRecordStatStorage.swift
//  SendbirdChatSDK
//
//  Created by Ernest Hong on 2022/12/14.
//

import Foundation

public class DailyRecordStatStorage: StatStorage {
    public let storageHelper: StatStorageHelper<DailyRecordKey, DailyRecordStat>
    
    public init(userDefaults: UserDefaults) {
        storageHelper = StatStorageHelper(
            statStorageKey: StorageKey(),
            userDefaults: userDefaults,
            statKeyGenerator: { $0.key })
    }
    
    // MARK: - For convenience
    public var uploadCandidateDailyRecordStats: [DailyRecordStat] {
        loadUnuploadedStats()
            .filter { $0.key.isSameDate(with: Date.now) == false }
    }

    public var dailyRecordStats: [DailyRecordStat] {
        loadStats()
    }
    
    public var unuploadedDailyRecordStats: [DailyRecordStat] {
        loadUnuploadedStats()
    }
    
    public func upsert(stat: DailyRecordStat) throws {
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
    
    public func markAsUploaded(stats: [DailyRecordStat]) {
        stats.forEach {
            $0.markAsUploaded()
            saveStats([$0])
        }
    }
    
    public func getDailyRecordStat(timestamp: Int64, statType: StatType) -> DailyRecordStat? {
        let key = DailyRecordKey(date: Date(milliSeconds: timestamp), statType: statType)
        
        return storageHelper.loadStat(for: key)
    }
}

extension DailyRecordStatStorage {
    public struct StorageKey: StatStorageKeyType {
        public let lastSentAt = "com.sendbird.sdk.chat.stat.daily_record.oldest_stat_timestamp"
        public let wrapper = "com.sendbird.sdk.chat.stat.daily_record.stats.wrapper"
        public let queue = "com.sendbird.sdk.chat.stat.daily_record.stats.queue"
    }
}
