//
//  SendbirdAuthGetTests.swift
//  SendbirdAuthTests
//

import XCTest
@testable @_spi(SendbirdInternal) import SendbirdAuthSDK

final class SendbirdAuthGetTests: XCTestCase {

    override func tearDown() {
        SendbirdAuth.updateSharedSDKInstance(to: SendbirdAuthMain())
        super.tearDown()
    }

    // appId가 일치하면 공유 인스턴스를 반환하는지 확인
    func test_get_returnsInstance_whenAppIdMatches() {
        let params = InternalInitParams(
            applicationId: "APP_ID_123",
            isLocalCachingEnabled: false
        )
        let authMain = SendbirdAuthMain(params: params)
        SendbirdAuth.updateSharedSDKInstance(to: authMain)

        let result = SendbirdAuth.get(appId: "APP_ID_123")
        XCTAssertTrue(result === authMain)
    }

    // appId가 일치하지 않으면 nil을 반환하는지 확인
    func test_get_returnsNil_whenAppIdDoesNotMatch() {
        let params = InternalInitParams(
            applicationId: "APP_ID_123",
            isLocalCachingEnabled: false
        )
        SendbirdAuth.updateSharedSDKInstance(to: SendbirdAuthMain(params: params))

        let result = SendbirdAuth.get(appId: "DIFFERENT_APP_ID")
        XCTAssertNil(result)
    }

    // 초기화되지 않은 인스턴스(빈 appId)에 대해 nil을 반환하는지 확인
    func test_get_returnsNil_whenInstanceHasEmptyAppId() {
        SendbirdAuth.updateSharedSDKInstance(to: SendbirdAuthMain())

        let result = SendbirdAuth.get(appId: "ANY_APP_ID")
        XCTAssertNil(result)
    }
}
