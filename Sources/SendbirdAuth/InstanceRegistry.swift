//
//  InstanceRegistry.swift
//  SendbirdAuth
//
//  Created by Kai Lee on 1/9/26.
//

import Foundation

final class InstanceRegistry {
    private var instances: [String: WeakReference<SendbirdAuthMain>] = [:]
    private let lock = NSLock()

    static func createKey(appId: String, apiHostUrl: String?) -> String {
        let hostUrl = apiHostUrl ?? Configuration.apiHostURL(for: appId)
        return "\(appId)_\(hostUrl)"
    }

    func getOrCreate(
        params: InternalInitParams,
        statAPIClient: StatAPIClientable? = nil,
        webSocketEngine: (any ChatWebSocketEngine)? = nil,
        httpClient: HTTPClientInterface? = nil,
        customRouterConfig: CommandRouterConfiguration? = nil,
        customSendbirdConfig: SendbirdConfiguration? = nil
    ) -> SendbirdAuthMain {
        let key = Self.createKey(appId: params.applicationId, apiHostUrl: params.customAPIHost)

        return lock.withLock {
            if let existing = instances[key]?.value {
                return existing
            }

            let newInstance = SendbirdAuthMain(
                params: params,
                statAPIClient: statAPIClient,
                webSocketEngine: webSocketEngine,
                httpClient: httpClient,
                customRouterConfig: customRouterConfig,
                customSendbirdConfig: customSendbirdConfig
            )
            instances[key] = WeakReference(value: newInstance)
            return newInstance
        }
    }

    func get(appId: String, apiHostUrl: String? = nil) -> SendbirdAuthMain? {
        let key = Self.createKey(appId: appId, apiHostUrl: apiHostUrl)
        return lock.withLock {
            instances[key]?.value
        }
    }

    func remove(appId: String, apiHostUrl: String? = nil) {
        let key = Self.createKey(appId: appId, apiHostUrl: apiHostUrl)
        lock.withLock {
            instances[key] = nil
        }
    }

    func remove(_ instance: SendbirdAuthMain) {
        let appId = instance.applicationId
        let apiHostUrl = instance.routerConfig.apiHost

        let key = Self.createKey(appId: appId, apiHostUrl: apiHostUrl)
        lock.withLock {
            instances[key] = nil
        }
    }

    func update(_ instance: SendbirdAuthMain) {
        let key = Self.createKey(appId: instance.applicationId, apiHostUrl: instance.routerConfig.apiHost)
        lock.withLock {
            instances[key] = WeakReference(value: instance)
        }
    }

    func clear() {
        lock.withLock {
            instances.removeAll()
        }
    }

    func first() -> SendbirdAuthMain? {
        lock.withLock {
            instances.values.first { $0.value != nil }?.value
        }
    }
}
