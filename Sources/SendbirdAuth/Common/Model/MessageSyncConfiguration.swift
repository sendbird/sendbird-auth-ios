//
//  MessageSyncConfiguration.swift
//  SendbirdChat
//
//  Created by Hoon Sung on 11/4/24.
//

import Foundation

package class MessageSyncConfiguration: CustomStringConvertible, Codable {
    package static let `default` = MessageSyncConfiguration(
        concurrentCallLimit: 1,
        backOffDelaySec: 0.5
    )
    
    package let concurrentCallLimit: Int
    package let backOffDelaySec: Double
    
    package var description: String {
        return "MessageSyncConfiguration(concurrentCallLimit: \(concurrentCallLimit), backOffDelaySec: \(backOffDelaySec))"
    }
    
    package init(
        concurrentCallLimit: Int,
        backOffDelaySec: Double
    ) {
        self.concurrentCallLimit = concurrentCallLimit
        self.backOffDelaySec = backOffDelaySec
    }
    
    package required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodeCodingKeys.self)
        self.concurrentCallLimit = (try? container.decodeIfPresent(Int.self, forKey: .concurrentCallLimit)) ?? Self.default.concurrentCallLimit
        self.backOffDelaySec = (try? container.decodeIfPresent(Double.self, forKey: .backOffDelay)) ?? Self.default.backOffDelaySec
    }
    
    package func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodeCodingKeys.self)
        try container.encode(self.concurrentCallLimit, forKey: .concurrentCallLimit)
        try container.encode(self.backOffDelaySec, forKey: .backOffDelay)
    }
}
