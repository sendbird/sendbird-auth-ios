//
//  DailyRecordStatStorage.swift
//  SendbirdChatSDK
//
//  Created by Ernest Hong on 2022/12/14.
//

import Foundation

@_spi(SendbirdInternal) public class DailyRecordStatStorage: StatStorage {
    @_spi(SendbirdInternal) public let storageHelper: StatStorageHelper<DailyRecordKey, DailyRecordStat>
    
    @_spi(SendbirdInternal) public init(userDefaults: UserDefaults) {
        storageHelper = StatStorageHelper(
            statStorageKey: StorageKey(),
            userDefaults: userDefaults,
            statKeyGenerator: { $0.key })
    }
    
    // MARK: - For convenience
    @_spi(SendbirdInternal) public var uploadCandidateDailyRecordStats: [DailyRecordStat] {
        loadUnuploadedStats()
            .filter { $0.key.isSameDate(with: Date.now) == false }
    }

    @_spi(SendbirdInternal) public var dailyRecordStats: [DailyRecordStat] {
        loadStats()
    }
    
    @_spi(SendbirdInternal) public var unuploadedDailyRecordStats: [DailyRecordStat] {
        loadUnuploadedStats()
    }
    
    @_spi(SendbirdInternal) public func upsert(stat: DailyRecordStat) throws {
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
    
    @_spi(SendbirdInternal) public func markAsUploaded(stats: [DailyRecordStat]) {
        stats.forEach {
            $0.markAsUploaded()
            saveStats([$0])
        }
    }
    
    @_spi(SendbirdInternal) public func getDailyRecordStat(timestamp: Int64, statType: StatType) -> DailyRecordStat? {
        let key = DailyRecordKey(date: Date(milliSeconds: timestamp), statType: statType)
        
        return storageHelper.loadStat(for: key)
    }
}

extension DailyRecordStatStorage {
    @_spi(SendbirdInternal) public struct StorageKey: StatStorageKeyType {
        @_spi(SendbirdInternal) public let lastSentAt = "com.sendbird.sdk.chat.stat.daily_record.oldest_stat_timestamp"
        @_spi(SendbirdInternal) public let wrapper = "com.sendbird.sdk.chat.stat.daily_record.stats.wrapper"
        @_spi(SendbirdInternal) public let queue = "com.sendbird.sdk.chat.stat.daily_record.stats.queue"
    }
}
