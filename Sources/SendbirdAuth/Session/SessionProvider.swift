//
//  SessionProvider.swift
//  SendbirdAuth
//
//  Created by Kai Lee on 2026/02/02.
//

import Foundation

/// Protocol for session sharing
/// Only one session is active at a time
@_spi(SendbirdInternal) public protocol SessionProvider {
    func setSession(_ session: Session?, for userId: String)
    func loadSession(for userId: String) -> Session?

    /// Register a callback invoked when the session changes
    func onSessionChanged(_ handler: @escaping (Session?) -> Void)

    /// Clear all session state (session, userId, knownKeys, UserDefaults)
    func clear()

    // MARK: - Refresh Coordination

    /// Called on a 401 response. Returns true if another SDK already refreshed the session, false otherwise.
    func hasRefreshedSession(current: Session) -> Bool

    /// Called after the token refresh API responds. Returns whether to accept the new session (reject if the key was already used).
    func submitRefreshedSession(_ newSession: Session) -> Bool
}

/// Session sharing implementation with UserDefaults persistence
@_spi(SendbirdInternal) public class PersistentSessionProvider: SessionProvider {
    @_spi(SendbirdInternal) public static let shared = PersistentSessionProvider()

    private let queue = SafeSerialQueue(label: "com.sendbird.session.provider")
    private var handlers: [(Session?) -> Void] = []

    /// Track already-used session keys (prevent rollback)
    private var knownKeys: Set<String> = []

    private var session: Session?
    @_spi(SendbirdInternal) public private(set) var userId: String?
    @_spi(SendbirdInternal) public init() {}

    /// Restore a session from UserDefaults
    @discardableResult
    @_spi(SendbirdInternal) public func loadSession(for userId: String) -> Session? {
        queue.sync {
            if let session, self.userId == userId {
                return session
            }

            guard let savedSession = Session.buildFromUserDefaults(for: userId) else {
                return nil
            }

            self.session = savedSession
            self.userId = userId

            knownKeys.insert(savedSession.key)
            return savedSession
        }
    }

    @_spi(SendbirdInternal) public func setSession(_ session: Session?, for userId: String) {
        guard !userId.isEmpty else {
            return
        }

        queue.sync {
            // Reset knownKeys when userId changes
            if self.userId != userId {
                knownKeys.removeAll()
            }

            self.session = session
            self.userId = userId

            // Add the new session key to knownKeys
            if let sessionKey = session?.key {
                knownKeys.insert(sessionKey)
            }

            if let session = session {
                Session.saveToUserDefaults(session: session, userId: userId)
            } else {
                Session.clearUserDefaults()
            }
        }

        let handlersToNotify = queue.sync { handlers }
        handlersToNotify.forEach { $0(session) }
    }

    @_spi(SendbirdInternal) public func onSessionChanged(_ handler: @escaping (Session?) -> Void) {
        queue.async {
            self.handlers.append(handler)
        }
    }

    @_spi(SendbirdInternal) public func clear() {
        queue.sync {
            session = nil
            userId = nil
            knownKeys.removeAll()
            Session.clearUserDefaults()
        }

        let handlersToNotify = queue.sync { handlers }
        handlersToNotify.forEach { $0(nil) }
    }

    // MARK: - Refresh Coordination

    @_spi(SendbirdInternal) public func hasRefreshedSession(current: Session) -> Bool {
        queue.sync {
            // If the stored session key differs, another SDK already refreshed it
            if let storedSession = session, storedSession.key != current.key {
                return true
            }
            return false // Refresh needed
        }
    }

    @_spi(SendbirdInternal) public func submitRefreshedSession(_ newSession: Session) -> Bool {
        let accepted = queue.sync {
            // Reject if the key was already used (prevent rollback)
            if knownKeys.contains(newSession.key) {
                return false
            }

            knownKeys.insert(newSession.key)
            session = newSession

            if let userId = self.userId {
                Session.saveToUserDefaults(session: newSession, userId: userId)
            }

            return true
        }

        if accepted {
            let handlersToNotify = queue.sync { handlers }
            handlersToNotify.forEach { $0(newSession) }
        }

        return accepted
    }
}
