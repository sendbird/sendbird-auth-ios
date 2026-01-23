//
//  ExternalStatMapperTests.swift
//  SendbirdAuthTests
//
//  Created by Tez Park on 2025/01/23.
//

import XCTest
@testable @_spi(SendbirdInternal) import SendbirdAuthSDK

final class ExternalStatMapperTests: XCTestCase {

    // MARK: - AI Agent Stats Mapping Tests

    func test_map_aiAgentStats_shouldCreateBaseStat() throws {
        let data: [String: Any] = [
            "key": "test_metric",
            "conversation_id": "conv_123"
        ]

        let stat = ExternalStatMapper.map(
            type: "ai_agent:stats",
            data: data,
            timestamp: 1234
        )

        XCTAssertNotNil(stat)
        XCTAssertEqual(stat?.statType, .aiAgentStats)
        XCTAssertEqual(stat?.timestamp, 1234)
    }

    func test_map_aiAgentStats_withIncludeRuntimeId_shouldSetGlobalRuntimeId() throws {
        let data: [String: Any] = ["key": "test_metric"]

        let stat = ExternalStatMapper.map(
            type: "ai_agent:stats",
            data: data,
            timestamp: 1234,
            includeRuntimeId: true
        )

        XCTAssertNotNil(stat)
        XCTAssertEqual(stat?.runtimeId, BaseStat.globalRuntimeId)
    }

    func test_map_aiAgentStats_withoutIncludeRuntimeId_shouldBeNil() throws {
        let data: [String: Any] = ["key": "test_metric"]

        let stat = ExternalStatMapper.map(
            type: "ai_agent:stats",
            data: data,
            timestamp: 1234,
            includeRuntimeId: false
        )

        XCTAssertNotNil(stat)
        XCTAssertNil(stat?.runtimeId)
    }

    // MARK: - Invalid Input Tests

    func test_map_invalidStatType_shouldReturnNil() {
        let stat = ExternalStatMapper.map(
            type: "invalid:type",
            data: [:],
            timestamp: 1234
        )

        XCTAssertNil(stat)
    }

    func test_map_nonExternalStatType_shouldReturnNil() {
        let stat = ExternalStatMapper.map(
            type: "api:result",  // internal stat type
            data: [:],
            timestamp: 1234
        )

        XCTAssertNil(stat)
    }
}
