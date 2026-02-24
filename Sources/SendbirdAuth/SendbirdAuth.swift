//
//  SendbirdAuth 2.swift
//  SendbirdChat
//
//  Created by Kai Lee on 6/23/25.
//

import Foundation

@_spi(SendbirdInternal) public final class SendbirdAuth {
    @_spi(SendbirdInternal) public static let authDecoder = JSONDecoder()

    @_spi(SendbirdInternal) public static var sdkVersion: String { "0.0.11" }

    private static var sdkInstance: SendbirdAuthMain?
    @_spi(SendbirdInternal) public static func updateSharedSDKInstance(to newMain: SendbirdAuthMain) {
        sdkInstance = newMain
    }

    @_spi(SendbirdInternal) public static let pref = LocalPreferences(suiteName: "com.sendbird.sdk.ios")

    @_spi(SendbirdInternal) public static var isInitialized: Bool {
        guard let sdkInstance else {
            return false
        }

        let emptyAppId = sdkInstance.applicationId.isEmpty
        if emptyAppId {
            // TODO: update warning message.
            let warningMessage = "SendbirdAuth [\(Date.now)] 🚨SendbirdAuth instance hasn't been initialized.🚨"
            print(warningMessage)
        }
        return !emptyAppId
    }

    @_spi(SendbirdInternal) public static var isInitializedWithoutWarning: Bool {
        guard let sdkInstance else {
            return false
        }

        let emptyAppId = sdkInstance.applicationId.isEmpty
        return !emptyAppId
    }

#if DEBUG
    /// 테스트용 StatManager 접근자
    @_spi(SendbirdInternal) public static var statManager: StatManager? {
        sdkInstance?.statManager
    }
#endif
    
    @discardableResult @_spi(SendbirdInternal) public static func addSendbirdExtensions(extensions: [SendbirdSDKInfo], customData: [String: String]?) -> Bool {
        guard let sdkInstance else { return false }

        return sdkInstance.addSendbirdExtensions(extensions: extensions, customData: customData)
    }

    /// Returns the shared `SendbirdAuthMain` instance if it matches the given `appId`.
    ///
    /// Multi-instance aware accessor. Currently returns the single shared instance
    /// when the `appId` matches; returns `nil` otherwise.
    @_spi(SendbirdInternal) public static func get(
        appId: String,
        apiHost: String? = nil
    ) -> SendbirdAuthMain? {
        guard let instance = sdkInstance,
              instance.applicationId == appId else { return nil }
        return instance
    }
}

