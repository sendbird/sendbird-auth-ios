//
//  StatStorage.swift
//  SendbirdChatSDK
//
//  Created by Ernest Hong on 2022/05/30.
//

import Foundation

public protocol StatStorage {
    associatedtype Key: Hashable & Codable
    associatedtype Value: BaseStatType
    
    typealias RecordStatType = Value
    
    func loadLastSentAt() -> Date
    func saveLastSentAt(_ lastSentAt: Date)
    func loadStats() -> [RecordStatType]
    func loadUploadedStats() -> [RecordStatType]
    func loadUnuploadedStats() -> [RecordStatType]
    func saveStats(_ stats: [RecordStatType])
    func removeAll()
    
    func remove(disallowedStatTypes: Set<StatType>)
    func removeUploadedStats()
    
    var storageHelper: StatStorageHelper<Key, RecordStatType> { get }
}

public extension StatStorage {
    func loadLastSentAt() -> Date {
        storageHelper.loadLastSentAt()
    }
    
    func saveLastSentAt(_ lastSentAt: Date) {
        storageHelper.saveLastSentAt(lastSentAt)
    }
    
    func loadStats() -> [RecordStatType] {
        storageHelper.loadStats()
    }
    
    func loadUploadedStats() -> [RecordStatType] {
        storageHelper.loadUploadedStats()
    }
    
    func loadUnuploadedStats() -> [RecordStatType] {
        storageHelper.loadUnuploadedStats()
    }
    
    func saveStats(_ stats: [RecordStatType]) {
        storageHelper.saveStats(stats)
    }
    
    func removeAll() {
        storageHelper.removeAll()
    }
    
    func remove(disallowedStatTypes: Set<StatType>) {
        storageHelper.remove(disallowedStatTypes: disallowedStatTypes)
    }
    
    func removeUploadedStats() {
        storageHelper.removeUploadedStats()
    }
}
