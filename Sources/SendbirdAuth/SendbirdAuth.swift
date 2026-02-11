//
//  SendbirdAuth 2.swift
//  SendbirdChat
//
//  Created by Kai Lee on 6/23/25.
//

import Foundation

@_spi(SendbirdInternal) public final class SendbirdAuth {
    @_spi(SendbirdInternal) public static let authDecoder = JSONDecoder()

    @_spi(SendbirdInternal) public static var sdkVersion: String { "0.0.9" }

    // MARK: - Multi-instance Support

    private static let registry = InstanceRegistry()

    /// Gets or creates a SendbirdAuthMain instance.
    /// You should hold a strong reference to the returned instance to prevent it from being deallocated.
    @_spi(SendbirdInternal) public static func getOrCreate(
        params: InternalInitParams,
        statAPIClient: StatAPIClientable? = nil,
        webSocketEngine: (any ChatWebSocketEngine)? = nil,
        httpClient: HTTPClientInterface? = nil,
        customRouterConfig: CommandRouterConfiguration? = nil,
        customSendbirdConfig: SendbirdConfiguration? = nil
    ) -> SendbirdAuthMain {
        registry.getOrCreate(
            params: params,
            statAPIClient: statAPIClient,
            webSocketEngine: webSocketEngine,
            httpClient: httpClient,
            customRouterConfig: customRouterConfig,
            customSendbirdConfig: customSendbirdConfig
        )
    }

    /// Gets an existing instance by appId and apiHostUrl
    @_spi(SendbirdInternal) public static func getInstance(appId: String, apiHostUrl: String? = nil) -> SendbirdAuthMain? {
        registry.get(appId: appId, apiHostUrl: apiHostUrl)
    }

    /// Removes an instance from the map
    @_spi(SendbirdInternal) public static func removeInstance(appId: String, apiHostUrl: String? = nil) {
        registry.remove(appId: appId, apiHostUrl: apiHostUrl)
    }

    @_spi(SendbirdInternal) public static func removeInstance(_ instance: SendbirdAuthMain) {
        registry.remove(instance)
    }

    /// Clears all instances
    @_spi(SendbirdInternal) public static func clearAllInstances() {
        registry.clear()
    }

    // MARK: - Legacy Support (Backward Compatibility)

    @available(*, deprecated, message: "DO NOT USE IT. Use `SendbirdAuthMain.preference` instead")
    @_spi(SendbirdInternal) public static var pref: LocalPreferences {
        if let sdkInstance = registry.first() {
            return sdkInstance.preference
        } else {
            return LocalPreferences(suiteName: "com.sendbird.sdk.ios")
        }
    }

    @_spi(SendbirdInternal) public static func updateSharedSDKInstance(to newMain: SendbirdAuthMain) {
        registry.update(newMain)
    }

    /// Check if a specific instance is initialized
    @_spi(SendbirdInternal) public static func isInitialized(appId: String, apiHostUrl: String? = nil) -> Bool {
        guard let instance = getInstance(appId: appId, apiHostUrl: apiHostUrl) else {
            return false
        }
        return !instance.applicationId.isEmpty
    }

    @available(*, deprecated, message: "DO NOT USE IT. Use isInitialized(appId:apiHostUrl:) instead")
    @_spi(SendbirdInternal) public static var isInitialized: Bool {
        guard let sdkInstance = registry.first() else {
            return false
        }

        let emptyAppId = sdkInstance.applicationId.isEmpty
        if emptyAppId {
            let warningMessage = "SendbirdAuth [\(Date.now)] 🚨SendbirdAuth instance hasn't been initialized.🚨"
            print(warningMessage)
        }
        return !emptyAppId
    }

    @available(*, deprecated, message: "DO NOT USE IT. Use isInitialized(appId:apiHostUrl:) instead")
    @_spi(SendbirdInternal) public static var isInitializedWithoutWarning: Bool {
        guard let sdkInstance = registry.first() else {
            return false
        }
        return !sdkInstance.applicationId.isEmpty
    }

#if DEBUG
    /// 테스트용 StatManager 접근자
    @_spi(SendbirdInternal) public static var statManager: StatManager? {
        registry.first()?.statManager
    }
#endif
    
    @discardableResult @_spi(SendbirdInternal) public static func addSendbirdExtensions(extensions: [SendbirdSDKInfo], customData: [String: String]?) -> Bool {
        guard let sdkInstance = registry.first() else { return false }
        
        return sdkInstance.addSendbirdExtensions(extensions: extensions, customData: customData)
    }
}

