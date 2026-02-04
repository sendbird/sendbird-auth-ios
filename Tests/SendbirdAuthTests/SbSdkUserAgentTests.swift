//
//  SbSdkUserAgentTests.swift
//  SendbirdAuthTests
//
//  Created by Celine Moon on 2023/04/10.
//
//  specs: https://docs.google.com/presentation/d/1sl6zHD3r1ivUGLDAQmitGQr6tslnnr9ZJK_42i6TLbI/edit#slide=id.g1a4f3d6fe14_0_0
//  sdk docs: https://sendbird.atlassian.net/wiki/spaces/SDK/pages/2054750998/SB-SDK-User-Agent+SDK+Design
//  test: https://docs.google.com/spreadsheets/d/17b9sU5vhT2ynMAqNWQ0crN_CHUCi96OnS5HL1oebzsk/edit#gid=0

import XCTest
@testable @_spi(SendbirdInternal) import SendbirdAuthSDK

final class SbSdkUserAgentTests: XCTestCase {
    var auth: SendbirdAuthMain!

    override func setUp() async throws {
        try await super.setUp()

        let params = InternalInitParams(
            applicationId: "test_app_id",
            isLocalCachingEnabled: false,
            mainSDKInfo: SendbirdSDKInfo(product: .chat, platform: .ios, version: "4.36.0")
        )
        auth = SendbirdAuthMain(params: params)
    }

    override func tearDown() async throws {
        auth = nil
        try await super.tearDown()
    }

    // MARK: - Test Cases

    #if os(iOS)
    func test_case1_sbSdkUserAgent_baseFormat() async throws {
        let vSDK = "4.36.0" // mainSDKInfo version
        let vAuth = SendbirdAuth.sdkVersion
        let vOS = await UIDevice.current.systemVersion
        let sbSdkUserAgent = "main_sdk_info=chat/ios/\(vSDK)&device_os_platform=ios&os_version=\(vOS)&auth_sdk_info=auth/ios/\(vAuth)"

        XCTAssertEqual(auth.sbSdkUserAgent, sbSdkUserAgent)

        let header = auth.requestHeaderContext
        XCTAssertEqual(header?.sbSdkUserAgent, sbSdkUserAgent)
    }

    func test_case2_sbSdkUserAgent_addValidExtensionSDK() async throws {
        let vSDK = "4.36.0"
        let vAuth = SendbirdAuth.sdkVersion
        let vOS = await UIDevice.current.systemVersion

        let uikit = SendbirdSDKInfo(product: .uikitChat, platform: .ios, version: "3.0.1")
        let live = SendbirdSDKInfo(product: .live, platform: .ios, version: "1.31.20-beta")
        let swiftui = SendbirdSDKInfo(product: .swiftuiChat, platform: .ios, version: "1.0.0")

        var sbSdkUserAgent = "main_sdk_info=chat/ios/\(vSDK)&device_os_platform=ios&os_version=\(vOS)"
        sbSdkUserAgent.append("&auth_sdk_info=auth/ios/\(vAuth)")
        sbSdkUserAgent.append("&extension_sdk_info=")
        sbSdkUserAgent.append("live/ios/1.31.20-beta,")
        sbSdkUserAgent.append("swiftui-chat/ios/1.0.0,")
        sbSdkUserAgent.append("uikit-chat/ios/3.0.1")

        let extensions = [uikit, live, swiftui].sorted(by: { $0.product.rawValue < $1.product.rawValue })
        let isValid = auth.addSendbirdExtensions(extensions: extensions, customData: nil)
        XCTAssertTrue(isValid)

        XCTAssertEqual(auth.sbSdkUserAgent, sbSdkUserAgent)

        let header = auth.requestHeaderContext
        XCTAssertEqual(header?.sbSdkUserAgent, sbSdkUserAgent)
    }

    func test_case3_sbSdkUserAgent_addInvalidExtensionSDK() async throws {
        let vSDK = "4.36.0"
        let vAuth = SendbirdAuth.sdkVersion
        let vOS = await UIDevice.current.systemVersion
        let sbSdkUserAgent = "main_sdk_info=chat/ios/\(vSDK)&device_os_platform=ios&os_version=\(vOS)&auth_sdk_info=auth/ios/\(vAuth)"

        let uikit = SendbirdSDKInfo(product: .uikitChat, platform: .ios, version: "3.0.1beta")

        let isValid = auth.addSendbirdExtensions(extensions: [uikit], customData: nil)
        XCTAssertFalse(isValid)

        let header = auth.requestHeaderContext
        XCTAssertEqual(header?.sbSdkUserAgent, sbSdkUserAgent)
    }

