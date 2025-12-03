//
//  DefaultRecordStat.swift
//  SendbirdChatSDK
//
//  Created by Jed Gyeong on 3/6/24.
//

import Foundation

@_spi(SendbirdInternal) public protocol DefaultRecordStatRepresentable: BaseStatType {
    func makeAdditionalData() -> [String: AnyCodable]?
}

extension DefaultRecordStatRepresentable {
    @_spi(SendbirdInternal) public func toDefaultRecordStat() -> DefaultRecordStat {
        DefaultRecordStat(
            statType: self.statType,
            timestamp: self.timestamp,
            statId: self.statId,
            isUploaded: self.isUploaded,
            data: self.makeAdditionalData()
        )
    }
}

@_spi(SendbirdInternal) public class DefaultRecordStat: BaseStat {}
