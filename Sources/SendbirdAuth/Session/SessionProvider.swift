//
//  SessionProvider.swift
//  SendbirdAuth
//
//  Created by Kai Lee on 2026/02/02.
//

import Foundation

/// Observer protocol for session changes
@_spi(SendbirdInternal) public protocol SessionObserver: AnyObject {
    func sessionDidChange(_ session: Session?)

    /// Called when the provider broadcasts a session refresh request.
    /// Observers with `canRefreshSession == true` should perform the actual refresh.
    func sessionRefreshRequested(for session: Session)

    /// Called when a refreshable SDK fails to refresh the session.
    /// Non-refreshable SDKs waiting for external refresh should handle the failure.
    func sessionRefreshFailed()
}

extension SessionObserver {
    @_spi(SendbirdInternal) public func sessionRefreshRequested(for session: Session) {}
    @_spi(SendbirdInternal) public func sessionRefreshFailed() {}
}

/// Protocol for session sharing
/// Only one session is active at a time
@_spi(SendbirdInternal) public protocol SessionProvider {
    func setSession(_ session: Session?, for userId: String)
    func loadSession(for userId: String) -> Session?

    /// Register an observer for session changes (weak reference, auto-cleaned on dealloc)
    func addSessionObserver(_ observer: SessionObserver)

    /// Remove a session observer
    func removeSessionObserver(_ observer: SessionObserver)

    /// Clear all session state (session, userId, knownKeys, UserDefaults)
    func clear()

    // MARK: - Refresh Coordination

    /// Called on a 401 response. Returns true if another SDK already refreshed the session, false otherwise.
    func hasRefreshedSession(current: Session) -> Bool

    /// Called after the token refresh API responds. Returns whether to accept the new session (reject if the key was already used).
    func submitRefreshedSession(_ newSession: Session) -> Bool

    /// Broadcast a session refresh request to all observers.
    /// Used when a non-refreshable SDK needs a refreshable SDK to perform the refresh.
    /// Returns `true` if there are other observers that may handle the refresh.
    @discardableResult
    func requestSessionRefresh(for session: Session) -> Bool

    /// Broadcast session refresh failure to all observers.
    /// Called when a refreshable SDK fails to refresh, notifying non-refreshable SDKs.
    func notifySessionRefreshFailed()
}

/// Session sharing implementation with UserDefaults persistence
@_spi(SendbirdInternal) public class PersistentSessionProvider: SessionProvider {
    @_spi(SendbirdInternal) public static let shared = PersistentSessionProvider()

    private let queue = SafeSerialQueue(label: "com.sendbird.session.provider")
    private var observers: [WeakReference<AnyObject>] = []

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
                Session.clearUserDefaults(for: userId)
            }
        }

        notifyObservers(session: session)
    }

    @_spi(SendbirdInternal) public func addSessionObserver(_ observer: SessionObserver) {
        queue.async {
            // Prevent duplicate registration
            let alreadyRegistered = self.observers.contains { $0.value === observer }
            if !alreadyRegistered {
                self.observers.append(WeakReference(value: observer))
            }
        }
    }

    @_spi(SendbirdInternal) public func removeSessionObserver(_ observer: SessionObserver) {
        queue.async {
            self.observers.removeAll { $0.value === observer || $0.value == nil }
        }
    }

    @_spi(SendbirdInternal) public func clear() {
        queue.sync {
            let currentUserId = userId
            session = nil
            userId = nil
            knownKeys.removeAll()
            Session.clearUserDefaults(for: currentUserId)
        }

        notifyObservers(session: nil)
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
            notifyObservers(session: newSession)
        }

        return accepted
    }

    @discardableResult
    @_spi(SendbirdInternal) public func requestSessionRefresh(for session: Session) -> Bool {
        let liveObservers: [SessionObserver] = queue.sync {
            observers.removeAll { $0.value == nil }
            return observers.compactMap { $0.value as? SessionObserver }
        }
        liveObservers.forEach { $0.sessionRefreshRequested(for: session) }
        // If there are multiple observers, at least one other SDK may handle the refresh
        return liveObservers.count > 1
    }

    @_spi(SendbirdInternal) public func notifySessionRefreshFailed() {
        let liveObservers: [SessionObserver] = queue.sync {
            observers.removeAll { $0.value == nil }
            return observers.compactMap { $0.value as? SessionObserver }
        }
        liveObservers.forEach { $0.sessionRefreshFailed() }
    }

    // MARK: - Private

    private func notifyObservers(session: Session?) {
        let liveObservers: [SessionObserver] = queue.sync {
            observers.removeAll { $0.value == nil }
            return observers.compactMap { $0.value as? SessionObserver }
        }
        liveObservers.forEach { $0.sessionDidChange(session) }
    }
}
