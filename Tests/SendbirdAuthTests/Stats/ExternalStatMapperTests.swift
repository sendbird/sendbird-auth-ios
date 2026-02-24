//
//  ExternalStatMapperTests.swift
//  SendbirdAuthTests
//
//  Created by Tez Park on 2025/01/23.
//

import XCTest
@testable @_spi(SendbirdInternal) import SendbirdAuthSDK

final class ExternalStatMapperTests: XCTestCase {

    override func tearDown() {
        super.tearDown()
        ExternalStatMapper.clearAllHandlers()
    }

    // MARK: - AI Agent Stats Tests (Requires Handler Registration)

    func test_map_aiAgentStats_withoutHandler_shouldReturnNil() throws {
        let data: [String: Any] = [
            "key": "test_metric",
            "conversation_id": "conv_123"
        ]

        let stat = ExternalStatMapper.map(
            type: "ai_agent:stats",
            data: data,
            timestamp: 1234
        )

        // Without registered handler, should return nil
        XCTAssertNil(stat)
    }

    func test_map_aiAgentStats_withHandler_shouldCreateStat() throws {
        // Register handler for aiAgentStats
        ExternalStatMapper.register(statType: .aiAgentStats) { statType, data, timestamp, statId, includeRuntimeId in
            return DefaultRecordStat(
                statType: statType,
                timestamp: timestamp,
                statId: statId,
                data: data,
                includeRuntimeId: includeRuntimeId
            )
        }

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
        XCTAssertTrue(stat is DefaultRecordStat)
        XCTAssertEqual(stat?.statType, .aiAgentStats)
        XCTAssertEqual(stat?.timestamp, 1234)
    }

    func test_map_aiAgentStats_withIncludeRuntimeId_shouldSetGlobalRuntimeId() throws {
        // Register handler for aiAgentStats
        ExternalStatMapper.register(statType: .aiAgentStats) { statType, data, timestamp, statId, includeRuntimeId in
            return DefaultRecordStat(
                statType: statType,
                timestamp: timestamp,
                statId: statId,
                data: data,
                includeRuntimeId: includeRuntimeId
            )
        }

        let data: [String: Any] = ["key": "test_metric"]

        let stat = ExternalStatMapper.map(
            type: "ai_agent:stats",
            data: data,
            timestamp: 1234,
            statId: nil,
            includeRuntimeId: true
        )

        XCTAssertNotNil(stat)
        XCTAssertEqual(stat?.runtimeId, BaseStat.globalRuntimeId)
    }

    func test_map_aiAgentStats_withoutIncludeRuntimeId_shouldBeNil() throws {
        // Register handler for aiAgentStats
        ExternalStatMapper.register(statType: .aiAgentStats) { statType, data, timestamp, statId, includeRuntimeId in
            return DefaultRecordStat(
                statType: statType,
                timestamp: timestamp,
                statId: statId,
                data: data,
                includeRuntimeId: includeRuntimeId
            )
        }

        let data: [String: Any] = ["key": "test_metric"]

        let stat = ExternalStatMapper.map(
            type: "ai_agent:stats",
            data: data,
            timestamp: 1234,
            statId: nil,
            includeRuntimeId: false
        )

        XCTAssertNotNil(stat)
        XCTAssertNil(stat?.runtimeId)
    }

    // MARK: - Notification Stats Tests (NotificationStat)

    func test_map_notificationStats_shouldCreateNotificationStat() throws {
        let data: [String: Any] = [
            "action": "clicked",
            "template_key": "template_123",
            "channel_url": "channel_abc",
            "tags": ["tag1", "tag2"],
            "message_id": Int64(12345),
            "source": "notification",
            "message_ts": Int64(1000000),
            "notification_event_deadline": Int64(2000000)
        ]

        let stat = ExternalStatMapper.map(
            type: "noti:stats",
            data: data,
            timestamp: 5678
        )

        XCTAssertNotNil(stat)
        XCTAssertTrue(stat is NotificationStat)
        XCTAssertEqual(stat?.statType, .notificationStats)
        XCTAssertEqual(stat?.timestamp, 5678)

        let notiStat = stat as? NotificationStat
        XCTAssertEqual(notiStat?.action, "clicked")
        XCTAssertEqual(notiStat?.templateKey, "template_123")
        XCTAssertEqual(notiStat?.channelURL, "channel_abc")
        XCTAssertEqual(notiStat?.tags, ["tag1", "tag2"])
        XCTAssertEqual(notiStat?.messageId, 12345)
        XCTAssertEqual(notiStat?.source, "notification")
        XCTAssertEqual(notiStat?.messageTs, 1000000)
        XCTAssertEqual(notiStat?.notificationEventDeadline, 2000000)
    }