    func test_case4_sbSdkUserAgent_addCustomData() async throws {
        let vSDK = "4.36.0"
        let vAuth = SendbirdAuth.sdkVersion
        let vOS = await UIDevice.current.systemVersion
        var sbSdkUserAgent = "main_sdk_info=chat/ios/\(vSDK)&device_os_platform=ios&os_version=\(vOS)"
        sbSdkUserAgent.append("&auth_sdk_info=auth/ios/\(vAuth)")
        sbSdkUserAgent.append("&extension_sdk_info=uikit-chat/ios/3.0.1")
        sbSdkUserAgent.append("&key1=value1")

        let uikit = SendbirdSDKInfo(product: .uikitChat, platform: .ios, version: "3.0.1")
        let customData = ["key1": "value1"]
        let isValid = auth.addSendbirdExtensions(extensions: [uikit], customData: customData)
        XCTAssertTrue(isValid)

        XCTAssertEqual(auth.sbSdkUserAgent, sbSdkUserAgent)

        let header = auth.requestHeaderContext
        XCTAssertEqual(header?.sbSdkUserAgent, sbSdkUserAgent)
    }

    func test_case5_sbSdkUserAgent_addInvalidCustomData() async throws {
        let vSDK = "4.36.0"
        let vAuth = SendbirdAuth.sdkVersion
        let vOS = await UIDevice.current.systemVersion
        let sbSdkUserAgent = "main_sdk_info=chat/ios/\(vSDK)&device_os_platform=ios&os_version=\(vOS)&auth_sdk_info=auth/ios/\(vAuth)"

        let uikit = SendbirdSDKInfo(product: .uikitChat, platform: .ios, version: "3.0.1")
        let customData = ["key1": "value&1"]
        let isValid = auth.addSendbirdExtensions(extensions: [uikit], customData: customData)
        XCTAssertFalse(isValid, "custom data cannot include '&'")

        XCTAssertEqual(auth.sbSdkUserAgent, sbSdkUserAgent)

        let header = auth.requestHeaderContext
        XCTAssertEqual(header?.sbSdkUserAgent, sbSdkUserAgent)
    }

    func test_case6_sbSdkUserAgent_emptyExtensionsArray() async throws {
        let vSDK = "4.36.0"
        let vAuth = SendbirdAuth.sdkVersion
        let vOS = await UIDevice.current.systemVersion
        let sbSdkUserAgent = "main_sdk_info=chat/ios/\(vSDK)&device_os_platform=ios&os_version=\(vOS)&auth_sdk_info=auth/ios/\(vAuth)"

        let isValid = auth.addSendbirdExtensions(extensions: [], customData: nil)
        XCTAssertFalse(isValid)

        XCTAssertEqual(auth.sbSdkUserAgent, sbSdkUserAgent)

        let header = auth.requestHeaderContext
        XCTAssertEqual(header?.sbSdkUserAgent, sbSdkUserAgent)
    }

    func test_case7_sbSdkUserAgent_addValidExtensionSDK_UIKit() async throws {
        let vUIKit = "3.0.0"

        let uikit = SendbirdSDKInfo(product: .uikitChat, platform: .ios, version: vUIKit)

        let isValid = auth.addSendbirdExtensions(extensions: [uikit], customData: nil)
        XCTAssertTrue(isValid)

        let header = auth.requestHeaderContext
        XCTAssertEqual(header?.inIncludeUIKitConfig, true)
        XCTAssertTrue(header?.sbUserAgent.contains("u\(vUIKit)") == true)
    }

    // MARK: - Auth SDK only (no mainSDKInfo)

    func test_case8_sbSdkUserAgent_authOnly() async throws {
        // Create auth instance without mainSDKInfo (auth SDK standalone)
        let params = InternalInitParams(
            applicationId: "test_app_id",
            isLocalCachingEnabled: false,
            mainSDKInfo: nil
        )
        let authOnly = SendbirdAuthMain(params: params)

        let vAuth = SendbirdAuth.sdkVersion
        let vOS = await UIDevice.current.systemVersion
        // When mainSDKInfo is nil, auth is the main SDK and no auth_sdk_info is added
        let sbSdkUserAgent = "main_sdk_info=auth/ios/\(vAuth)&device_os_platform=ios&os_version=\(vOS)"

        XCTAssertEqual(authOnly.sbSdkUserAgent, sbSdkUserAgent)
    }
    #endif
}
