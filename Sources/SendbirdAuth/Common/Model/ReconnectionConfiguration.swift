//
//  ReconnectionConfiguration.swift
//  SendbirdChat
//
//  Created by Minhyuk Kim on 2021/07/29.
//

import Foundation

package class ReconnectionConfiguration: Codable {
    package static let `default` = ReconnectionConfiguration(
        baseInterval: 2,
        maximumInterval: 20,
        multiplier: 2,
        maximumRetryCount: -1
    )
    package let baseInterval: Double
    package let maximumInterval: Double
    
    package let multiplier: Int
    package let maximumRetryCount: Int
    
    package init(
        baseInterval: Double,
        maximumInterval: Double,
        multiplier: Int,
        maximumRetryCount: Int
    ) {
        self.baseInterval = baseInterval
        self.maximumInterval = maximumInterval
        self.multiplier = multiplier
        self.maximumRetryCount = maximumRetryCount
    }
    
    package func createTask(sessionKey: String) -> ReconnectionTask {
        return ReconnectionTask(config: self, sessionKey: sessionKey)
    }
    
    package required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodeCodingKeys.self)
        self.baseInterval = try container.decode(Double.self, forKey: .interval)
        self.maximumInterval = try container.decode(Double.self, forKey: .maxInterval)
        self.multiplier = try container.decode(Int.self, forKey: .multiplier)
        self.maximumRetryCount = try container.decode(Int.self, forKey: .retryCount)
    }
    
    package func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodeCodingKeys.self)
        try container.encode(self.baseInterval, forKey: .interval)
        try container.encode(self.maximumInterval, forKey: .maxInterval)
        try container.encode(self.multiplier, forKey: .multiplier)
        try container.encode(self.maximumRetryCount, forKey: .retryCount)
    }
}
