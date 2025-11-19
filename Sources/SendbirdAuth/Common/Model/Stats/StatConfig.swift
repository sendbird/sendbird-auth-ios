//
//  StatConfig.swift
//  SendbirdChatSDK
//
//  Created by Jed Gyeong on 2/28/24.
//

import Foundation

package class StatConfig: Codable {
    package let minStatCount: Int
    package let minInterval: Int64
    package let maxStatCountPerRequest: Int
    package let lowerThreshold: Int
    package let requestDelayRange: Int
    package let modStatCount: Int = 20
    
    package enum CodingKeys: String, CodingKey {
        case minStatCount = "min_stat_count"
        case minInterval = "min_interval"
        case maxStatCountPerRequest = "max_stat_count_per_request"
        case lowerThreshold = "lower_threshold"
        case requestDelayRange = "request_delay_range"
    }
    
    package init(
        minStatCount: Int, 
        minInterval: Int64,
        maxStatCountPerRequest: Int,
        lowerThreshold: Int,
        requestDelayRange: Int
    ) {
        self.minStatCount = minStatCount
        self.minInterval = minInterval
        self.maxStatCountPerRequest = maxStatCountPerRequest
        self.lowerThreshold = lowerThreshold
        self.requestDelayRange = requestDelayRange
    }
    
    package required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        minStatCount = try container.decode(Int.self, forKey: .minStatCount)
        minInterval = try container.decode(Int64.self, forKey: .minInterval)
        maxStatCountPerRequest = try container.decode(Int.self, forKey: .maxStatCountPerRequest)
        lowerThreshold = try container.decode(Int.self, forKey: .lowerThreshold)
        requestDelayRange = try container.decode(Int.self, forKey: .requestDelayRange)
    }
    
    package func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        try container.encode(minStatCount, forKey: .minStatCount)
        try container.encode(minInterval, forKey: .minInterval)
        try container.encodeIfPresent(maxStatCountPerRequest, forKey: .maxStatCountPerRequest)
        try container.encodeIfPresent(lowerThreshold, forKey: .lowerThreshold)
        try container.encodeIfPresent(requestDelayRange, forKey: .requestDelayRange)
    }
}

extension StatConfig {
    /// This is the debug description for the `StatConfig` object.
    package var debugDescription: String {
        """
        Stat config: minStatCount: \(self.minStatCount), minInterval: \(self.minInterval), maxStatCountPerRequest: \(self.maxStatCountPerRequest), lowerThreshold: \(self.lowerThreshold), requestDelayRange: \(self.requestDelayRange)
        """
    }
}
