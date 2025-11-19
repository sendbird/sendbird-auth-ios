//
//  DailyRecordStat.swift
//  SendbirdChatSDK
//
//  Created by Ernest Hong on 2022/12/14.
//

import Foundation

package final class DailyRecordStat: BaseStat {
    package var key: DailyRecordKey {
        DailyRecordKey(
            date: Date(milliSeconds: timestamp),
            statType: statType
        )
    }
    
    package func updated(with newValue: DailyRecordStat) -> DailyRecordStat {
        let updatedData = mergeNestedData(existing: self.data ?? [:], new: newValue.data ?? [:])
        
        return DailyRecordStat(
            statType: newValue.statType,
            timestamp: newValue.timestamp,
            statId: newValue.statId,
            isUploaded: newValue.isUploaded,
            data: updatedData
        )
    }
    
    /// 중첩된 딕셔너리를 재귀적으로 병합합니다.
    private func mergeNestedData(existing: [String: AnyCodable], new: [String: AnyCodable]) -> [String: AnyCodable] {
        var result = existing
        
        for (key, newValue) in new {
            if let existingValue = result[key],
               let existingDict = convertToCodableDictionary(from: existingValue.value),
               let newDict = convertToCodableDictionary(from: newValue.value) {
                
                result[key] = AnyCodable(mergeNestedData(existing: existingDict, new: newDict))
            } else if newValue.value != nil {
                result[key] = newValue
            }
        }
        
        return result
    }
    
    /// `Any` 타입의 값을 `[String: AnyCodable]` 딕셔너리로 변환하는 헬퍼 함수
    private func convertToCodableDictionary(from anyValue: Any) -> [String: AnyCodable]? {
        // Case 1: 값이 이미 `[String: AnyCodable]` 타입인 경우 (재귀 호출 시 발생)
        if let codableDict = anyValue as? [String: AnyCodable] {
            return codableDict
        }
        
        // Case 2: 값이 `[String: Any]` 타입인 경우 (최초 실행 시 발생)
        if let anyDict = anyValue as? [String: Any] {
            // `[String: Any]`를 `[String: AnyCodable]`로 변환
            return anyDict.mapValues { AnyCodable($0) }
        }
        
        // 딕셔너리 타입이 아니면 nil 반환
        return nil
    }
}

package struct DailyRecordKey: Codable, Hashable {
    private static let dateFormatter: DateFormatter = {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyyMMdd"
        return dateFormatter
    }()

    package let formattedDate: String
    package let statType: StatType
    
    package init(date: Date, statType: StatType) {
        self.formattedDate = Self.dateFormatter.string(from: date)
        self.statType = statType
    }
    
    package func isSameDate(with other: Date) -> Bool {
        return self.formattedDate == Self.dateFormatter.string(from: other)
    }
    
    package func hash(into hasher: inout Hasher) {
        hasher.combine(formattedDate)
        hasher.combine(statType)
    }
}
