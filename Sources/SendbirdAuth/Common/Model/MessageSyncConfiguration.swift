//
//  MessageSyncConfiguration.swift
//  SendbirdChat
//
//  Created by Hoon Sung on 11/4/24.
//

import Foundation

@_spi(SendbirdInternal) public class MessageSyncConfiguration: CustomStringConvertible, Codable {
    @_spi(SendbirdInternal) public static let `default` = MessageSyncConfiguration(
        concurrentCallLimit: 1,
        backOffDelaySec: 0.5
    )
    
    @_spi(SendbirdInternal) public let concurrentCallLimit: Int
    @_spi(SendbirdInternal) public let backOffDelaySec: Double
    
    @_spi(SendbirdInternal) public var description: String {
        return "MessageSyncConfiguration(concurrentCallLimit: \(concurrentCallLimit), backOffDelaySec: \(backOffDelaySec))"
    }
    
    @_spi(SendbirdInternal) public init(
        concurrentCallLimit: Int,
        backOffDelaySec: Double
    ) {
        self.concurrentCallLimit = concurrentCallLimit
        self.backOffDelaySec = backOffDelaySec
    }
    
    @_spi(SendbirdInternal) public required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodeCodingKeys.self)
        self.concurrentCallLimit = (try? container.decodeIfPresent(Int.self, forKey: .concurrentCallLimit)) ?? Self.default.concurrentCallLimit
        self.backOffDelaySec = (try? container.decodeIfPresent(Double.self, forKey: .backOffDelay)) ?? Self.default.backOffDelaySec
    }
    
    @_spi(SendbirdInternal) public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodeCodingKeys.self)
        try container.encode(self.concurrentCallLimit, forKey: .concurrentCallLimit)
        try container.encode(self.backOffDelaySec, forKey: .backOffDelay)
    }
}
