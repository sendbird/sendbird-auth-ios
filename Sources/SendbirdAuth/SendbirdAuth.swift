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

    /// Thread-safe weak reference map for storing multiple SendbirdAuthMain instances
    /// Key: appId or appId_apiHostUrl
    /// Uses NSMapTable with weak values to allow automatic cleanup when instances are deallocated
    private static let instances = NSMapTable<NSString, SendbirdAuthMain>(
        keyOptions: .strongMemory,
        valueOptions: .weakMemory
    )
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
        let key = createInstanceKey(appId: params.applicationId, apiHostUrl: params.customAPIHost) as NSString

        return instancesLock.withLock {
            if let existing = instances.object(forKey: key) {
                return existing
            }

            let newInstance = SendbirdAuthMain(params: params)
            instances.setObject(newInstance, forKey: key)
            return newInstance
        }
    }

    /// Gets an existing instance by appId and apiHostUrl
    @_spi(SendbirdInternal) public static func getInstance(appId: String, apiHostUrl: String? = nil) -> SendbirdAuthMain? {
        let key = createInstanceKey(appId: appId, apiHostUrl: apiHostUrl) as NSString
        return instancesLock.withLock {
            instances.object(forKey: key)
        }
    }

    /// Removes an instance from the map
    @_spi(SendbirdInternal) public static func removeInstance(appId: String, apiHostUrl: String? = nil) {
        let key = createInstanceKey(appId: appId, apiHostUrl: apiHostUrl) as NSString
        instancesLock.withLock {
            instances.removeObject(forKey: key)
        }
    }

    /// Clears all instances
    @_spi(SendbirdInternal) public static func clearAllInstances() {
        instancesLock.withLock {
            instances.removeAllObjects()
        }
    }

    /// Returns the first available instance (thread-safe)
    private static func getFirstInstance() -> SendbirdAuthMain? {
        instancesLock.withLock {
            instances.objectEnumerator()?.nextObject() as? SendbirdAuthMain
        }
    }

    // MARK: - Legacy Support (Backward Compatibility)

    @available(*, deprecated, message: "Use getOrCreate(params:) instead")
    @_spi(SendbirdInternal) public static func updateSharedSDKInstance(to newMain: SendbirdAuthMain) {
        let key = createInstanceKey(appId: newMain.applicationId, apiHostUrl: newMain.routerConfig.apiHost) as NSString
        instancesLock.withLock {
            instances.setObject(newMain, forKey: key)
        }
    }

    @available(*, deprecated, message: "Use getInstance(appId:apiHostUrl:) instead")
    @_spi(SendbirdInternal) public static let pref = LocalPreferences(suiteName: "com.sendbird.sdk.ios")

    @_spi(SendbirdInternal) public static var isInitialized: Bool {
        guard let sdkInstance = getFirstInstance() else {
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
        guard let instance = getInstance(appId: appId, apiHostUrl: apiHostUrl) else {
            return false
        }
        return !instance.applicationId.isEmpty
    }

    @_spi(SendbirdInternal) public static var isInitializedWithoutWarning: Bool {
        guard let sdkInstance = getFirstInstance() else {
            return false
        }
        return !sdkInstance.applicationId.isEmpty
    }
}
