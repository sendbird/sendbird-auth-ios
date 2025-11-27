//
//  DailyRecordStatType.swift
//  SendbirdChat
//
//  Created by Kai Lee on 8/25/25.
//

import Foundation

/// Defines a protocol-oriented alternative to the previous `Stat` class inheritance structure.
/// For more details, refer to the [document](https://sendbird.atlassian.net/wiki/x/FIByy)
@_spi(SendbirdInternal) public protocol DailyRecordStatType: BaseStatType {
    var key: DailyRecordKey { get }
    func updated(with newValue: Self) -> Self
    func makeAdditionalData() -> [String: AnyCodable]?
}

extension DailyRecordStatType {
    @_spi(SendbirdInternal) public var key: DailyRecordKey {
        DailyRecordKey(
            date: Date(milliSeconds: timestamp),
            statType: statType
        )
    }
    
    @_spi(SendbirdInternal) public func makeAdditionalData() -> [String: AnyCodable]? {
        return nil
    }
    
    @_spi(SendbirdInternal) public func toDailyRecordStat() -> DailyRecordStat {
        DailyRecordStat(
            statType: self.statType,
            timestamp: self.timestamp,
            statId: self.statId,
            isUploaded: self.isUploaded,
            data: self.makeAdditionalData()
        )
    }
}
