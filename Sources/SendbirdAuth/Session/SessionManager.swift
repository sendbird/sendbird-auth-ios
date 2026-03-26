//
//  SessionManager.swift
//  SendbirdAuth
//
//  Created by OpenAI Codex on 2026/03/26.
//

import Foundation

@_spi(SendbirdInternal) public final class SessionManager {
    private let queue = SafeSerialQueue(label: "com.sendbird.session.manager")
    private var observers: [WeakReference<AnyObject>] = []
    private var knownKeys: Set<String> = []
    private var cachedSession: Session?
    private var requiresConnectionStateReset = false

    @_spi(SendbirdInternal) public let applicationId: String?
    @_spi(SendbirdInternal) public let userId: String?

    @_spi(SendbirdInternal) public init(applicationId: String, userId: String) {
        self.applicationId = applicationId.isEmpty ? nil : applicationId
        self.userId = userId.isEmpty ? nil : userId
    }

    @_spi(SendbirdInternal) public var session: Session? {
        get { loadSession() }
        set { setSession(newValue) }
    }

    @_spi(SendbirdInternal) public var canReuseConnectionState: Bool {
        queue.sync { !requiresConnectionStateReset }
    }

    @discardableResult
    @_spi(SendbirdInternal) public func loadSession() -> Session? {
        guard let userId else {
            return nil
        }

        return queue.sync {
            if let cachedSession {
                return cachedSession
            }

            guard let savedSession = Session.buildFromUserDefaults(for: userId) else {
                return nil
            }

            cachedSession = savedSession
            knownKeys.insert(savedSession.key)
            return savedSession
        }
    }

    @_spi(SendbirdInternal) public func setSession(_ session: Session?) {
        guard let userId else {
            return
        }

        queue.sync {
            cachedSession = session

            if let sessionKey = session?.key {
                knownKeys.insert(sessionKey)
            }

            if let session {
                Session.saveToUserDefaults(session: session, userId: userId)
            } else {
                Session.clearUserDefaults(for: userId)
            }
        }

        notifyObservers(session: session)
    }

    @_spi(SendbirdInternal) public func addSessionObserver(_ observer: SessionObserver) {
        queue.sync {
            let alreadyRegistered = observers.contains { $0.value === observer }
            if !alreadyRegistered {
                observers.append(WeakReference(value: observer))
            }
        }
    }

    @_spi(SendbirdInternal) public func removeSessionObserver(_ observer: SessionObserver) {
        queue.sync {
            observers.removeAll { $0.value === observer || $0.value == nil }
        }
    }

    @_spi(SendbirdInternal) public func clear() {
        queue.sync {
            cachedSession = nil
            knownKeys.removeAll()
            requiresConnectionStateReset = true
            Session.clearUserDefaults(for: userId)
        }

        notifyObservers(session: nil)
    }

    @_spi(SendbirdInternal) public func activateConnectionState() {
        queue.sync {
            requiresConnectionStateReset = false
        }
    }

    @_spi(SendbirdInternal) public func hasRefreshedSession(current: Session) -> Bool {
        queue.sync {
            if let cachedSession, cachedSession.key != current.key {
                return true
            }

            return false
        }
    }

    @_spi(SendbirdInternal) public func submitRefreshedSession(_ newSession: Session) -> Bool {
        guard let userId else {
            return false
        }

        let accepted = queue.sync {
            if knownKeys.contains(newSession.key) {
                return false
            }

            knownKeys.insert(newSession.key)
            cachedSession = newSession
            Session.saveToUserDefaults(session: newSession, userId: userId)
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

        var handled = false
        for observer in liveObservers {
            if observer.canRefreshSession {
                observer.sessionRefreshRequested(for: session)
                handled = true
            }
        }
        return handled
    }

    @_spi(SendbirdInternal) public func notifySessionRefreshFailed() {
        let liveObservers: [SessionObserver] = queue.sync {
            observers.removeAll { $0.value == nil }
            return observers.compactMap { $0.value as? SessionObserver }
        }
        liveObservers.forEach { $0.sessionRefreshFailed() }
    }

    private func notifyObservers(session: Session?) {
        let liveObservers: [SessionObserver] = queue.sync {
            observers.removeAll { $0.value == nil }
            return observers.compactMap { $0.value as? SessionObserver }
        }
        liveObservers.forEach { $0.sessionDidChange(session) }
    }
}
