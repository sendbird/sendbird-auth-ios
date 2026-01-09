//
//  InstanceRegistry.swift
//  SendbirdAuth
//
//  Created by Kai Lee on 1/9/26.
//

import Foundation

internal final class InstanceRegistry {
    private let instances = NSMapTable<NSString, SendbirdAuthMain>(
        keyOptions: .strongMemory,
        valueOptions: .weakMemory
    )
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
        let key = Self.createKey(appId: params.applicationId, apiHostUrl: params.customAPIHost) as NSString

        return lock.withLock {
            if let existing = instances.object(forKey: key) {
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
            instances.setObject(newInstance, forKey: key)
            return newInstance
        }
    }

    func get(appId: String, apiHostUrl: String? = nil) -> SendbirdAuthMain? {
        let key = Self.createKey(appId: appId, apiHostUrl: apiHostUrl) as NSString
        return lock.withLock {
            instances.object(forKey: key)
        }
    }

    func remove(appId: String, apiHostUrl: String? = nil) {
        let key = Self.createKey(appId: appId, apiHostUrl: apiHostUrl) as NSString
        lock.withLock {
            instances.removeObject(forKey: key)
        }
    }

    func remove(_ instance: SendbirdAuthMain) {
        let appId = instance.applicationId
        let apiHostUrl = instance.routerConfig.apiHost

        let key = Self.createKey(appId: appId, apiHostUrl: apiHostUrl) as NSString
        lock.withLock {
            instances.removeObject(forKey: key)
        }
    }

    func update(_ instance: SendbirdAuthMain) {
        let key = Self.createKey(appId: instance.applicationId, apiHostUrl: instance.routerConfig.apiHost) as NSString
        lock.withLock {
            instances.setObject(instance, forKey: key)
        }
    }

    func clear() {
        lock.withLock {
            instances.removeAllObjects()
        }
    }

    func first() -> SendbirdAuthMain? {
        lock.withLock {
            instances.objectEnumerator()?.nextObject() as? SendbirdAuthMain
        }
    }
}
