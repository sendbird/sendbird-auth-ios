//
//  StatStorageHelper.swift
//  SendbirdChat
//
//  Created by Kai Lee on 2/21/25.
//

import Foundation

public class StatStorageHelper<Key: Hashable & Codable, RecordStatType: BaseStatType> {
    private let queue: SafeSerialQueue
    @UserDefault private var lastSentAt: Date?
    @CodableUserDefault private var internalStatWrappers: [Key: StatCodableWrapper<RecordStatType>]?
    
    private let statKeyGenerator: (RecordStatType) -> Key?
    
    public init<Keys: StatStorageKeyType>(
        statStorageKey: Keys,
        userDefaults: UserDefaults,
        statKeyGenerator: @escaping (RecordStatType) -> Key?
    ) {
        self.queue = SafeSerialQueue(label: statStorageKey.queue)
        self.statKeyGenerator = statKeyGenerator
        
        _internalStatWrappers = .init(statStorageKey.wrapper, userDefaults: userDefaults)
        _lastSentAt = .init(statStorageKey.lastSentAt, userDefaults: userDefaults)
        
        lastSentAt = Date(timeIntervalSince1970: 0)
        if internalStatWrappers == nil {
            internalStatWrappers = [:]
        }
    }
    
    // MARK: StatStorage
    public func loadLastSentAt() -> Date {
        lastSentAt ?? Date(timeIntervalSince1970: 0)
    }
    
    public func saveLastSentAt(_ lastSentAt: Date) {
        self.lastSentAt = lastSentAt
    }
    
    public func loadStat(for key: Key) -> RecordStatType? {
        internalStatWrappers?[key]?.baseStat
    }
    
    public func loadStats() -> [RecordStatType] {
        let allStats = Array(recordStatMap.values)
        
        return allStats
    }
    
    public func loadUnuploadedStats() -> [RecordStatType] {
        let allStats = Array(recordStatMap.values)
        
        let result = allStats.filter {
            $0.isUploaded == false
        }

        return result
    }
    
    public func loadUploadedStats() -> [RecordStatType] {
        let allStats = Array(recordStatMap.values)
        
        let result = allStats.filter {
            $0.isUploaded == true
        }
        
        return result
    }
    
    public func saveStats(_ stats: [RecordStatType]) {
        let dict = stats
            .reduce(into: [Key: StatCodableWrapper]()) { result, stat in
                if let key = statKeyGenerator(stat) {
                    result[key] = StatCodableWrapper(baseStat: stat)
                }
            }
        
        statWrappers = statWrappers?.merging(dict) { _, new in new }
    }
    
    public func removeAll() {
        internalStatWrappers = [:]
    }
    
    // MARK: StatStorage related
    private var statWrappers: [Key: StatCodableWrapper<RecordStatType>]? {
        get {
            queue.sync { 
                internalStatWrappers
            }
        }
        set {
            queue.sync { [weak self] in
                guard let self else { return }
                self.internalStatWrappers = newValue
            }
        }
    }
    
    private var recordStatMap: [Key: RecordStatType] {
        statWrappers?.compactMapValues { $0.baseStat } ?? [:]
    }
    
    // 수집하지 않기로 한 type의 stat은 삭제.
    public func remove(disallowedStatTypes: Set<StatType>) {
        statWrappers = statWrappers?.filter({ element in
            disallowedStatTypes.contains(element.value.baseStat.statType) == false
        })
    }
    
    // 업로드한 stat은 삭제
    public func removeUploadedStats() {
        statWrappers = statWrappers?.filter({ element in
            if element.value.baseStat.isUploaded == false {
                return true
            }
            
            return false
        })
    }
}
