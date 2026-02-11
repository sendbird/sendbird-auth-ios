//
//  StatTypeTests.swift
//  SendbirdAuthTests
//
//  Created by Tez Park on 2025/01/23.
//

import XCTest
@testable @_spi(SendbirdInternal) import SendbirdAuthSDK

final class StatTypeTests: XCTestCase {

    func test_aiAgentStats_rawValue_shouldBeCorrect() {
        XCTAssertEqual(StatType.aiAgentStats.rawValue, "ai_agent:stats")
    }

    func test_aiAgentStats_isExternal_shouldBeTrue() {
        XCTAssertTrue(StatType.aiAgentStats.isExternal)
    }

    func test_internalStatTypes_isExternal_shouldBeFalse() {
        XCTAssertFalse(StatType.apiResult.isExternal)
        XCTAssertFalse(StatType.webSocketConnect.isExternal)
        XCTAssertFalse(StatType.webSocketDisconnect.isExternal)
        XCTAssertFalse(StatType.featureLocalCache.isExternal)
        XCTAssertFalse(StatType.featureLocalCacheEvent.isExternal)
    }

    func test_externalStatTypes_isExternal_shouldBeTrue() {
        XCTAssertTrue(StatType.notificationStats.isExternal)
        XCTAssertTrue(StatType.aiAgentStats.isExternal)
    }
}
