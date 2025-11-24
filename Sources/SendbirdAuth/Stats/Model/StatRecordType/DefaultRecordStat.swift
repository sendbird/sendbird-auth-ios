//
//  DefaultRecordStat.swift
//  SendbirdChatSDK
//
//  Created by Jed Gyeong on 3/6/24.
//

import Foundation

public protocol DefaultRecordStatRepresentable: BaseStatType {
    func makeAdditionalData() -> [String: AnyCodable]?
}

extension DefaultRecordStatRepresentable {
    public func toDefaultRecordStat() -> DefaultRecordStat {
        DefaultRecordStat(
            statType: self.statType,
            timestamp: self.timestamp,
            statId: self.statId,
            isUploaded: self.isUploaded,
            data: self.makeAdditionalData()
        )
    }
}

public class DefaultRecordStat: BaseStat {}
