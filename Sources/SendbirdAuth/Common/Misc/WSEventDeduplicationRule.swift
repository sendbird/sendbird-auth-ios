//
//  WSEventDeduplicationRule.swift
//  SendbirdChat
//
//  Created by Celine Moon on 4/25/25.
//

import Foundation

/// A deduplication rule for a WS event.
/// e.g., `WSEventDeduplicationRule(managerType: GroupChannelManager.self, eventType: .systemEvent, uniqueId: 1234)`
/// ignores a SYEV{"unique_id" = "1234"} for GroupChannelManager.
/// - Since: 4.27.0
@_spi(SendbirdInternal) public struct WSEventDeduplicationRule {
    @_spi(SendbirdInternal) public let managerType: AnyClass
    @_spi(SendbirdInternal) public let eventType: CommandType
    @_spi(SendbirdInternal) public let uniqueId: String
    
    @_spi(SendbirdInternal) public init(managerType: AnyClass, eventType: CommandType, uniqueId: String) {
        self.managerType = managerType
        self.eventType = eventType
        self.uniqueId = uniqueId
    }
}

extension WSEventDeduplicationRule: CustomStringConvertible {
    @_spi(SendbirdInternal) public var description: String {
        "WSEventDeduplicationRule(managerType=\(managerType), eventType=\(eventType), uniqueId=\(uniqueId))"
    }
}
