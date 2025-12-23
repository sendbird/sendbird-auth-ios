//
//  SendbirdAuth 2.swift
//  SendbirdChat
//
//  Created by Kai Lee on 6/23/25.
//

import Foundation

@_spi(SendbirdInternal) public final class SendbirdAuth {
    @_spi(SendbirdInternal) public static let authDecoder = JSONDecoder()

    @_spi(SendbirdInternal) public static var sdkVersion: String { "0.0.5" }

    // MARK: - Multi-instance Support

    /// Thread-safe dictionary for storing multiple SendbirdAuthMain instances
    /// Key: appId or appId_apiHostUrl
    private static var instances: [String: SendbirdAuthMain] = [:]
    private static let instancesLock = NSLock()

    /// Creates the key for identifying a SendbirdAuthMain instance
    private static func createInstanceKey(appId: String, apiHostUrl: String?) -> String {
        if let apiHostUrl, !apiHostUrl.isEmpty {
            return "\(appId)_\(apiHostUrl)"
        }
        return appId
    }

    /// Gets or creates a SendbirdAuthMain instance
    @_spi(SendbirdInternal) public static func getOrCreate(params: InternalInitParams) -> SendbirdAuthMain {
        let key = createInstanceKey(appId: params.applicationId, apiHostUrl: params.customAPIHost)

        instancesLock.lock()
        defer { instancesLock.unlock() }

        if let existing = instances[key] {
            return existing
        }

        let newInstance = SendbirdAuthMain(params: params)
        newInstance.onDestroy = { [key] in
            instancesLock.lock()
            defer { instancesLock.unlock() }
            instances.removeValue(forKey: key)
        }
        instances[key] = newInstance

        return newInstance
    }

    /// Gets an existing instance by appId and apiHostUrl
    @_spi(SendbirdInternal) public static func getInstance(appId: String, apiHostUrl: String? = nil) -> SendbirdAuthMain? {
        let key = createInstanceKey(appId: appId, apiHostUrl: apiHostUrl)
        instancesLock.lock()
        defer { instancesLock.unlock() }
        return instances[key]
    }

    /// Removes an instance from the map
    @_spi(SendbirdInternal) public static func removeInstance(appId: String, apiHostUrl: String? = nil) {
        let key = createInstanceKey(appId: appId, apiHostUrl: apiHostUrl)
        instancesLock.lock()
        defer { instancesLock.unlock() }
        instances.removeValue(forKey: key)
    }

    /// Clears all instances
    @_spi(SendbirdInternal) public static func clearAllInstances() {
        instancesLock.lock()
        defer { instancesLock.unlock() }
        instances.removeAll()
    }

    // MARK: - Legacy Support (Backward Compatibility)

    @available(*, deprecated, message: "Use getOrCreate(params:) instead")
    @_spi(SendbirdInternal) public static func updateSharedSDKInstance(to newMain: SendbirdAuthMain) {
        let key = createInstanceKey(appId: newMain.applicationId, apiHostUrl: newMain.routerConfig.apiHost)
        instancesLock.lock()
        defer { instancesLock.unlock() }
        instances[key] = newMain
    }

    @available(*, deprecated, message: "Use getInstance(appId:apiHostUrl:) instead")
    @_spi(SendbirdInternal) public static let pref = LocalPreferences(suiteName: "com.sendbird.sdk.ios")

    @_spi(SendbirdInternal) public static var isInitialized: Bool {
        instancesLock.lock()
        let firstInstance = instances.values.first
        instancesLock.unlock()

        guard let sdkInstance = firstInstance else {
            return false
        }

        let emptyAppId = sdkInstance.applicationId.isEmpty
        if emptyAppId {
            let warningMessage = "SendbirdAuth [\(Date.now)] 🚨SendbirdAuth instance hasn't been initialized.🚨"
            print(warningMessage)
        }
        return !emptyAppId
    }

    /// Check if a specific instance is initialized
    @_spi(SendbirdInternal) public static func isInitialized(appId: String, apiHostUrl: String? = nil) -> Bool {
        let key = createInstanceKey(appId: appId, apiHostUrl: apiHostUrl)
        instancesLock.lock()
        defer { instancesLock.unlock() }

        guard let instance = instances[key] else {
            return false
        }
        return !instance.applicationId.isEmpty
    }

    @_spi(SendbirdInternal) public static var isInitializedWithoutWarning: Bool {
        instancesLock.lock()
        let firstInstance = instances.values.first
        instancesLock.unlock()

        guard let sdkInstance = firstInstance else {
            return false
        }

        let emptyAppId = sdkInstance.applicationId.isEmpty
        return !emptyAppId
    }
}
