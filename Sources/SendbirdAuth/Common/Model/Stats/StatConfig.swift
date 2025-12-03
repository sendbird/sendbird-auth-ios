//
//  StatConfig.swift
//  SendbirdChatSDK
//
//  Created by Jed Gyeong on 2/28/24.
//

import Foundation

@_spi(SendbirdInternal) public class StatConfig: Codable {
    @_spi(SendbirdInternal) public let minStatCount: Int
    @_spi(SendbirdInternal) public let minInterval: Int64
    @_spi(SendbirdInternal) public let maxStatCountPerRequest: Int
    @_spi(SendbirdInternal) public let lowerThreshold: Int
    @_spi(SendbirdInternal) public let requestDelayRange: Int
    @_spi(SendbirdInternal) public let modStatCount: Int = 20
    
    @_spi(SendbirdInternal) public enum CodingKeys: String, CodingKey {
        case minStatCount = "min_stat_count"
        case minInterval = "min_interval"
        case maxStatCountPerRequest = "max_stat_count_per_request"
        case lowerThreshold = "lower_threshold"
        case requestDelayRange = "request_delay_range"
    }
    
    @_spi(SendbirdInternal) public init(
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
    
    @_spi(SendbirdInternal) public required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        minStatCount = try container.decode(Int.self, forKey: .minStatCount)
        minInterval = try container.decode(Int64.self, forKey: .minInterval)
        maxStatCountPerRequest = try container.decode(Int.self, forKey: .maxStatCountPerRequest)
        lowerThreshold = try container.decode(Int.self, forKey: .lowerThreshold)
        requestDelayRange = try container.decode(Int.self, forKey: .requestDelayRange)
    }
    
    @_spi(SendbirdInternal) public func encode(to encoder: Encoder) throws {
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
    @_spi(SendbirdInternal) public var debugDescription: String {
        """
        Stat config: minStatCount: \(self.minStatCount), minInterval: \(self.minInterval), maxStatCountPerRequest: \(self.maxStatCountPerRequest), lowerThreshold: \(self.lowerThreshold), requestDelayRange: \(self.requestDelayRange)
        """
    }
}
