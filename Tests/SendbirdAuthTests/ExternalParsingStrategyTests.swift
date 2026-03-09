//
//  ExternalParsingStrategyTests.swift
//  SendbirdAuthTests
//

import XCTest
@testable @_spi(SendbirdInternal) import SendbirdAuthSDK

final class ExternalParsingStrategyTests: XCTestCase {
    var auth: SendbirdAuthMain!

    override func setUp() {
        super.setUp()
        let params = InternalInitParams(
            applicationId: "test_app_id",
            isLocalCachingEnabled: false
        )
        auth = SendbirdAuthMain(params: params)
    }

    override func tearDown() {
        auth = nil
        super.tearDown()
    }

    // 등록된 외부 파싱 전략이 매칭되는 메시지 수신 시 호출되는지 확인
    func test_addStrategy_andReceiveMessage_callsStrategy() {
        let expectation = expectation(description: "Strategy called")

        auth.addExternalParsingStrategy(for: "AIEV", identifier: "test") { message in
            XCTAssertTrue(message.hasPrefix("AIEV"))
            expectation.fulfill()
            return nil
        }

        auth.router.simulateDidReceiveMessage("AIEV{\"type\":\"ai_agent_event\"}")

        wait(for: [expectation], timeout: 1.0)
    }

    // 제거된 전략은 더 이상 호출되지 않는지 확인
    func test_removeStrategy_noLongerCalled() {
        auth.addExternalParsingStrategy(for: "AIEV", identifier: "test") { _ in
            XCTFail("Removed strategy should not be called")
            return nil
        }

        auth.removeExternalParsingStrategy(for: "AIEV", identifier: "test")
        auth.router.simulateDidReceiveMessage("AIEV{\"data\":\"test\"}")
    }

    // 다른 커맨드 타입의 메시지에는 전략이 호출되지 않는지 확인
    func test_strategyOnlyCalledForMatchingCmdType() {
        auth.addExternalParsingStrategy(for: "AIEV", identifier: "test") { _ in
            XCTFail("Strategy for AIEV should not be called for LOGI message")
            return nil
        }

        auth.router.simulateDidReceiveMessage("LOGI{\"data\":\"login\"}")
    }

    // 같은 커맨드 타입에 복수 전략 등록 시 모두 호출되는지 확인
    func test_multipleStrategies_allCalledForSameCmdType() {
        let exp1 = expectation(description: "Strategy 1 called")
        let exp2 = expectation(description: "Strategy 2 called")

        auth.addExternalParsingStrategy(for: "AIEV", identifier: "handler-1") { _ in
            exp1.fulfill()
            return nil
        }
        auth.addExternalParsingStrategy(for: "AIEV", identifier: "handler-2") { _ in
            exp2.fulfill()
            return nil
        }

        auth.router.simulateDidReceiveMessage("AIEV{\"data\":\"test\"}")

        wait(for: [exp1, exp2], timeout: 1.0)
    }

    // 외부 전략과 기존 parsingStrategy가 모두 실행되는지 확인
    func test_existingParsingStrategy_alwaysExecuted() {
        let externalCalled = expectation(description: "External strategy called")
        let parsingCalled = expectation(description: "Existing parsingStrategy called")

        auth.addExternalParsingStrategy(for: "AIEV", identifier: "test") { _ in
            externalCalled.fulfill()
            return nil
        }

        auth.router.parsingStrategy = { _ in
            parsingCalled.fulfill()
            return nil
        }

        auth.router.simulateDidReceiveMessage("AIEV{\"data\":\"test\"}")

        wait(for: [externalCalled, parsingCalled], timeout: 1.0)
    }
}
