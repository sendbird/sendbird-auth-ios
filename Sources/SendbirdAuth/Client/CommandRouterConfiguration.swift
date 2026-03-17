//
//  CommandRouterConfiguration.swift
//  SendbirdChat
//
//  Created by Wooyoung Chung on 7/30/21.
//

import Foundation

@_spi(SendbirdInternal) public class CommandRouterConfiguration {
    @_spi(SendbirdInternal) public private(set) var cachePolicy: NSURLRequest.CachePolicy
    @_spi(SendbirdInternal) public private(set) var useNativeSocket: Bool?

    @_spi(SendbirdInternal) public var apiHost: String
    @_spi(SendbirdInternal) public var wsHost: String

    // NOTE: When set, the latest host is persisted to AppGroup UserDefaults
    // so that NotificationExtension can reuse the main app's host for API calls (e.g., push delivery).
    // The applicationId is used to scope the keys so multiple SDK instances don't overwrite each other.
    private var appGroup: String?
    private var applicationId: String?
    private var appGroupPreferences: LocalPreferences?

    @_spi(SendbirdInternal) public init(
        useNativeSocket: Bool? = nil,
        cachePolicy: NSURLRequest.CachePolicy,
        apiHost: String,
        wsHost: String
    ) {
        self.cachePolicy = cachePolicy
        self.useNativeSocket = useNativeSocket
        self.apiHost = apiHost
        self.wsHost = wsHost
        Logger.main.info("API Host: \(apiHost)")
        Logger.main.info("WS Host: \(wsHost)")
    }
    
    // Only used for before `SendbirdChat.initWithApplicationId` is called
    @_spi(SendbirdInternal) public static let `default` = CommandRouterConfiguration(
        useNativeSocket: nil,
        cachePolicy: .useProtocolCachePolicy,
        apiHost: "",
        wsHost: ""
    )
    
    // NOTE: Enables host persistence to AppGroup UserDefaults
    // so that NotificationExtension can reuse the main app's host for API calls (e.g., push delivery).
    @_spi(SendbirdInternal) public func setAppGroup(_ appGroup: String, applicationId: String) {
        self.appGroup = appGroup
        self.applicationId = applicationId
        self.appGroupPreferences = LocalPreferences(suiteName: appGroup)
        syncHostToAppGroup()
    }

    @_spi(SendbirdInternal) public func updateHost(apiHost: String?, wsHost: String?) {
        if let apiHost {
            self.apiHost = apiHost
        }
        if let wsHost {
            self.wsHost = wsHost
        }
        syncHostToAppGroup()
    }

    // NOTE: Reads the latest host from AppGroup UserDefaults that was saved by the main app.
    // Used by NotificationExtension to restore the main app's host for API calls (e.g., push delivery).
    @_spi(SendbirdInternal) @discardableResult
    public func loadHostFromAppGroup(
        appGroup: String,
        applicationId: String
    ) -> Bool {
        let preferences = appGroupPreferences ?? LocalPreferences(suiteName: appGroup)
        let apiHost: String? = preferences.value(forKey: "\(PreferenceKey.latestAPIHost)_\(applicationId)")
        let wsHost: String? = preferences.value(forKey: "\(PreferenceKey.latestWSHost)_\(applicationId)")

        var loaded = false
        if let apiHost, apiHost.hasElements {
            self.apiHost = apiHost
            loaded = true
        }
        if let wsHost, wsHost.hasElements {
            self.wsHost = wsHost
            loaded = true
        }
        return loaded
    }

    // TODO: PushDeviceInfoCacheStorage also uses UserDefaults(suiteName: appGroup) for push token.
    // Consider sharing a single AppGroup UserDefaults instance across host sync and push token storage.
    private func syncHostToAppGroup() {
        guard let applicationId, let preferences = appGroupPreferences else { return }
        preferences.set(value: apiHost, forKey: "\(PreferenceKey.latestAPIHost)_\(applicationId)")
        preferences.set(value: wsHost, forKey: "\(PreferenceKey.latestWSHost)_\(applicationId)")
    }
}