    func test_map_notificationStats_withMissingRequiredFields_shouldReturnNil() {
        let data: [String: Any] = [
            "action": "clicked"
            // Missing other required fields
        ]

        let stat = ExternalStatMapper.map(
            type: "noti:stats",
            data: data,
            timestamp: 1234
        )

        XCTAssertNil(stat)
    }

    func test_map_notificationStats_withOptionalFieldsMissing_shouldUseDefaults() {
        let data: [String: Any] = [
            "action": "clicked",
            "template_key": "template_123",
            "channel_url": "channel_abc",
            "tags": ["tag1"],
            "message_id": Int64(12345),
            "source": "notification",
            "message_ts": Int64(1000000)
            // topic, notification_event_deadline are optional
        ]

        let stat = ExternalStatMapper.map(
            type: "noti:stats",
            data: data,
            timestamp: 5678
        )

        XCTAssertNotNil(stat)
        let notiStat = stat as? NotificationStat
        XCTAssertEqual(notiStat?.tags, ["tag1"])
        XCTAssertNil(notiStat?.topic)
        XCTAssertEqual(notiStat?.notificationEventDeadline, 0)
    }

    // MARK: - Register Handler Tests

    func test_register_customHandler_shouldOverrideBuiltIn() {
        // Register custom handler that returns DefaultRecordStat for notification
        ExternalStatMapper.register(statType: .notificationStats) { statType, data, timestamp, statId, includeRuntimeId in
            return DefaultRecordStat(
                statType: statType,
                timestamp: timestamp,
                statId: statId,
                data: data,
                includeRuntimeId: includeRuntimeId
            )
        }

        let data: [String: Any] = [
            "action": "clicked",
            "template_key": "template_123",
            "channel_url": "channel_abc",
            "message_id": Int64(12345),
            "source": "notification",
            "message_ts": Int64(1000000)
        ]

        let stat = ExternalStatMapper.map(
            type: "noti:stats",
            data: data,
            timestamp: 5678
        )

        XCTAssertNotNil(stat)
        XCTAssertTrue(stat is DefaultRecordStat)
        XCTAssertFalse(stat is NotificationStat)
    }

    func test_unregister_shouldFallbackToBuiltIn() {
        // Register then unregister
        ExternalStatMapper.register(statType: .notificationStats) { statType, data, timestamp, statId, includeRuntimeId in
            return DefaultRecordStat(
                statType: statType,
                timestamp: timestamp,
                statId: statId,
                data: data,
                includeRuntimeId: includeRuntimeId
            )
        }
        ExternalStatMapper.unregister(statType: .notificationStats)

        let data: [String: Any] = [
            "action": "clicked",
            "template_key": "template_123",
            "channel_url": "channel_abc",
            "tags": ["tag1", "tag2"],
            "message_id": Int64(12345),
            "source": "notification",
            "message_ts": Int64(1000000)
        ]

        let stat = ExternalStatMapper.map(
            type: "noti:stats",
            data: data,
            timestamp: 1234
        )

        XCTAssertNotNil(stat)
        XCTAssertTrue(stat is NotificationStat)
    }

    func test_clearAllHandlers_shouldClearRegisteredHandlers() {
        // Register custom handler for notificationStats
        ExternalStatMapper.register(statType: .notificationStats) { statType, data, timestamp, statId, includeRuntimeId in
            return DefaultRecordStat(
                statType: statType,
                timestamp: timestamp,
                statId: statId,
                data: data,
                includeRuntimeId: includeRuntimeId
            )
        }
        ExternalStatMapper.clearAllHandlers()

        // After clearing, should fallback to built-in NotificationStat handling
        let data: [String: Any] = [
            "action": "clicked",
            "template_key": "template_123",
            "channel_url": "channel_abc",
            "tags": ["tag1"],
            "message_id": Int64(12345),
            "source": "notification",
            "message_ts": Int64(1000000)
        ]

        let stat = ExternalStatMapper.map(
            type: "noti:stats",
            data: data,
            timestamp: 1234
        )

        XCTAssertNotNil(stat)
        XCTAssertTrue(stat is NotificationStat)  // Built-in handling restored
    }

    func test_register_handlerReturnsNil_shouldReturnNil() {
        ExternalStatMapper.register(statType: .aiAgentStats) { _, _, _, _, _ in
            return nil
        }

        let stat = ExternalStatMapper.map(
            type: "ai_agent:stats",
            data: [:],
            timestamp: 1234
        )

        XCTAssertNil(stat)
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
