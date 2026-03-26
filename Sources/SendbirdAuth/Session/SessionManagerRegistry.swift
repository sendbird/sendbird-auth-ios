//
//  SessionManagerRegistry.swift
//  SendbirdAuth
//
//  Created by OpenAI Codex on 2026/03/26.
//

import Foundation

@_spi(SendbirdInternal) public protocol SessionManagerRegistry {
    func sessionManager(applicationId: String, userId: String) -> SessionManager
}

@_spi(SendbirdInternal) public final class DefaultSessionManagerRegistry: SessionManagerRegistry {
    @_spi(SendbirdInternal) public static let shared = DefaultSessionManagerRegistry()

    private let queue = SafeSerialQueue(label: "com.sendbird.session.manager.registry")
    private var managers: [String: SessionManager] = [:]

    @_spi(SendbirdInternal) public init() {}

    @_spi(SendbirdInternal) public func sessionManager(applicationId: String, userId: String) -> SessionManager {
        guard applicationId.isEmpty == false, userId.isEmpty == false else {
            return SessionManager(applicationId: applicationId, userId: userId)
        }

        let key = "\(applicationId)|\(userId)"
        return queue.sync {
            if let existing = managers[key] {
                return existing
            }

            let manager = SessionManager(applicationId: applicationId, userId: userId)
            managers[key] = manager
            return manager
        }
    }
}
